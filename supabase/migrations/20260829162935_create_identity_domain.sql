-- =====================================================================
-- IDENTITY DOMAIN
-- =====================================================================
--
-- Identity domain:
--   - profiles
--   - teams
--   - team_members
--   - team_membership_requests
--   - projects
--
-- Auth is fully delegated to Supabase Auth (auth.users).
-- Passwords are never stored here.
--
-- Team / membership writes happen exclusively through SECURITY DEFINER
-- functions. Direct client writes to teams, team_members and
-- team_membership_requests are not granted.
--
-- RLS policies are intentionally read-oriented. Membership checks use
-- private SECURITY DEFINER helper functions so that policies do not
-- recursively query RLS-protected tables.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------

create schema if not exists identity;
create schema if not exists private;


-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------

create table identity.profiles (
                                 id          uuid primary key references auth.users (id) on delete cascade,
                                 full_name   text not null default '',
                                 avatar_path text,
                                 created_at  timestamptz not null default now(),
                                 updated_at  timestamptz not null default now()
);

comment on table identity.profiles is
  'One row per auth.users, auto-created on signup. Password is never stored here -- Supabase Auth owns it.';

comment on column identity.profiles.avatar_path is
  'Storage path (bucket: avatars). PNG only, enforced at bucket policy + edge function level.';


create table identity.teams (
                              id         uuid primary key default gen_random_uuid(),
                              name       text not null,
                              created_by uuid not null references identity.profiles (id),
                              created_at timestamptz not null default now(),
                              updated_at timestamptz not null default now()
);

comment on table identity.teams is
  'No owner_id column by design -- current owner is read from team_members.role = owner.';


create table identity.team_members (
                                     team_id   uuid not null references identity.teams (id) on delete cascade,
                                     user_id   uuid not null references identity.profiles (id) on delete cascade,
                                     role      text not null check (role in ('owner', 'admin', 'member')),
                                     joined_at timestamptz not null default now(),
                                     primary key (team_id, user_id)
);

-- At most one owner per team.
create unique index idx_team_members_single_owner
  on identity.team_members (team_id)
  where role = 'owner';

create index idx_team_members_user_id
  on identity.team_members (user_id);


create table identity.team_membership_requests (
                                                 id            uuid primary key default gen_random_uuid(),
                                                 team_id       uuid not null references identity.teams (id) on delete cascade,
                                                 user_id       uuid not null references identity.profiles (id) on delete cascade,
                                                 type          text not null check (
                                                   type in ('join_request', 'invite', 'ownership_transfer')
                                                   ),
                                                 initiated_by  uuid not null references identity.profiles (id),
                                                 status        text not null default 'pending'
                                                   check (status in ('pending', 'accepted', 'rejected', 'cancelled')),
                                                 requested_at  timestamptz not null default now(),
                                                 decided_at    timestamptz,
                                                 decided_by    uuid references identity.profiles (id)
);

comment on table identity.team_membership_requests is
  'Bidirectional membership flow. type=join_request: user_id requests, an owner/admin decides. type=invite: an owner/admin initiates, user_id decides. type=ownership_transfer: the owner initiates, user_id (the target, member or not) decides. initiated_by can always cancel while pending.';

-- At most one pending request per (team, user), regardless of type.
create unique index idx_membership_requests_one_pending
  on identity.team_membership_requests (team_id, user_id)
  where status = 'pending';

create index idx_membership_requests_user_id
  on identity.team_membership_requests (user_id);

create index idx_membership_requests_initiated_by
  on identity.team_membership_requests (initiated_by);


create table identity.projects (
                                 id                 uuid primary key default gen_random_uuid(),
                                 owner_id           uuid not null references identity.profiles (id),
                                 team_id            uuid references identity.teams (id) on delete set null,
                                 name               text not null,
                                 description        text,
                                 archive_path       text not null,
                                 archive_size_bytes bigint not null check (archive_size_bytes > 0),
                                 archive_sha256     text not null check (archive_sha256 ~ '^[a-f0-9]{64}$'),
                                 created_at         timestamptz not null default now(),
                                 updated_at         timestamptz not null default now()
);

comment on table identity.projects is
  'User-uploaded project archives. Archive itself lives in Storage (bucket: project-archives, .tar.zst); this row is metadata + integrity checksum. A team may own any number of projects (not a 1:1 relationship).';

