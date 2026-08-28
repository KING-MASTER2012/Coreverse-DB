// Validation schemas for the /releases edge function.
//
// Kept separate from index.ts so they can be unit tested (schemas.test.ts)
// without spinning up a Supabase client or network access.

import { z } from "zod";

export const VERSION_PATTERN = /^\d+\.\d+\.\d+$/;

export const STATUS_VALUES = ["stable", "beta", "rc", "deprecated"] as const;

export const VersionParamSchema = z
  .string()
  .regex(VERSION_PATTERN, "expected MAJOR.MINOR.PATCH, e.g. 1.4.2");

export const ListQuerySchema = z.object({
  status: z.enum(STATUS_VALUES).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export const LatestQuerySchema = z.object({
  status: z.enum(STATUS_VALUES).default("stable"),
});

export type ListQuery = z.infer<typeof ListQuerySchema>;
export type LatestQuery = z.infer<typeof LatestQuerySchema>;
