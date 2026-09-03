-- Content domain: news, polls, and discussions for the website, plus a
-- platform-level role table it depends on.
--
-- Design notes:
--   * Unlike identity's team roles, most of this domain's authorization
--     is a simple, static predicate ("is this user a moderator?", "is
--     this their own row?") rather than a multi-step state transition
--     so it's expressed directly in RLS policies instead of SECURITY
--     DEFINER functions. The only real functions here are:
--       - identity.is_platform_moderator(): a small reusable RLS helper
--       - content.poll_results(): a public aggregate that has to read
--         across all users' votes despite poll_votes being self-read-only
--   * Data integrity that can't be expressed as a plain FK/CHECK (an
--     option must belong to the poll it's voted on) is enforced with a
--     trigger, not a function -- it's a constraint, not an authorization
--     rule.
--   * discussion_replies uses soft delete (deleted_at) so moderation
--     doesn't break a thread's structure; the app/edge layer renders
--     "[deleted]" for tombstoned rows rather than filtering them out.

-- ---------------------------------------------------------------------
-- identity.platform_roles (introduced here, lives in the identity schema)
-- ---------------------------------------------------------------------

create table identity.platform_roles (
                                       user_id uuid primary key
                                         references identity.profiles (id)
                                           on delete cascade,
                                       role text not null
                                         check (role in ('admin', 'moderator')),
                                       granted_at timestamptz not null default now()
);

comment on table identity.platform_roles is
  'Platform-wide (not team-scoped) roles, gating who can write content.news '
    'and moderate content.discussions/polls. No INSERT/UPDATE/DELETE grants '
    'exist for anon/authenticated -- roles are assigned manually via '
    'service_role (Supabase dashboard/SQL editor), not self-service.';

alter table identity.platform_roles enable row level security;

-- Deliberately self-only: no public listing of who the moderators/admins
-- are (avoids making them an enumerable social-engineering target).
create policy platform_roles_self_read
  on identity.platform_roles
  for select
  to authenticated
  using (user_id = auth.uid());

grant select on identity.platform_roles to authenticated;

create or replace function identity.is_platform_moderator()
  returns boolean
  language sql
  stable
as $$
select exists (
  select 1
  from identity.platform_roles
  where user_id = auth.uid()
    and role in ('admin', 'moderator')
);
$$;

grant execute on function identity.is_platform_moderator()
  to authenticated;

-- ---------------------------------------------------------------------
-- Schema + tables
-- ---------------------------------------------------------------------

create schema if not exists content;

create table content.news (
                            id uuid primary key default gen_random_uuid(),
                            title text not null,
                            slug text not null unique,
                            body text not null,
                            author_id uuid not null references identity.profiles (id),
                            status text not null default 'draft'
                              check (status in ('draft', 'published')),
                            published_at timestamptz,
                            created_at timestamptz not null default now(),
                            updated_at timestamptz not null default now()
);

create index idx_news_status
  on content.news (status);

create index idx_news_published_at
  on content.news (published_at desc);

create table content.polls (
                             id uuid primary key default gen_random_uuid(),
                             question text not null,
                             created_by uuid not null references identity.profiles (id),
                             closes_at timestamptz,
                             created_at timestamptz not null default now()
);

create table content.poll_options (
                                    id uuid primary key default gen_random_uuid(),
                                    poll_id uuid not null
                                      references content.polls (id)
                                        on delete cascade,
                                    label text not null,
                                    display_order int not null default 0
);

create index idx_poll_options_poll_id
  on content.poll_options (poll_id);

create table content.poll_votes (
                                  poll_id uuid not null
                                    references content.polls (id)
                                      on delete cascade,
                                  option_id uuid not null
                                    references content.poll_options (id)
                                      on delete cascade,
                                  user_id uuid not null
                                    references identity.profiles (id),
                                  voted_at timestamptz not null default now(),
                                  primary key (poll_id, user_id)
);

create table content.discussions (
                                   id uuid primary key default gen_random_uuid(),
                                   title text not null,
                                   body text not null,
                                   author_id uuid not null references identity.profiles (id),
                                   category text,
                                   is_locked boolean not null default false,
                                   created_at timestamptz not null default now(),
                                   updated_at timestamptz not null default now()
);

create index idx_discussions_category
  on content.discussions (category);

create table content.discussion_replies (
                                          id uuid primary key default gen_random_uuid(),
                                          discussion_id uuid not null
                                            references content.discussions (id)
                                              on delete cascade,
                                          author_id uuid not null references identity.profiles (id),
                                          body text not null,
                                          deleted_at timestamptz,
                                          created_at timestamptz not null default now(),
                                          updated_at timestamptz not null default now()
);

create index idx_discussion_replies_discussion_id
  on content.discussion_replies (discussion_id);

-- ---------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------

create or replace function content.set_updated_at()
  returns trigger
  language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_news_updated_at
  before update on content.news
  for each row
execute function content.set_updated_at();

create trigger trg_discussions_updated_at
  before update on content.discussions
  for each row
execute function content.set_updated_at();

create trigger trg_discussion_replies_updated_at
  before update on content.discussion_replies
  for each row
execute function content.set_updated_at();

-- A vote's option must actually belong to the poll it's cast on --
-- not expressible as a plain FK, so enforced here rather than in RLS
-- (this is a data-integrity rule, not an authorization rule).
create or replace function content.enforce_vote_option_matches_poll()
  returns trigger
  language plpgsql
as $$
begin
  if not exists (
    select 1
    from content.poll_options
    where id = new.option_id
      and poll_id = new.poll_id
  ) then
    raise exception
      'option % does not belong to poll %',
      new.option_id,
      new.poll_id
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger trg_poll_votes_option_matches_poll
  before insert on content.poll_votes
  for each row
execute function content.enforce_vote_option_matches_poll();

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------

alter table content.news enable row level security;
alter table content.polls enable row level security;
alter table content.poll_options enable row level security;
alter table content.poll_votes enable row level security;
alter table content.discussions enable row level security;
alter table content.discussion_replies enable row level security;

-- ---------------------------------------------------------------------
-- news
--
-- Anonymous users must never invoke identity.is_platform_moderator(),
-- because that function reads identity.platform_roles and anon has no
-- SELECT permission on that table.
--
-- Therefore public and authenticated read access are deliberately split.
-- ---------------------------------------------------------------------

create policy news_public_read
  on content.news
  for select
  to anon
  using (
  status = 'published'
  );

create policy news_authenticated_read
  on content.news
  for select
  to authenticated
  using (
  status = 'published'
    or author_id = auth.uid()
    or identity.is_platform_moderator()
  );

create policy news_moderator_insert
  on content.news
  for insert
  to authenticated
  with check (
  identity.is_platform_moderator()
    and author_id = auth.uid()
  );

create policy news_moderator_update
  on content.news
  for update
  to authenticated
  using (
  identity.is_platform_moderator()
  )
  with check (
  identity.is_platform_moderator()
  );

create policy news_moderator_delete
  on content.news
  for delete
  to authenticated
  using (
  identity.is_platform_moderator()
  );

-- ---------------------------------------------------------------------
-- polls: public read; moderator-only write
-- ---------------------------------------------------------------------

-- Insert/update are split (rather than one FOR ALL policy) because the
-- insert check ties created_by to the caller, which would incorrectly
-- block a different moderator from editing an existing poll if reused
-- for update.

create policy polls_public_read
  on content.polls
  for select
  to anon, authenticated
  using (true);

create policy polls_moderator_insert
  on content.polls
  for insert
  to authenticated
  with check (
  identity.is_platform_moderator()
    and created_by = auth.uid()
  );

create policy polls_moderator_update
  on content.polls
  for update
  to authenticated
  using (
  identity.is_platform_moderator()
  )
  with check (
  identity.is_platform_moderator()
  );

create policy polls_moderator_delete
  on content.polls
  for delete
  to authenticated
  using (
  identity.is_platform_moderator()
  );

create policy poll_options_public_read
  on content.poll_options
  for select
  to anon, authenticated
  using (true);

create policy poll_options_moderator_write
  on content.poll_options
  for all
  to authenticated
  using (
  identity.is_platform_moderator()
  )
  with check (
  identity.is_platform_moderator()
  );

-- ---------------------------------------------------------------------
-- poll_votes
--
-- Self-read only: individual votes are private; aggregated results are
-- public via content.poll_results().
--
-- Immutable -- no update/delete policy.
-- ---------------------------------------------------------------------

create policy poll_votes_self_read
  on content.poll_votes
  for select
  to authenticated
  using (
  user_id = auth.uid()
  );

create policy poll_votes_self_insert
  on content.poll_votes
  for insert
  to authenticated
  with check (
  user_id = auth.uid()
    and exists (
    select 1
    from content.polls as p
    where p.id = poll_votes.poll_id
      and (
      p.closes_at is null
        or p.closes_at > now()
      )
  )
  );

-- ---------------------------------------------------------------------
-- discussions
--
-- Public read; any authenticated user can start one; author (while
-- unlocked) or a moderator (always) can edit/delete.
-- ---------------------------------------------------------------------

create policy discussions_public_read
  on content.discussions
  for select
  to anon, authenticated
  using (true);

create policy discussions_authenticated_insert
  on content.discussions
  for insert
  to authenticated
  with check (
  author_id = auth.uid()
  );

create policy discussions_author_or_moderator_update
  on content.discussions
  for update
  to authenticated
  using (
  (
    author_id = auth.uid()
      and not is_locked
    )
    or identity.is_platform_moderator()
  )
  with check (
  author_id = auth.uid()
    or identity.is_platform_moderator()
  );

create policy discussions_author_or_moderator_delete
  on content.discussions
  for delete
  to authenticated
  using (
  author_id = auth.uid()
    or identity.is_platform_moderator()
  );

-- ---------------------------------------------------------------------
-- discussion_replies
--
-- Public read (tombstoned rows included -- the app layer renders
-- "[deleted]").
--
-- Reply requires the discussion to be unlocked.
--
-- Author or moderator can update (including soft-delete via setting
-- deleted_at).
--
-- No delete policy -- moderation is soft-delete only.
-- ---------------------------------------------------------------------

create policy discussion_replies_public_read
  on content.discussion_replies
  for select
  to anon, authenticated
  using (true);

create policy discussion_replies_authenticated_insert
  on content.discussion_replies
  for insert
  to authenticated
  with check (
  author_id = auth.uid()
    and exists (
    select 1
    from content.discussions as d
    where d.id = discussion_replies.discussion_id
      and not d.is_locked
  )
  );

create policy discussion_replies_author_or_moderator_update
  on content.discussion_replies
  for update
  to authenticated
  using (
  author_id = auth.uid()
    or identity.is_platform_moderator()
  )
  with check (
  author_id = auth.uid()
    or identity.is_platform_moderator()
  );

-- ---------------------------------------------------------------------
-- content.poll_results: public aggregate
--
-- SECURITY DEFINER is required because poll_votes is self-read-only
-- while aggregation needs to count votes across all users.
-- ---------------------------------------------------------------------

create or replace function content.poll_results(
  p_poll_id uuid
)
  returns table (
                  option_id uuid,
                  label text,
                  vote_count bigint
                )
  language sql
  stable
  security definer
  set search_path = content, public
as $$
select
  o.id,
  o.label,
  count(v.user_id)
from content.poll_options o
       left join content.poll_votes v
                 on v.option_id = o.id
where o.poll_id = p_poll_id
group by
  o.id,
  o.label,
  o.display_order
order by
  o.display_order;
$$;

-- ---------------------------------------------------------------------
-- content.create_poll_with_options
--
-- A poll needs >= 2 options to be meaningful, and PostgREST can't do
-- a multi-table transactional insert in one call. This wraps poll +
-- options creation atomically rather than leaving the edge function
-- to do two separate inserts.
-- ---------------------------------------------------------------------

create or replace function content.create_poll_with_options(
  p_question text,
  p_options text[],
  p_closes_at timestamptz default null
)
  returns uuid
  language plpgsql
  security definer
  set search_path = content, identity, public
as $$
declare
  v_poll_id uuid;
  v_option text;
  v_order int := 0;
begin
  if not identity.is_platform_moderator() then
    raise exception
      'only a moderator or admin can create polls'
      using errcode = '42501';
  end if;

  if array_length(p_options, 1) is null
    or array_length(p_options, 1) < 2 then
    raise exception 'a poll needs at least 2 options';
  end if;

  insert into content.polls (
    question,
    created_by,
    closes_at
  )
  values (
           p_question,
           auth.uid(),
           p_closes_at
         )
  returning id into v_poll_id;

  foreach v_option in array p_options loop
      insert into content.poll_options (
        poll_id,
        label,
        display_order
      )
      values (
               v_poll_id,
               v_option,
               v_order
             );

      v_order := v_order + 1;
    end loop;

  return v_poll_id;
end;
$$;

grant execute on function content.create_poll_with_options(
  text,
  text[],
  timestamptz
  ) to authenticated;

-- ---------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------

grant usage on schema content
  to anon, authenticated;

grant select on content.news
  to anon, authenticated;

grant insert, update, delete on content.news
  to authenticated;

grant select on content.polls
  to anon, authenticated;

grant insert, update, delete on content.polls
  to authenticated;

grant select on content.poll_options
  to anon, authenticated;

grant insert, update, delete on content.poll_options
  to authenticated;

grant select on content.poll_votes
  to authenticated;

grant insert on content.poll_votes
  to authenticated;

grant select on content.discussions
  to anon, authenticated;

grant insert, update, delete on content.discussions
  to authenticated;

grant select on content.discussion_replies
  to anon, authenticated;

grant insert, update on content.discussion_replies
  to authenticated;

grant execute on function content.poll_results(uuid)
  to anon, authenticated;
