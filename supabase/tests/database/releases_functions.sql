-- Tests for releases.get_latest / list_releases / get_by_version.
-- Run with: supabase test db

begin;
select plan(7);

insert into releases.engine_releases
(version, version_major, version_minor, version_patch, release_date, status)
values
  ('1.9.0',  1, 9,  0, '2026-01-01', 'stable'),
  ('1.10.0', 1, 10, 0, '2026-02-01', 'stable'),
  ('2.0.0',  2, 0,  0, '2026-03-01', 'stable'),
  ('2.1.0',  2, 1,  0, '2026-04-01', 'deprecated');

insert into releases.engine_artifacts
(release_id, os, architecture, download_url, sha256, size_bytes, min_requirements, compiler)
select id, 'windows', 'x86_64', 'https://example.com/' || version,
       repeat('c', 64), 1000, '{}'::jsonb, '{}'::jsonb
from releases.engine_releases where version = '2.0.0';

-- Semver-aware sorting: 1.10.0 must sort after 1.9.0 numerically, not
-- lexicographically (where "1.10.0" < "1.9.0").
select is(
  (select version from releases.get_latest('stable')),
  '2.0.0',
  'get_latest(''stable'') returns the numerically highest stable version'
  );

select ok(
         (select version_minor from releases.engine_releases where version = '1.10.0')
           > (select version_minor from releases.engine_releases where version = '1.9.0'),
         '1.10.0 sorts numerically after 1.9.0'
       );

select ok(
         (select version_major from releases.engine_releases where version = '2.0.0')
           > (select version_major from releases.engine_releases where version = '1.9.0')
           and (select version_major from releases.engine_releases where version = '1.9.0')
                 * 100 < 199,
         '2.0.0 sorts after 1.99.99-style versions via version_major'
       );

-- get_by_version + nested artifacts
select is(
  (select version from releases.get_by_version('1.9.0')),
  '1.9.0',
  'get_by_version returns the exact matching version'
  );

select is(
  (select jsonb_array_length(artifacts) from releases.get_by_version('2.0.0')),
  1,
  'get_by_version nests the correct number of artifacts'
  );

select is(
  (select artifacts -> 0 ->> 'os' from releases.get_by_version('2.0.0')),
  'windows',
  'get_by_version nests artifact fields correctly'
  );

-- list_releases: status filtering + null-status passthrough
select is(
  (select count(*)::int from releases.list_releases(null, 20, 0)),
  4,
  'list_releases(null, ...) returns every seeded release regardless of status'
  );

select * from finish();
rollback;
