-- Releases domain: engine release metadata + per-platform artifacts.
--
-- Design notes:
--   * engine_releases holds release-level metadata only (no binaries, no
--     platform-specific data). One row per version.
--   * engine_artifacts holds one row per (release, os, architecture) with
--     the download_url / sha256 / size the Launcher needs to fetch and
--     verify the binary. A release can have zero or more artifacts.
--   * RLS: SELECT is public (anon + authenticated) since release metadata
--     is not sensitive and the Launcher checks for updates before a user
--     is signed in. No INSERT/UPDATE/DELETE policies exist for anon or
--     authenticated -- only service_role (which bypasses RLS) can write.

create schema if not exists releases;

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------

create table releases.engine_releases (
                                        id                    uuid primary key default gen_random_uuid(),
                                        version               text not null unique,
                                        version_major         int not null,
                                        version_minor         int not null,
                                        version_patch         int not null,
                                        release_date          date not null,
                                        release_notes_summary text,
                                        status                text not null default 'stable'
                                          check (status in ('stable', 'beta', 'rc', 'deprecated')),
                                        created_at            timestamptz not null default now(),
                                        updated_at            timestamptz not null default now()
);

comment on table releases.engine_releases is
  'Coreverse Engine release metadata. No binaries live here -- see engine_artifacts.';

create index idx_engine_releases_version_sort
  on releases.engine_releases (version_major desc, version_minor desc, version_patch desc);

create index idx_engine_releases_status
  on releases.engine_releases (status);

create table releases.engine_artifacts (
                                         id               uuid primary key default gen_random_uuid(),
                                         release_id       uuid not null references releases.engine_releases (id) on delete cascade,
                                         os               text not null check (os in ('windows', 'linux', 'macos')),
                                         architecture     text not null check (architecture in ('x86_64', 'arm64')),
                                         download_url     text not null,
                                         sha256           text not null check (sha256 ~ '^[a-f0-9]{64}$'),
                                         size_bytes       bigint not null check (size_bytes > 0),
                                         min_requirements jsonb not null,
                                         compiler         jsonb not null,
                                         created_at       timestamptz not null default now(),
                                         unique (release_id, os, architecture)
);

comment on table releases.engine_artifacts is
  'Per-OS/architecture downloadable artifact for a release. sha256 is used '
    'by the Launcher to verify binary integrity in case the distribution '
    'source (GitHub, CDN, etc.) is ever compromised.';

create index idx_engine_artifacts_release_id
  on releases.engine_artifacts (release_id);

-- ---------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------

create or replace function releases.set_updated_at()
  returns trigger
  language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_engine_releases_updated_at
  before update on releases.engine_releases
  for each row
execute function releases.set_updated_at();

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------

alter table releases.engine_releases enable row level security;
alter table releases.engine_artifacts enable row level security;

create policy engine_releases_public_read
  on releases.engine_releases
  for select
  to anon, authenticated
  using (true);

create policy engine_artifacts_public_read
  on releases.engine_artifacts
  for select
  to anon, authenticated
  using (true);

-- No INSERT/UPDATE/DELETE policies are defined for anon/authenticated on
-- either table. Writes are performed exclusively via service_role, which
-- bypasses RLS entirely (admin tooling / CI release pipeline).

-- ---------------------------------------------------------------------
-- Read functions
--
-- All three return the same row shape, with artifacts nested as a jsonb
-- array, matching the API's Release/Artifact schema 1:1.
-- ---------------------------------------------------------------------

create or replace function releases.get_by_version(p_version text)
  returns table (
                  id                    uuid,
                  version               text,
                  status                text,
                  release_date          date,
                  release_notes_summary text,
                  artifacts             jsonb
                )
  language sql
  stable
as $$
select
  r.id,
  r.version,
  r.status,
  r.release_date,
  r.release_notes_summary,
  coalesce(
      jsonb_agg(
      jsonb_build_object(
        'os', a.os,
        'architecture', a.architecture,
        'download_url', a.download_url,
        'sha256', a.sha256,
        'size_bytes', a.size_bytes,
        'min_requirements', a.min_requirements,
        'compiler', a.compiler
      )
               ) filter (where a.id is not null),
      '[]'::jsonb
  ) as artifacts
from releases.engine_releases r
       left join releases.engine_artifacts a on a.release_id = r.id
where r.version = p_version
group by r.id, r.version, r.status, r.release_date, r.release_notes_summary;
$$;

create or replace function releases.get_latest(p_status text default 'stable')
  returns table (
                  id                    uuid,
                  version               text,
                  status                text,
                  release_date          date,
                  release_notes_summary text,
                  artifacts             jsonb
                )
  language sql
  stable
as $$
select
  r.id,
  r.version,
  r.status,
  r.release_date,
  r.release_notes_summary,
  coalesce(
      jsonb_agg(
      jsonb_build_object(
        'os', a.os,
        'architecture', a.architecture,
        'download_url', a.download_url,
        'sha256', a.sha256,
        'size_bytes', a.size_bytes,
        'min_requirements', a.min_requirements,
        'compiler', a.compiler
      )
               ) filter (where a.id is not null),
      '[]'::jsonb
  ) as artifacts
from releases.engine_releases r
       left join releases.engine_artifacts a on a.release_id = r.id
where r.status = p_status
group by r.id, r.version, r.status, r.release_date, r.release_notes_summary, r.version_major, r.version_minor, r.version_patch
order by r.version_major desc, r.version_minor desc, r.version_patch desc
limit 1;
$$;

create or replace function releases.list_releases(
  p_status text default null,
  p_limit  int  default 20,
  p_offset int  default 0
)
  returns table (
                  id                    uuid,
                  version               text,
                  status                text,
                  release_date          date,
                  release_notes_summary text,
                  artifacts             jsonb
                )
  language sql
  stable
as $$
select
  r.id,
  r.version,
  r.status,
  r.release_date,
  r.release_notes_summary,
  coalesce(
      jsonb_agg(
      jsonb_build_object(
        'os', a.os,
        'architecture', a.architecture,
        'download_url', a.download_url,
        'sha256', a.sha256,
        'size_bytes', a.size_bytes,
        'min_requirements', a.min_requirements,
        'compiler', a.compiler
      )
               ) filter (where a.id is not null),
      '[]'::jsonb
  ) as artifacts
from releases.engine_releases r
       left join releases.engine_artifacts a on a.release_id = r.id
where p_status is null or r.status = p_status
group by r.id, r.version, r.status, r.release_date, r.release_notes_summary, r.version_major, r.version_minor, r.version_patch
order by r.version_major desc, r.version_minor desc, r.version_patch desc
limit p_limit
  offset p_offset;
$$;

-- ---------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------

grant usage on schema releases to anon, authenticated;

grant select on releases.engine_releases to anon, authenticated;
grant select on releases.engine_artifacts to anon, authenticated;

grant execute on function releases.get_by_version(text) to anon, authenticated;
grant execute on function releases.get_latest(text) to anon, authenticated;
grant execute on function releases.list_releases(text, int, int) to anon, authenticated;
