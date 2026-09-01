import { assert, assertFalse, } from '@std/assert';
import { UuidSchema, } from './schemas.ts';

Deno.test('UuidSchema accepts a valid uuid', () => {
  assert(UuidSchema.safeParse('11111111-1111-1111-1111-111111111111',).success,);
});

Deno.test('UuidSchema rejects a non-uuid string', () => {
  assertFalse(UuidSchema.safeParse('request-123',).success,);
});
