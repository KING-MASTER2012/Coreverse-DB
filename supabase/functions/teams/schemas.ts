import { z, } from 'zod';

export const CreateTeamSchema = z.object({
  name: z.string().min(1,).max(100,),
},);

export const RenameTeamSchema = z.object({
  name: z.string().min(1,).max(100,),
},);

export const InviteSchema = z.object({
  user_id: z.string().uuid(),
},);

export const OwnershipTransferSchema = z.object({
  user_id: z.string().uuid(),
},);

export const MemberActionSchema = z.object({
  action: z.enum(['promote', 'demote', 'remove',],),
},);

export const UuidSchema = z.string().uuid();
