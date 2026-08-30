import { z } from "zod";

export const CreateDiscussionSchema = z.object({
  title: z.string().min(1).max(200),
  body: z.string().min(1),
  category: z.string().max(50).nullable().optional(),
});

export const UpdateDiscussionSchema = z.object({
  title: z.string().min(1).max(200).optional(),
  body: z.string().min(1).optional(),
  is_locked: z.boolean().optional(),
}).refine((b) => b.title !== undefined || b.body !== undefined || b.is_locked !== undefined, {
  message: "at least one field must be provided",
});

export const CreateReplySchema = z.object({
  body: z.string().min(1),
});

export const UpdateReplySchema = z.object({
  body: z.string().min(1).optional(),
  deleted: z.boolean().optional(),
}).refine((b) => b.body !== undefined || b.deleted !== undefined, {
  message: "at least one field must be provided",
});

export const UuidSchema = z.string().uuid();
