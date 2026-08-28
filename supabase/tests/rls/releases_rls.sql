-- RLS tests for the releases domain.
-- Run with: supabase test db

begin;
select plan(9);

-- Setup as the migration/superuser role (bypasses RLS).
insert into releases.engine_releases
(version, version_major, version_minor, version_patch, release_date, status)
values ('9.9.9', 9, 9, 9, '2026-01-01', 'stable');

insert into releases.engine_artifacts
(release_id, os, architecture, download_url, sha256, size_bytes, min_requirements, compiler)
select id, 'linux', 'x86_64',
       'https://example.com/9.9.9.tar.gz',
       repeat('a', 64),
       1000,
       '{}'::jsonb,
  '{}'::jsonb
from releases.engine_releases where version = '9.9.9';

-- ---------------------------------------------------------------------
-- anon
-- ---------------------------------------------------------------------
set local role anon;

select isnt_empty(
         $$ select 1 from releases.engine_releases where version = '9.9.9' $$,
         'anon can SELECT from engine_releases'
       );

select isnt_empty(
         $$ select 1 from releases.engine_artifacts a
     join releases.engine_releases r on r.id = a.release_id
     where r.version = '9.9.9' $$,
         'anon can SELECT from engine_artifacts'
       );

select throws_ok(
         $$ insert into releases.engine_releases
       (version, version_major, version_minor, version_patch, release_date, status)
     values ('9.9.8', 9, 9, 8, '2026-01-01', 'stable') $$,
         '42501',
         'anon cannot INSERT into engine_releases'
       );

select throws_ok(
         $$ update releases.engine_releases set status = 'deprecated' where version = '9.9.9' $$,
         '42501',
         'anon cannot UPDATE engine_releases'
       );

select throws_ok(
         $$ delete from releases.engine_releases where version = '9.9.9' $$,
         '42501',
         'anon cannot DELETE from engine_releases'
       );

reset role;

-- ---------------------------------------------------------------------
-- authenticated
-- ---------------------------------------------------------------------
set local role authenticated;

select isnt_empty(
         $$ select 1 from releases.engine_releases where version = '9.9.9' $$,
         'authenticated can SELECT from engine_releases'
       );

select throws_ok(
         $$ insert into releases.engine_releases
       (version, version_major, version_minor, version_patch, release_date, status)
     values ('9.9.7', 9, 9, 7, '2026-01-01', 'stable') $$,
         '42501',
         'authenticated cannot INSERT into engine_releases'
       );

select throws_ok(
         $$ insert into releases.engine_artifacts
       (release_id, os, architecture, download_url, sha256, size_bytes, min_requirements, compiler)
     select id, 'linux', 'arm64', 'https://example.com/x', repeat('b', 64), 1, '{}'::jsonb, '{}'::jsonb
     from releases.engine_releases where version = '9.9.9' $$,
         '42501',
         'authenticated cannot INSERT into engine_artifacts'
       );

select throws_ok(
         $$ delete from releases.engine_artifacts
     using releases.engine_releases r
     where r.id = releases.engine_artifacts.release_id and r.version = '9.9.9' $$,
         '42501',
         'authenticated cannot DELETE from engine_artifacts'
       );

reset role;

select * from finish();
rollback;
