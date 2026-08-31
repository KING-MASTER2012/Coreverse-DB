-- RLS tests for the docs domain.
-- Run with: supabase test db

begin;

select plan(6);

insert into docs.sources (
  id,
  kind,
  title,
  slug,
  base_url
)
values (
         '12121212-0000-0000-0000-000000000001',
         'engine_mdbook',
         'RLS Test Docs',
         'rls-test-docs',
         'https://example.com/'
       );

insert into docs.pages (
  source_id,
  path,
  title,
  content_text
)
values (
         '12121212-0000-0000-0000-000000000001',
         'page-one',
         'Page One',
         'searchable content here'
       );

-- ---------------------------------------------------------------------
-- public read
-- ---------------------------------------------------------------------

set local role anon;

select isnt_empty(
         $$
    select 1
    from docs.sources
    where slug = 'rls-test-docs'
    $$,
         'anon can SELECT docs.sources'
       );

select isnt_empty(
         $$
    select 1
    from docs.pages
    where path = 'page-one'
    $$,
         'anon can SELECT docs.pages'
       );

reset role;

-- ---------------------------------------------------------------------
-- no direct writes for anon/authenticated -- only service_role
-- ---------------------------------------------------------------------

set local role anon;

select throws_ok(
         $$
    insert into docs.sources (
        kind,
        title,
        slug,
        base_url
    )
    values (
        'other',
        'Hack',
        'hack-slug',
        'https://evil.example.com/'
    )
    $$,
         '42501',
         null,
         'anon cannot INSERT into docs.sources'
       );

reset role;

set local role authenticated;

set local "request.jwt.claims" =
  '{"sub":"12121212-0000-0000-0000-000000000099","role":"authenticated"}';

select throws_ok(
         $$
    insert into docs.pages (
        source_id,
        path,
        title
    )
    values (
        '12121212-0000-0000-0000-000000000001',
        'hacked-page',
        'Hacked'
    )
    $$,
         '42501',
         null,
         'an authenticated user cannot INSERT into docs.pages'
       );

select throws_ok(
         $$
    update docs.sources
    set title = 'hijacked'
    where slug = 'rls-test-docs'
    $$,
         '42501',
         null,
         'an authenticated user cannot UPDATE docs.sources'
       );

reset role;

-- ---------------------------------------------------------------------
-- docs.search is callable by anon
-- ---------------------------------------------------------------------

set local role anon;

select isnt_empty(
         $$
    select 1
    from docs.search('searchable')
    $$,
         'anon can call docs.search() and get a match'
       );

reset role;

select * from finish();

rollback;
