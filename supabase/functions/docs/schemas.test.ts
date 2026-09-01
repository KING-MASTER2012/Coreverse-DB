import { assert, assertEquals, assertFalse, } from '@std/assert';
import { ReindexBodySchema, SearchQuerySchema, } from './schemas.ts';

Deno.test('SearchQuerySchema requires a non-empty q', () => {
  assertFalse(SearchQuerySchema.safeParse({},).success,);
  assert(SearchQuerySchema.safeParse({ q: 'vulkan', },).success,);
});

Deno.test('SearchQuerySchema defaults limit to 20', () => {
  const result = SearchQuerySchema.parse({ q: 'x', },);
  assertEquals(result.limit, 20,);
});

Deno.test('SearchQuerySchema rejects a limit above 50', () => {
  assertFalse(SearchQuerySchema.safeParse({ q: 'x', limit: '100', },).success,);
});

Deno.test('SearchQuerySchema rejects an unknown kind', () => {
  assertFalse(SearchQuerySchema.safeParse({ q: 'x', kind: 'blog', },).success,);
});

const validReindexBody = {
  source: {
    kind: 'engine_mdbook',
    title: 'Engine Docs',
    slug: 'engine',
    base_url: 'https://docs.example.com/engine/',
  },
  pages: [{ path: 'intro', title: 'Intro', },],
};

Deno.test('ReindexBodySchema accepts a minimal valid body', () => {
  assert(ReindexBodySchema.safeParse(validReindexBody,).success,);
});

Deno.test('ReindexBodySchema rejects an uppercase slug', () => {
  assertFalse(
    ReindexBodySchema.safeParse({
      ...validReindexBody,
      source: { ...validReindexBody.source, slug: 'Engine-Docs', },
    },).success,
  );
});

Deno.test('ReindexBodySchema rejects an empty pages array', () => {
  assertFalse(ReindexBodySchema.safeParse({ ...validReindexBody, pages: [], },).success,);
});

Deno.test('ReindexBodySchema rejects a non-url base_url', () => {
  assertFalse(
    ReindexBodySchema.safeParse({
      ...validReindexBody,
      source: { ...validReindexBody.source, base_url: 'not-a-url', },
    },).success,
  );
});
