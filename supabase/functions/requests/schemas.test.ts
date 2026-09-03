import { assert, assertFalse, } from '@std/assert';
import { UuidSchema, } from './schemas.ts';

Deno.test('UuidSchema accepts a valid uuid', () => {
  assert(UuidSchema.safeParse('7c9e6679-7425-40de-944b-e07fc5f90ae7',).success,);
});

Deno.test('UuidSchema rejects a non-uuid string', () => {
  assertFalse(UuidSchema.safeParse('request-123',).success,);
});
