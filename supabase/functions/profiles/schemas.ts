import { z, } from 'zod';

// Client only ever sends us a Storage path (after uploading the PNG
// directly to the avatars bucket) -- never raw image bytes.
export const UpdateProfileSchema = z.object({
  full_name: z.string().min(1,).max(100,).optional(),
  avatar_path: z.string().min(1,).nullable().optional(),
},).refine((body,) => body.full_name !== undefined || body.avatar_path !== undefined, {
  message: 'at least one of full_name or avatar_path must be provided',
},);
