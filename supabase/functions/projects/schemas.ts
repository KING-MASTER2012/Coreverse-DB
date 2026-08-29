import { z } from "zod";

// Client uploads the .tar.zst directly to the project-archives Storage
// bucket first, then registers the resulting metadata here -- this
// function never receives file bytes.
export const CreateProjectSchema = z.object({
  name: z.string().min(1).max(200),
  description: z.string().max(2000).nullable().optional(),
  team_id: z.string().uuid().nullable().optional(),
  archive_path: z.string().min(1),
  archive_size_bytes: z.coerce.number().int().positive(),
  archive_sha256: z.string().regex(/^[a-f0-9]{64}$/, "expected a lowercase 64-char hex sha256"),
});

export const UpdateProjectSchema = z.object({
  name: z.string().min(1).max(200).optional(),
  description: z.string().max(2000).nullable().optional(),
}).refine((body) => body.name !== undefined || body.description !== undefined, {
  message: "at least one of name or description must be provided",
});

export const UuidSchema = z.string().uuid();
