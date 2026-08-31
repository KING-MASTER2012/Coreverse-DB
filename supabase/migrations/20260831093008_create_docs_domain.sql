-- Docs domain: a catalog + full-text search INDEX over documentation that
-- lives elsewhere (mdBook output in the coreverse-engine repo and, per
-- the plan, tutorial repos -- also mdBook-based). This schema never
-- stores rendered pages, only enough plain text to search and produce a
-- snippet; the actual page is always read from source.base_url + path.
--
-- Writes happen exclusively through the docs-reindex edge function,
-- authenticated with a shared secret (not a user session) and called
-- from those other repos' CI after their mdBook build -- not through a
-- distributed Supabase service-role key. See that function's comment
-- for the full rationale.
--
-- Text search uses the 'simple' (language-agnostic) config rather than
-- 'english', since content spans Turkish and English and 'english'
-- stemming would misparse Turkish text.

create schema if not exists docs;

create table docs.sources (
                            id                   uuid primary key default gen_random_uuid(),
                            kind                 text not null check (kind in ('engine_mdbook', 'tutorial', 'other')),
                            title                text not null,
                            slug                 text not null unique,
                            base_url             text not null,
                            current_version_ref  text,
                            created_at           timestamptz not null default now(),
                            updated_at           timestamptz not null default now()
);

comment on table docs.sources is
  'One row per documentation site (e.g. the engine mdBook, a tutorial mdBook).';

create table docs.pages (
                          id             uuid primary key default gen_random_uuid(),
                          source_id      uuid not null references docs.sources (id) on delete cascade,
                          path           text not null,
                          title          text not null,
                          content_text   text,
                          search_vector  tsvector generated always as
                            (to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(content_text, '')))
                            stored,
                          updated_at     timestamptz not null default now(),
                          unique (source_id, path)
);

comment on table docs.pages is
  'Search index only -- content_text is plain text for search/snippets, '
    'not the rendered page. Read the real page at sources.base_url || path.';

create index idx_docs_pages_search on docs.pages using gin (search_vector);
create index idx_docs_pages_source_id on docs.pages (source_id);

-- ---------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------

create or replace function docs.set_updated_at()
  returns trigger
  language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_docs_sources_updated_at
  before update on docs.sources
  for each row execute function docs.set_updated_at();

create trigger trg_docs_pages_updated_at
  before update on docs.pages
  for each row execute function docs.set_updated_at();

-- ---------------------------------------------------------------------
-- Row Level Security: public read, no anon/authenticated write policies
-- at all -- only service_role (via the reindex edge function) writes.
-- ---------------------------------------------------------------------

alter table docs.sources enable row level security;
alter table docs.pages enable row level security;

create policy "docs_sources_public_read"
  on docs.sources for select
  to anon, authenticated
  using (true);

create policy "docs_pages_public_read"
  on docs.pages for select
  to anon, authenticated
  using (true);

-- ---------------------------------------------------------------------
-- docs.search: full-text search with a plain-text snippet.
-- ---------------------------------------------------------------------

create or replace function docs.search(
  p_query       text,
  p_source_kind text default null,
  p_limit       int default 20
)
  returns table (
                  page_id     uuid,
                  source_id   uuid,
                  source_slug text,
                  path        text,
                  title       text,
                  snippet     text,
                  rank        real
                )
  language sql
  stable
as $$
select
  p.id,
  p.source_id,
  s.slug,
  p.path,
  p.title,
  ts_headline(
    'simple',
    coalesce(p.content_text, ''),
    plainto_tsquery('simple', p_query),
    'MaxFragments=1, MaxWords=30, MinWords=10'
  ),
  ts_rank(p.search_vector, plainto_tsquery('simple', p_query))
from docs.pages p
       join docs.sources s on s.id = p.source_id
where p.search_vector @@ plainto_tsquery('simple', p_query)
  and (p_source_kind is null or s.kind = p_source_kind)
order by ts_rank(p.search_vector, plainto_tsquery('simple', p_query)) desc
limit p_limit;
$$;

-- ---------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------

grant usage on schema docs to anon, authenticated;
grant select on docs.sources to anon, authenticated;
grant select on docs.pages to anon, authenticated;
grant execute on function docs.search(text, text, int) to anon, authenticated;
