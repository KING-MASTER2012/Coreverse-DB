-- Tests for content domain functions and triggers.
-- Run with: supabase test db

begin;
select plan(6);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'ffffffff-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'func-mod@example.com', crypt('x', gen_salt('bf')), now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'ffffffff-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'func-voter1@example.com', crypt('x', gen_salt('bf')), now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'ffffffff-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'func-voter2@example.com', crypt('x', gen_salt('bf')), now(), now(), now())
  on conflict (id) do nothing;

insert into identity.platform_roles (user_id, role)
values ('ffffffff-0000-0000-0000-000000000001', 'moderator');

-- ---------------------------------------------------------------------
-- identity.is_platform_moderator()
-- ---------------------------------------------------------------------
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"ffffffff-0000-0000-0000-000000000001","role":"authenticated"}';

select ok(identity.is_platform_moderator(), 'is_platform_moderator() is true for a moderator');

reset role;
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"ffffffff-0000-0000-0000-000000000002","role":"authenticated"}';

select ok(not identity.is_platform_moderator(), 'is_platform_moderator() is false for a regular user');

reset role;

-- ---------------------------------------------------------------------
-- content.enforce_vote_option_matches_poll trigger
-- ---------------------------------------------------------------------
insert into content.polls (id, question, created_by)
values
  ('11223344-0000-0000-0000-000000000001', 'Poll A', 'ffffffff-0000-0000-0000-000000000001'),
  ('11223344-0000-0000-0000-000000000002', 'Poll B', 'ffffffff-0000-0000-0000-000000000001');

insert into content.poll_options (id, poll_id, label, display_order)
values
  ('11223344-0000-0000-0000-000000000011', '11223344-0000-0000-0000-000000000001', 'A1', 1),
  ('11223344-0000-0000-0000-000000000012', '11223344-0000-0000-0000-000000000001', 'A2', 2),
  ('11223344-0000-0000-0000-000000000021', '11223344-0000-0000-0000-000000000002', 'B1', 1);

select throws_like(
         $$ insert into content.poll_votes (poll_id, option_id, user_id)
     values ('11223344-0000-0000-0000-000000000001', '11223344-0000-0000-0000-000000000021', 'ffffffff-0000-0000-0000-000000000002') $$,
         '%does not belong to poll%',
         'voting with an option from a different poll is rejected'
       );

-- ---------------------------------------------------------------------
-- content.poll_results aggregation
-- ---------------------------------------------------------------------
insert into content.poll_votes (poll_id, option_id, user_id)
values
  ('11223344-0000-0000-0000-000000000001', '11223344-0000-0000-0000-000000000011', 'ffffffff-0000-0000-0000-000000000002'),
  ('11223344-0000-0000-0000-000000000001', '11223344-0000-0000-0000-000000000011', 'ffffffff-0000-0000-0000-000000000003');

select is(
  (select vote_count from content.poll_results('11223344-0000-0000-0000-000000000001')
  where option_id = '11223344-0000-0000-0000-000000000011'),
  2::bigint,
  'poll_results tallies votes for the chosen option correctly'
  );

select is(
  (select vote_count from content.poll_results('11223344-0000-0000-0000-000000000001')
  where option_id = '11223344-0000-0000-0000-000000000012'),
  0::bigint,
  'poll_results reports zero for an option with no votes'
  );

select is(
  (select count(*)::int from content.poll_results('11223344-0000-0000-0000-000000000001')),
  2,
  'poll_results returns exactly one row per option'
  );

select * from finish();
rollback;
