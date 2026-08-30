import { z } from "zod";

export const CreatePollSchema = z.object({
  question: z.string().min(1).max(300),
  closes_at: z.string().datetime().nullable().optional(),
  options: z.array(z.string().min(1).max(120)).min(2).max(20),
});

export const CastVoteSchema = z.object({
  option_id: z.string().uuid(),
});

export const UuidSchema = z.string().uuid();
