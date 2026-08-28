-- RLS tests for the releases domain.
--
-- Run with:
--   supabase test db
--
-- Requires the pgTAP extension.

select plan(9);

-- ---------------------------------------------------------------------
-- Setup as the migration/superuser role
-- ---------------------------------------------------------------------
-- Generate a version above every existing release.

with base as (
  select coalesce(max(version_major), 0) + 1 as major
  from releases.engine_releases
)
insert into releases.engine_releases
(
  version,
  version_major,
  version_minor,
  version_patch,
  release_date,
  status
)
select
  major::text || '.0.0',
  major,
  0,
  0,
  '2026-01-01',
  'stable'
from base;

-- Add an artifact belonging to the test release.

insert into releases.engine_artifacts
(
  release_id,
  os,
  architecture,
  download_url,
  sha256,
  size_bytes,
  min_requirements,
  compiler
)
select
  id,
  'linux',
  'x86_64',
  'https://example.com/rls-test.tar.gz',
  repeat('a', 64),
  1000,
  '{}'::jsonb,
  '{}'::jsonb
from releases.engine_releases
where version = (
  (
    select max(version_major)
    from releases.engine_releases
  )::text
    || '.0.0'
  );

-- ---------------------------------------------------------------------
-- Test-release helpers
-- ---------------------------------------------------------------------
-- The dynamically generated test release is always the highest major.

-- ---------------------------------------------------------------------
-- anon
-- ---------------------------------------------------------------------

set role anon;

-- 1
select isnt_empty(
         $$
    select 1
    from releases.engine_releases
    where version = (
      (
        select max(version_major)
        from releases.engine_releases
      )::text || '.0.0'
    )
  $$,
         'anon can SELECT from engine_releases'
       );

-- 2
select isnt_empty(
         $$
    select 1
    from releases.engine_artifacts a
    join releases.engine_releases r
      on r.id = a.release_id
    where r.version = (
      (
        select max(version_major)
        from releases.engine_releases
      )::text || '.0.0'
    )
  $$,
         'anon can SELECT from engine_artifacts'
       );

-- 3
select throws_ok(
         $$
    insert into releases.engine_releases
    (
      version,
      version_major,
      version_minor,
      version_patch,
      release_date,
      status
    )
    values
    (
      (
        (
          select max(version_major)
          from releases.engine_releases
        )::text || '.1.0'
      ),
      (
        select max(version_major)
        from releases.engine_releases
      ),
      1,
      0,
      '2026-01-01',
      'stable'
    )
  $$,
         '42501',
         NULL,
         'anon cannot INSERT into engine_releases'
       );

-- 4
select throws_ok(
         $$
    update releases.engine_releases
    set status = 'deprecated'
    where version = (
      (
        select max(version_major)
        from releases.engine_releases
      )::text || '.0.0'
    )
  $$,
         '42501',
         NULL,
         'anon cannot UPDATE engine_releases'
       );

-- 5
select throws_ok(
         $$
    delete from releases.engine_releases
    where version = (
      (
        select max(version_major)
        from releases.engine_releases
      )::text || '.0.0'
    )
  $$,
         '42501',
         NULL,
         'anon cannot DELETE from engine_releases'
       );

reset role;

-- ---------------------------------------------------------------------
-- authenticated
-- ---------------------------------------------------------------------

set role authenticated;

-- 6
select isnt_empty(
         $$
    select 1
    from releases.engine_releases
    where version = (
      (
        select max(version_major)
        from releases.engine_releases
      )::text || '.0.0'
    )
  $$,
         'authenticated can SELECT from engine_releases'
       );

-- 7
select throws_ok(
         $$
    insert into releases.engine_releases
    (
      version,
      version_major,
      version_minor,
      version_patch,
      release_date,
      status
    )
    values
    (
      (
        (
          select max(version_major)
          from releases.engine_releases
        )::text || '.2.0'
      ),
      (
        select max(version_major)
        from releases.engine_releases
      ),
      2,
      0,
      '2026-01-01',
      'stable'
    )
  $$,
         '42501',
         NULL,
         'authenticated cannot INSERT into engine_releases'
       );

-- 8
select throws_ok(
         $$
    insert into releases.engine_artifacts
    (
      release_id,
      os,
      architecture,
      download_url,
      sha256,
      size_bytes,
      min_requirements,
      compiler
    )
    select
      id,
      'linux',
      'arm64',
      'https://example.com/rejected.tar.gz',
      repeat('b', 64),
      1,
      '{}'::jsonb,
      '{}'::jsonb
    from releases.engine_releases
    where version = (
      (
        select max(version_major)
        from releases.engine_releases
      )::text || '.0.0'
    )
  $$,
         '42501',
         NULL,
         'authenticated cannot INSERT into engine_artifacts'
       );

-- 9
select throws_ok(
         $$
    delete from releases.engine_artifacts
    using releases.engine_releases r
    where r.id = releases.engine_artifacts.release_id
      and r.version = (
        (
          select max(version_major)
          from releases.engine_releases
        )::text || '.0.0'
      )
  $$,
         '42501',
         NULL,
         'authenticated cannot DELETE from engine_artifacts'
       );

reset role;

select * from finish();
