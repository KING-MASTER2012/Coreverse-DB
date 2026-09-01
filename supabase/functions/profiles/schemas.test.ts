import { assert, assertFalse, } from '@std/assert';
import { UpdateProfileSchema, } from './schemas.ts';

Deno.test('UpdateProfileSchema accepts full_name only', () => {
  assert(UpdateProfileSchema.safeParse({ full_name: 'Alice', },).success,);
});

Deno.test('UpdateProfileSchema accepts avatar_path only', () => {
  assert(UpdateProfileSchema.safeParse({ avatar_path: 'avatars/x.png', },).success,);
});

Deno.test('UpdateProfileSchema accepts null avatar_path (clearing it)', () => {
  assert(UpdateProfileSchema.safeParse({ avatar_path: null, },).success,);
});

Deno.test('UpdateProfileSchema rejects an empty body', () => {
  assertFalse(UpdateProfileSchema.safeParse({},).success,);
});

Deno.test('UpdateProfileSchema rejects an over-length full_name', () => {
  assertFalse(UpdateProfileSchema.safeParse({ full_name: 'x'.repeat(101,), },).success,);
});