create index idx_projects_owner_id
  on identity.projects (owner_id);

create index idx_projects_team_id
  on identity.projects (team_id);


-- ---------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------

create function identity.set_updated_at()
  returns trigger
  language plpgsql
  set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;


create trigger trg_profiles_updated_at
  before update on identity.profiles
  for each row
execute function identity.set_updated_at();


create trigger trg_teams_updated_at
  before update on identity.teams
  for each row
execute function identity.set_updated_at();


create trigger trg_projects_updated_at
  before update on identity.projects
  for each row
execute function identity.set_updated_at();


-- ---------------------------------------------------------------------
-- Auto-create a profile on signup
-- ---------------------------------------------------------------------

create function identity.handle_new_auth_user()
  returns trigger
  language plpgsql
  security definer
  set search_path = ''
as $$
begin
  insert into identity.profiles (id, full_name)
  values (
           new.id,
           coalesce(new.raw_user_meta_data ->> 'full_name', '')
         );

  return new;
end;
$$;

alter function identity.handle_new_auth_user()
  owner to postgres;

revoke all on function identity.handle_new_auth_user() from public;


create trigger trg_handle_new_auth_user
  after insert on auth.users
  for each row
execute function identity.handle_new_auth_user();


-- ---------------------------------------------------------------------
-- 30-member team cap
-- ---------------------------------------------------------------------

create function identity.enforce_team_capacity()
  returns trigger
  language plpgsql
  set search_path = ''
as $$
begin
  if (
       select count(*)
       from identity.team_members
       where team_id = new.team_id
     ) >= 30 then
    raise exception
      'team % is at capacity (30 members)',
      new.team_id
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

alter function identity.enforce_team_capacity()
  owner to postgres;

revoke all on function identity.enforce_team_capacity() from public;


create trigger trg_team_members_capacity
  before insert on identity.team_members
  for each row
execute function identity.enforce_team_capacity();


-- ---------------------------------------------------------------------
-- RLS helper functions
--
-- IMPORTANT:
-- These functions are created BEFORE RLS policies.
--
-- SECURITY DEFINER + row_security=off prevents the helper itself from
-- re-entering team_members RLS and causing infinite recursion.
-- ---------------------------------------------------------------------

create function private.is_team_member(_team_id uuid)
  returns boolean
  language sql
  stable
  security definer
  set search_path = ''
  set row_security = off
as $$
select exists (
  select 1
  from identity.team_members tm
  where tm.team_id = _team_id
    and tm.user_id = auth.uid()
);
$$;

alter function private.is_team_member(uuid)
  owner to postgres;

revoke all on function private.is_team_member(uuid) from public;


create function private.is_team_admin(_team_id uuid)
  returns boolean
  language sql
  stable
  security definer
  set search_path = ''
  set row_security = off
as $$
select exists (
  select 1
  from identity.team_members tm
  where tm.team_id = _team_id
    and tm.user_id = auth.uid()
    and tm.role in ('owner', 'admin')
);
$$;

alter function private.is_team_admin(uuid)
  owner to postgres;

revoke all on function private.is_team_admin(uuid) from public;


-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------

alter table identity.profiles enable row level security;
alter table identity.teams enable row level security;
alter table identity.team_members enable row level security;
alter table identity.team_membership_requests enable row level security;
alter table identity.projects enable row level security;


-- ---------------------------------------------------------------------
-- profiles
--
-- Public read.
-- Authenticated users may only update their own profile.
-- ---------------------------------------------------------------------

create policy "profiles_public_read"
  on identity.profiles
  for select
  to anon, authenticated
  using (
  true
  );


create policy "profiles_self_update"
  on identity.profiles
  for update
  to authenticated
  using (
  id = auth.uid()
  )
  with check (
  id = auth.uid()
  );


-- ---------------------------------------------------------------------
-- teams
--
-- Only team members may read the team.
-- ---------------------------------------------------------------------

create policy "teams_member_read"
  on identity.teams
  for select
  to authenticated
  using (
  (select private.is_team_member(id))
  );


-- ---------------------------------------------------------------------
-- team_members
--
-- Only members of a team may read its membership rows.
-- ---------------------------------------------------------------------

create policy "team_members_member_read"
  on identity.team_members
  for select
  to authenticated
  using (
  (select private.is_team_member(team_id))
  );


