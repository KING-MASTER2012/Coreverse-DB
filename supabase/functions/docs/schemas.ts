import { z } from "zod";

export const SearchQuerySchema = z.object({
  q: z.string().min(1),
  kind: z.enum(["engine_mdbook", "tutorial", "other"]).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export const ReindexBodySchema = z.object({
  source: z.object({
    kind: z.enum(["engine_mdbook", "tutorial", "other"]),
    title: z.string().min(1).max(200),
    slug: z.string().min(1).max(100).regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, "expected a lowercase, hyphenated slug"),
    base_url: z.string().url(),
    current_version_ref: z.string().nullable().optional(),
  }),
  pages: z.array(z.object({
    path: z.string().min(1),
    title: z.string().min(1),
    content_text: z.string().optional(),
  })).min(1),
});
