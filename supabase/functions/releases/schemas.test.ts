import { assert, assertEquals, assertFalse, } from '@std/assert';
import { LatestQuerySchema, ListQuerySchema, VersionParamSchema, } from './schemas.ts';

Deno.test('VersionParamSchema accepts a valid semver', () => {
  assert(VersionParamSchema.safeParse('1.4.2',).success,);
});

Deno.test('VersionParamSchema rejects a missing patch segment', () => {
  assertFalse(VersionParamSchema.safeParse('1.4',).success,);
});

Deno.test('VersionParamSchema rejects an extra segment', () => {
  assertFalse(VersionParamSchema.safeParse('1.4.2.3',).success,);
});

Deno.test('VersionParamSchema rejects non-numeric input', () => {
  assertFalse(VersionParamSchema.safeParse('foo',).success,);
});

Deno.test('ListQuerySchema applies default limit/offset', () => {
  const result = ListQuerySchema.parse({},);
  assertEquals(result.limit, 20,);
  assertEquals(result.offset, 0,);
});

Deno.test('ListQuerySchema rejects a limit above 100', () => {
  assertFalse(ListQuerySchema.safeParse({ limit: '500', },).success,);
});

Deno.test('ListQuerySchema rejects an unknown status value', () => {
  assertFalse(ListQuerySchema.safeParse({ status: 'nightly', },).success,);
});

Deno.test('LatestQuerySchema defaults status to stable', () => {
  const result = LatestQuerySchema.parse({},);
  assertEquals(result.status, 'stable',);
});