-- ---------------------------------------------------------------------
-- membership requests
--
-- Relevant parties:
--   * target user
--   * initiator
--   * owner/admin of the team
-- ---------------------------------------------------------------------

create policy "membership_requests_relevant_parties_read"
  on identity.team_membership_requests
  for select
  to authenticated
  using (
  user_id = auth.uid()
    or initiated_by = auth.uid()
    or (select private.is_team_admin(team_id))
  );


-- ---------------------------------------------------------------------
-- projects
--
-- Project owner can always read.
-- Team members can read team projects.
-- Direct writes are owner-only.
-- ---------------------------------------------------------------------

create policy "projects_read"
  on identity.projects
  for select
  to authenticated
  using (
  owner_id = auth.uid()
    or (
    team_id is not null
      and (select private.is_team_member(team_id))
    )
  );


create policy "projects_owner_insert"
  on identity.projects
  for insert
  to authenticated
  with check (
  owner_id = auth.uid()
  );


create policy "projects_owner_update"
  on identity.projects
  for update
  to authenticated
  using (
  owner_id = auth.uid()
  )
  with check (
  owner_id = auth.uid()
  );


create policy "projects_owner_delete"
  on identity.projects
  for delete
  to authenticated
  using (
  owner_id = auth.uid()
  );


-- ---------------------------------------------------------------------
-- Functions: teams
-- ---------------------------------------------------------------------

create function identity.create_team(p_name text)
  returns uuid
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  v_team_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  insert into identity.teams (
    name,
    created_by
  )
  values (
           p_name,
           auth.uid()
         )
  returning id into v_team_id;

  insert into identity.team_members (
    team_id,
    user_id,
    role
  )
  values (
           v_team_id,
           auth.uid(),
           'owner'
         );

  return v_team_id;
end;
$$;

alter function identity.create_team(text)
  owner to postgres;

revoke all on function identity.create_team(text) from public;


create function identity.rename_team(
  p_team_id uuid,
  p_name text
)
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
begin
  if not exists (
    select 1
    from identity.team_members
    where team_id = p_team_id
      and user_id = auth.uid()
      and role = 'owner'
  ) then
    raise exception
      'only the owner can rename this team'
      using errcode = '42501';
  end if;

  update identity.teams
  set name = p_name
  where id = p_team_id;
end;
$$;

alter function identity.rename_team(uuid, text)
  owner to postgres;

revoke all on function identity.rename_team(uuid, text) from public;


create function identity.delete_team(p_team_id uuid)
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
begin
  if not exists (
    select 1
    from identity.team_members
    where team_id = p_team_id
      and user_id = auth.uid()
      and role = 'owner'
  ) then
    raise exception
      'only the owner can delete this team'
      using errcode = '42501';
  end if;

  delete from identity.teams
  where id = p_team_id;
end;
$$;

alter function identity.delete_team(uuid)
  owner to postgres;

revoke all on function identity.delete_team(uuid) from public;


-- ---------------------------------------------------------------------
-- Functions: membership requests
-- ---------------------------------------------------------------------

create function identity.request_to_join(p_team_id uuid)
  returns uuid
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  v_request_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if exists (
    select 1
    from identity.team_members
    where team_id = p_team_id
      and user_id = auth.uid()
  ) then
    raise exception 'already a member of this team';
  end if;

  insert into identity.team_membership_requests (
    team_id,
    user_id,
    type,
    initiated_by
  )
  values (
           p_team_id,
           auth.uid(),
           'join_request',
           auth.uid()
         )
  returning id into v_request_id;

  return v_request_id;

exception
  when unique_violation then
    raise exception 'a pending request already exists for this team';
end;
$$;

alter function identity.request_to_join(uuid)
  owner to postgres;

revoke all on function identity.request_to_join(uuid) from public;


create function identity.invite_to_team(
  p_team_id uuid,
  p_user_id uuid
)
  returns uuid
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  v_request_id uuid;
begin
  if not exists (
    select 1
    from identity.team_members
    where team_id = p_team_id
      and user_id = auth.uid()
      and role in ('owner', 'admin')
  ) then
    raise exception
      'only the owner or an admin can invite'
      using errcode = '42501';
  end if;

  if exists (
    select 1
    from identity.team_members
    where team_id = p_team_id
      and user_id = p_user_id
  ) then
    raise exception 'user is already a member of this team';
  end if;

  insert into identity.team_membership_requests (
    team_id,
    user_id,
    type,
    initiated_by
  )
  values (
           p_team_id,
           p_user_id,
           'invite',
           auth.uid()
         )
  returning id into v_request_id;

  return v_request_id;

