import { z, } from 'zod';

export const CreateNewsSchema = z.object({
  title: z.string().min(1,).max(200,),
  slug: z.string().min(1,).max(200,).regex(
    /^[a-z0-9]+(-[a-z0-9]+)*$/,
    'expected a lowercase, hyphenated slug',
  ),
  body: z.string().min(1,),
},);

export const UpdateNewsSchema = z.object({
  title: z.string().min(1,).max(200,).optional(),
  body: z.string().min(1,).optional(),
  status: z.enum(['draft', 'published',],).optional(),
},).refine((b,) => b.title !== undefined || b.body !== undefined || b.status !== undefined, {
  message: 'at least one field must be provided',
},);

export const UuidSchema = z.string().uuid();
