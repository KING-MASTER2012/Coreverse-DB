-- RLS tests for the identity domain.
-- Run with: supabase test db

begin;

select plan(10);


-- ---------------------------------------------------------------------
-- Fixture users
-- ---------------------------------------------------------------------

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    'aaaaaaaa-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'rls-owner@example.com',
    crypt('x', gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'aaaaaaaa-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'rls-member@example.com',
    crypt('x', gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'aaaaaaaa-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'rls-outsider@example.com',
    crypt('x', gen_salt('bf')),
    now(),
    now(),
    now()
  )
on conflict (id) do nothing;


-- ---------------------------------------------------------------------
-- Team fixture
-- ---------------------------------------------------------------------

insert into identity.teams (
  id,
  name,
  created_by
)
values (
         'bbbbbbbb-0000-0000-0000-000000000001',
         'RLS Test Team',
         'aaaaaaaa-0000-0000-0000-000000000001'
       );


insert into identity.team_members (
  team_id,
  user_id,
  role
)
values
  (
    'bbbbbbbb-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001',
    'owner'
  ),
  (
    'bbbbbbbb-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000002',
    'member'
  );


-- ---------------------------------------------------------------------
-- profiles: public read, self-only write
-- ---------------------------------------------------------------------

set local role anon;

select isnt_empty(
         $$
        select 1
        from identity.profiles
        where id =
            'aaaaaaaa-0000-0000-0000-000000000001'
    $$,
         'anon can SELECT from profiles (public read)'
       );

reset role;


set local role authenticated;

set local "request.jwt.claims"
  to '{"sub":"aaaaaaaa-0000-0000-0000-000000000003","role":"authenticated"}';

update identity.profiles
set full_name = 'Hacked'
where id =
      'aaaaaaaa-0000-0000-0000-000000000001';

select is(
         (
           select full_name
           from identity.profiles
           where id =
                 'aaaaaaaa-0000-0000-0000-000000000001'
         ),
         '',
         'authenticated cannot UPDATE another user''s profile'
       );

reset role;


-- ---------------------------------------------------------------------
-- teams / team_members:
-- members-only read, no direct writes
-- ---------------------------------------------------------------------

set local role authenticated;

set local "request.jwt.claims"
  to '{"sub":"aaaaaaaa-0000-0000-0000-000000000002","role":"authenticated"}';

select isnt_empty(
         $$
        select 1
        from identity.teams
        where id =
            'bbbbbbbb-0000-0000-0000-000000000001'
    $$,
         'a team member can SELECT the team'
       );

select isnt_empty(
         $$
        select 1
        from identity.team_members
        where team_id =
            'bbbbbbbb-0000-0000-0000-000000000001'
    $$,
         'a team member can SELECT team_members'
       );

reset role;


set local role authenticated;

set local "request.jwt.claims"
  to '{"sub":"aaaaaaaa-0000-0000-0000-000000000003","role":"authenticated"}';

select is_empty(
         $$
        select 1
        from identity.teams
        where id =
            'bbbbbbbb-0000-0000-0000-000000000001'
    $$,
         'a non-member cannot SELECT the team'
       );


select throws_ok(
         $$
        insert into identity.team_members (
            team_id,
            user_id,
            role
        )
        values (
            'bbbbbbbb-0000-0000-0000-000000000001',
            'aaaaaaaa-0000-0000-0000-000000000003',
            'member'
        )
    $$,
         '42501',
         'permission denied for table team_members',
         'direct INSERT into team_members is blocked'
       );


select throws_ok(
         $$
        update identity.team_members
        set role = 'owner'
        where team_id =
            'bbbbbbbb-0000-0000-0000-000000000001'
          and user_id =
            'aaaaaaaa-0000-0000-0000-000000000002'
    $$,
         '42501',
         'permission denied for table team_members',
         'direct UPDATE on team_members is blocked'
       );

reset role;


-- ---------------------------------------------------------------------
-- projects:
-- owner + team-member read, owner-only write
-- ---------------------------------------------------------------------

insert into identity.projects (
  owner_id,
  team_id,
  name,
  archive_path,
  archive_size_bytes,
  archive_sha256
)
values (
         'aaaaaaaa-0000-0000-0000-000000000001',
         'bbbbbbbb-0000-0000-0000-000000000001',
         'rls-test-project',
         'project-archives/test.tar.zst',
         100,
         repeat('d', 64)
       );


set local role authenticated;

set local "request.jwt.claims"
  to '{"sub":"aaaaaaaa-0000-0000-0000-000000000002","role":"authenticated"}';

select isnt_empty(
         $$
        select 1
        from identity.projects
        where name = 'rls-test-project'
    $$,
         'a team member can SELECT a team-owned project'
       );


update identity.projects
set name = 'renamed'
where name = 'rls-test-project';


select is(
         (
           select name
           from identity.projects
           where name = 'rls-test-project'
         ),
         'rls-test-project',
         'a non-owner team member cannot UPDATE the project'
       );

reset role;


set local role authenticated;

set local "request.jwt.claims"
  to '{"sub":"aaaaaaaa-0000-0000-0000-000000000003","role":"authenticated"}';

select is_empty(
         $$
        select 1
        from identity.projects
        where name = 'rls-test-project'
    $$,
         'a non-member, non-owner cannot SELECT the project'
       );

reset role;


select * from finish();

rollback;