exception
  when unique_violation then
    raise exception
      'a pending request already exists for this user/team';
end;
$$;

alter function identity.invite_to_team(uuid, uuid)
  owner to postgres;

revoke all on function identity.invite_to_team(uuid, uuid) from public;


create function identity.offer_ownership(
  p_team_id uuid,
  p_user_id uuid
)
  returns uuid
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  v_request_id uuid;
begin
  if not exists (
    select 1
    from identity.team_members
    where team_id = p_team_id
      and user_id = auth.uid()
      and role = 'owner'
  ) then
    raise exception
      'only the owner can offer ownership'
      using errcode = '42501';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'cannot transfer ownership to yourself';
  end if;

  insert into identity.team_membership_requests (
    team_id,
    user_id,
    type,
    initiated_by
  )
  values (
           p_team_id,
           p_user_id,
           'ownership_transfer',
           auth.uid()
         )
  returning id into v_request_id;

  return v_request_id;

exception
  when unique_violation then
    raise exception
      'a pending request already exists for this user/team';
end;
$$;

alter function identity.offer_ownership(uuid, uuid)
  owner to postgres;

revoke all on function identity.offer_ownership(uuid, uuid) from public;


create function identity.cancel_request(p_request_id uuid)
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  v_initiated_by uuid;
begin
  select initiated_by
  into v_initiated_by
  from identity.team_membership_requests
  where id = p_request_id
    and status = 'pending'
    for update;

  if not found then
    raise exception 'no pending request with that id';
  end if;

  if v_initiated_by <> auth.uid() then
    raise exception
      'only the initiator can cancel this request'
      using errcode = '42501';
  end if;

  delete from identity.team_membership_requests
  where id = p_request_id;
end;
$$;

alter function identity.cancel_request(uuid)
  owner to postgres;

revoke all on function identity.cancel_request(uuid) from public;


-- ---------------------------------------------------------------------
-- Functions: responding to requests
-- ---------------------------------------------------------------------

create function identity.respond_to_join_request(
  p_request_id uuid,
  p_decision text
)
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  v_req identity.team_membership_requests%rowtype;
begin
  if p_decision not in ('accept', 'reject') then
    raise exception 'p_decision must be ''accept'' or ''reject''';
  end if;

  select *
  into v_req
  from identity.team_membership_requests
  where id = p_request_id
    and type = 'join_request'
    and status = 'pending'
    for update;

  if not found then
    raise exception 'no pending join request with that id';
  end if;

  if not exists (
    select 1
    from identity.team_members
    where team_id = v_req.team_id
      and user_id = auth.uid()
      and role in ('owner', 'admin')
  ) then
    raise exception
      'only the owner or an admin can respond'
      using errcode = '42501';
  end if;

  if p_decision = 'reject' then
    delete from identity.team_membership_requests
    where id = p_request_id;

    return;
  end if;

  insert into identity.team_members (
    team_id,
    user_id,
    role
  )
  values (
           v_req.team_id,
           v_req.user_id,
           'member'
         );

  delete from identity.team_membership_requests
  where id = p_request_id;
end;
$$;

alter function identity.respond_to_join_request(uuid, text)
  owner to postgres;

revoke all on function identity.respond_to_join_request(uuid, text) from public;


create function identity.respond_to_invite(
  p_request_id uuid,
  p_decision text
)
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  v_req identity.team_membership_requests%rowtype;
begin
  if p_decision not in ('accept', 'reject') then
    raise exception 'p_decision must be ''accept'' or ''reject''';
  end if;

  select *
  into v_req
  from identity.team_membership_requests
  where id = p_request_id
    and type = 'invite'
    and status = 'pending'
    for update;

  if not found then
    raise exception 'no pending invite with that id';
  end if;

  if v_req.user_id <> auth.uid() then
    raise exception
      'only the invited user can respond'
      using errcode = '42501';
  end if;

  if p_decision = 'reject' then
    delete from identity.team_membership_requests
    where id = p_request_id;

    return;
  end if;

  if (
       select count(*)
       from identity.team_members
       where team_id = v_req.team_id
     ) >= 30 then
    raise exception 'team is at capacity (30 members)';
  end if;

  insert into identity.team_members (
    team_id,
    user_id,
    role
  )
  values (
           v_req.team_id,
           v_req.user_id,
           'member'
         );

  delete from identity.team_membership_requests
  where id = p_request_id;
