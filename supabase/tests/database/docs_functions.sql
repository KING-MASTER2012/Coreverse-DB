-- Tests for docs.search().
-- Run with: supabase test db

begin;

select plan(5);

insert into docs.sources (
  id,
  kind,
  title,
  slug,
  base_url
)
values
  (
    '13131313-0000-0000-0000-000000000001',
    'engine_mdbook',
    'Engine Docs',
    'search-test-engine',
    'https://example.com/engine/'
  ),
  (
    '13131313-0000-0000-0000-000000000002',
    'tutorial',
    'Tutorials',
    'search-test-tutorials',
    'https://example.com/tutorials/'
  );

insert into docs.pages (
  source_id,
  path,
  title,
  content_text
)
values
  (
    '13131313-0000-0000-0000-000000000001',
    'engine-search-alpha',
    'Engine Search Alpha',
    'searchalpha documentation fixture'
  ),
  (
    '13131313-0000-0000-0000-000000000001',
    'opengl-setup',
    'OpenGL Setup',
    'renderer context and swapchain setup'
  ),
  (
    '13131313-0000-0000-0000-000000000002',
    'tutorial-search-beta',
    'Tutorial Search Beta',
    'searchalpha tutorial fixture'
  );

-- ---------------------------------------------------------------------
-- Search across all sources by default.
-- ---------------------------------------------------------------------

select is(
         (
           select count(*)::int
           from docs.search('searchalpha')
         ),
         2,
         'docs.search matches pages across all sources by default'
       );

-- ---------------------------------------------------------------------
-- kind filter narrows results.
-- ---------------------------------------------------------------------

select is(
         (
           select count(*)::int
           from docs.search('searchalpha', 'tutorial')
         ),
         1,
         'docs.search filters by source kind when provided'
       );

select is(
         (
           select title
           from docs.search('searchalpha', 'engine_mdbook')
           limit 1
         ),
         'Engine Search Alpha',
         'docs.search returns the expected page for a kind-scoped query'
       );

-- ---------------------------------------------------------------------
-- No match for an unrelated term.
-- ---------------------------------------------------------------------

select is(
         (
           select count(*)::int
           from docs.search('nonexistentterm12345')
         ),
         0,
         'docs.search returns no rows for a term that matches nothing'
       );

-- ---------------------------------------------------------------------
-- limit is respected.
-- ---------------------------------------------------------------------

select is(
         (
           select count(*)::int
           from docs.search('searchalpha', null, 1)
         ),
         1,
         'docs.search respects the p_limit parameter'
       );

select * from finish();

rollback;
