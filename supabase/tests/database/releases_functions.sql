-- Tests for releases.get_latest / list_releases / get_by_version.
--
-- Run with:
--   supabase test db
--
-- Requires the pgTAP extension.

select plan(7);

-- ---------------------------------------------------------------------
-- Test data
-- ---------------------------------------------------------------------
-- Create test versions above every existing release.
--
-- Existing max major = N
--
-- Test releases:
--   N+1.9.0   stable
--   N+1.10.0  stable
--   N+2.0.0   stable
--   N+2.1.0   deprecated
--
-- Therefore N+2.0.0 is guaranteed to be the highest stable test
-- release and cannot collide with existing releases.

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
  major::text || '.9.0',
  major,
  9,
  0,
  DATE '2026-01-01',
  'stable'
from base

union all

select
  major::text || '.10.0',
  major,
  10,
  0,
  DATE '2026-02-01',
  'stable'
from base

union all

select
  (major + 1)::text || '.0.0',
  major + 1,
  0,
  0,
  DATE '2026-03-01',
  'stable'
from base

union all

select
  (major + 1)::text || '.1.0',
  major + 1,
  1,
  0,
  DATE '2026-04-01',
  'deprecated'
from base;

-- ---------------------------------------------------------------------
-- Add one artifact to the highest-major test release
-- ---------------------------------------------------------------------

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
  r.id,
  'windows',
  'x86_64',
  'https://example.com/' || r.version,
  repeat('c', 64),
  1000,
  '{}'::jsonb,
  '{}'::jsonb
from releases.engine_releases r
where r.version_major = (
  select max(version_major)
  from releases.engine_releases
)
  and r.version_minor = 0
  and r.version_patch = 0
  and r.status = 'stable';

-- ---------------------------------------------------------------------
-- 1. get_latest
-- ---------------------------------------------------------------------
-- The highest-major test release is stable and must be returned.

select is(
         (
           select version
           from releases.get_latest('stable')
         ),
         (
           select r.version
           from releases.engine_releases r
           where r.version_major = (
             select max(version_major)
             from releases.engine_releases
           )
             and r.version_minor = 0
             and r.version_patch = 0
             and r.status = 'stable'
           limit 1
         ),
         'get_latest(''stable'') returns the highest stable version'
       );

-- ---------------------------------------------------------------------
-- 2. Numeric minor-version ordering
-- ---------------------------------------------------------------------
-- Verify that 10 is greater than 9 numerically.

select ok(
         (
           select r.version_minor
           from releases.engine_releases r
           where r.version_major = (
             select max(version_major) - 1
             from releases.engine_releases
           )
             and r.version_minor = 10
             and r.version_patch = 0
           limit 1
         )
           >
         (
           select r.version_minor
           from releases.engine_releases r
           where r.version_major = (
             select max(version_major) - 1
             from releases.engine_releases
           )
             and r.version_minor = 9
             and r.version_patch = 0
           limit 1
         ),
         'minor version 10 sorts after minor version 9 numerically'
       );

-- ---------------------------------------------------------------------
-- 3. Major-version ordering
-- ---------------------------------------------------------------------

select ok(
         (
           select max(r.version_major)
           from releases.engine_releases r
         )
           >
         (
           select max(r.version_major) - 1
           from releases.engine_releases r
         ),
         'higher major version sorts after lower major version'
       );

-- ---------------------------------------------------------------------
-- 4. get_by_version
-- ---------------------------------------------------------------------

select is(
         (
           select version
           from releases.get_by_version(
             (
               select r.version
               from releases.engine_releases r
               where r.version_major = (
                                         select max(version_major)
                                         from releases.engine_releases
                                       ) - 1
                 and r.version_minor = 9
                 and r.version_patch = 0
               limit 1
             )
                )
         ),
         (
           select r.version
           from releases.engine_releases r
           where r.version_major = (
                                     select max(version_major)
                                     from releases.engine_releases
                                   ) - 1
             and r.version_minor = 9
             and r.version_patch = 0
           limit 1
         ),
         'get_by_version returns the exact matching version'
       );

-- ---------------------------------------------------------------------
-- 5. get_by_version + nested artifacts
-- ---------------------------------------------------------------------

select is(
         (
           select jsonb_array_length(artifacts)
           from releases.get_by_version(
             (
               select r.version
               from releases.engine_releases r
               where r.version_major = (
                 select max(version_major)
                 from releases.engine_releases
               )
                 and r.version_minor = 0
                 and r.version_patch = 0
                 and r.status = 'stable'
               limit 1
             )
                )
         ),
         1,
         'get_by_version nests the correct number of artifacts'
       );

-- ---------------------------------------------------------------------
-- 6. Artifact fields
-- ---------------------------------------------------------------------

select is(
         (
           select artifacts -> 0 ->> 'os'
           from releases.get_by_version(
             (
               select r.version
               from releases.engine_releases r
               where r.version_major = (
                 select max(version_major)
                 from releases.engine_releases
               )
                 and r.version_minor = 0
                 and r.version_patch = 0
                 and r.status = 'stable'
               limit 1
             )
                )
         ),
         'windows',
         'get_by_version nests artifact fields correctly'
       );

-- ---------------------------------------------------------------------
-- 7. list_releases
-- ---------------------------------------------------------------------
-- NULL status means no status filter.

select is(
         (
           select count(*)::int
           from releases.list_releases(null, 1000, 0)
         ),
         (
           select count(*)::int
           from releases.engine_releases
         ),
         'list_releases(null, ...) returns all releases'
       );

select * from finish();