end;
$$;

alter function identity.respond_to_invite(uuid, text)
  owner to postgres;

revoke all on function identity.respond_to_invite(uuid, text) from public;


create function identity.respond_to_ownership_transfer(
  p_request_id uuid,
  p_decision text
)
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  v_req       identity.team_membership_requests%rowtype;
  v_is_member boolean;
  v_headcount int;
begin
  if p_decision not in ('accept', 'reject') then
    raise exception 'p_decision must be ''accept'' or ''reject''';
  end if;

  select *
  into v_req
  from identity.team_membership_requests
  where id = p_request_id
    and type = 'ownership_transfer'
    and status = 'pending'
    for update;

  if not found then
    raise exception 'no pending ownership transfer with that id';
  end if;

  if v_req.user_id <> auth.uid() then
    raise exception
      'only the offer target can respond'
      using errcode = '42501';
  end if;

  if p_decision = 'reject' then
    delete from identity.team_membership_requests
    where id = p_request_id;

    return;
  end if;

  select exists (
    select 1
    from identity.team_members
    where team_id = v_req.team_id
      and user_id = v_req.user_id
  )
  into v_is_member;

  if v_is_member then

    -- Target already a member: simple role swap.
    update identity.team_members
    set role = 'owner'
    where team_id = v_req.team_id
      and user_id = v_req.user_id;

    update identity.team_members
    set role = 'admin'
    where team_id = v_req.team_id
      and user_id = v_req.initiated_by;

  else

    select count(*)
    into v_headcount
    from identity.team_members
    where team_id = v_req.team_id;

    if v_headcount >= 30 then

      -- At capacity:
      -- remove the old owner to make room.
      delete from identity.team_members
      where team_id = v_req.team_id
        and user_id = v_req.initiated_by;

    else

      update identity.team_members
      set role = 'admin'
      where team_id = v_req.team_id
        and user_id = v_req.initiated_by;

    end if;

    insert into identity.team_members (
      team_id,
      user_id,
      role
    )
    values (
             v_req.team_id,
             v_req.user_id,
             'owner'
           );

  end if;

  delete from identity.team_membership_requests
  where id = p_request_id;
end;
$$;

alter function identity.respond_to_ownership_transfer(uuid, text)
  owner to postgres;

revoke all on function identity.respond_to_ownership_transfer(uuid, text) from public;


-- ---------------------------------------------------------------------
-- Functions: role management + leaving
-- ---------------------------------------------------------------------

create function identity.promote_to_admin(
  p_team_id uuid,
  p_target uuid
)
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
begin
  if not exists (
    select 1
    from identity.team_members
    where team_id = p_team_id
      and user_id = auth.uid()
      and role in ('owner', 'admin')
  ) then
    raise exception
      'only the owner or an admin can promote'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from identity.team_members
    where team_id = p_team_id
      and user_id = p_target
      and role = 'member'
  ) then
    raise exception 'target must be a current member';
  end if;

  update identity.team_members
  set role = 'admin'
  where team_id = p_team_id
    and user_id = p_target;
end;
$$;

alter function identity.promote_to_admin(uuid, uuid)
  owner to postgres;

revoke all on function identity.promote_to_admin(uuid, uuid) from public;


create function identity.demote_to_member(
  p_team_id uuid,
  p_target uuid
)
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
begin
  if not exists (
    select 1
    from identity.team_members
    where team_id = p_team_id
      and user_id = auth.uid()
      and role = 'owner'
  ) then
    raise exception
      'only the owner can demote an admin'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from identity.team_members
    where team_id = p_team_id
      and user_id = p_target
      and role = 'admin'
  ) then
    raise exception 'target must be a current admin';
  end if;

  update identity.team_members
  set role = 'member'
  where team_id = p_team_id
    and user_id = p_target;
end;
$$;

alter function identity.demote_to_member(uuid, uuid)
  owner to postgres;

revoke all on function identity.demote_to_member(uuid, uuid) from public;


create function identity.remove_member(
  p_team_id uuid,
  p_target uuid
)
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  v_caller_role text;
  v_target_role text;
begin
  select role
  into v_caller_role
  from identity.team_members
  where team_id = p_team_id
    and user_id = auth.uid();

  select role
  into v_target_role
  from identity.team_members
  where team_id = p_team_id
    and user_id = p_target;

  if v_caller_role is null
    or v_caller_role not in ('owner', 'admin') then
    raise exception
      'only the owner or an admin can remove members'
      using errcode = '42501';
  end if;

  if v_target_role is null then
    raise exception 'target is not a member of this team';
  end if;

  if v_target_role = 'owner' then
    raise exception
      'cannot remove the owner -- transfer ownership first';
  end if;

  if v_caller_role = 'admin'
    and v_target_role <> 'member' then
    raise exception
      'admins can only remove members'
      using errcode = '42501';
  end if;

  delete from identity.team_members
  where team_id = p_team_id
    and user_id = p_target;
end;
$$;

alter function identity.remove_member(uuid, uuid)
  owner to postgres;

revoke all on function identity.remove_member(uuid, uuid) from public;


create function identity.leave_team(p_team_id uuid)
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  v_role text;
begin
  select role
  into v_role
  from identity.team_members
  where team_id = p_team_id
    and user_id = auth.uid();

  if v_role is null then
    raise exception 'not a member of this team';
  end if;

  if v_role = 'owner' then
    raise exception
      'the owner cannot leave -- transfer ownership first';
  end if;

  delete from identity.team_members
  where team_id = p_team_id
    and user_id = auth.uid();
end;
$$;

alter function identity.leave_team(uuid)
  owner to postgres;

revoke all on function identity.leave_team(uuid) from public;


-- ---------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------

grant usage on schema identity
  to anon, authenticated;

grant usage on schema private
  to authenticated;


-- profiles
grant select on identity.profiles
  to anon, authenticated;

grant update on identity.profiles
  to authenticated;


-- teams
grant select on identity.teams
  to authenticated;


-- team_members
grant select on identity.team_members
  to authenticated;


-- membership requests
grant select on identity.team_membership_requests
  to authenticated;


-- projects
grant select, insert, update, delete
  on identity.projects
  to authenticated;


-- Private RLS helpers
grant execute on function private.is_team_member(uuid)
  to authenticated;

grant execute on function private.is_team_admin(uuid)
  to authenticated;


-- Business functions
grant execute on function identity.create_team(text)
  to authenticated;

grant execute on function identity.rename_team(uuid, text)
  to authenticated;

grant execute on function identity.delete_team(uuid)
  to authenticated;

grant execute on function identity.request_to_join(uuid)
  to authenticated;

grant execute on function identity.invite_to_team(uuid, uuid)
  to authenticated;

grant execute on function identity.offer_ownership(uuid, uuid)
  to authenticated;

grant execute on function identity.cancel_request(uuid)
  to authenticated;

grant execute on function identity.respond_to_join_request(uuid, text)
  to authenticated;

grant execute on function identity.respond_to_invite(uuid, text)
  to authenticated;

grant execute on function identity.respond_to_ownership_transfer(uuid, text)
  to authenticated;

grant execute on function identity.promote_to_admin(uuid, uuid)
  to authenticated;

grant execute on function identity.demote_to_member(uuid, uuid)
  to authenticated;

grant execute on function identity.remove_member(uuid, uuid)
  to authenticated;

grant execute on function identity.leave_team(uuid)
  to authenticated;


-- ---------------------------------------------------------------------
-- Expired request cleanup
--
-- Requires pg_cron.
-- Runs hourly and deletes pending requests older than 3 days.
-- ---------------------------------------------------------------------

create extension if not exists pg_cron;

do $$
  begin

    if exists (
      select 1
      from pg_extension
      where extname = 'pg_cron'
    ) then

      if exists (
        select 1
        from cron.job
        where jobname = 'expire-team-membership-requests'
      ) then

        perform cron.unschedule(
          'expire-team-membership-requests'
                );

      end if;

      perform cron.schedule(
        'expire-team-membership-requests',
        '0 * * * *',
        $cron$
                delete from identity.team_membership_requests
                where status = 'pending'
                  and requested_at < now() - interval '3 days';
            $cron$
              );

    end if;

  end
$$;
