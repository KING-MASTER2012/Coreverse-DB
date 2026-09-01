import { assert, assertFalse, } from '@std/assert';
import {
  CreateDiscussionSchema,
  CreateReplySchema,
  UpdateDiscussionSchema,
  UpdateReplySchema,
} from './schemas.ts';

Deno.test('CreateDiscussionSchema accepts a minimal valid body', () => {
  assert(CreateDiscussionSchema.safeParse({ title: 'T', body: 'b', },).success,);
});

Deno.test('CreateDiscussionSchema rejects an empty title', () => {
  assertFalse(CreateDiscussionSchema.safeParse({ title: '', body: 'b', },).success,);
});

Deno.test('UpdateDiscussionSchema rejects an empty body', () => {
  assertFalse(UpdateDiscussionSchema.safeParse({},).success,);
});

Deno.test('UpdateDiscussionSchema accepts is_locked-only update', () => {
  assert(UpdateDiscussionSchema.safeParse({ is_locked: true, },).success,);
});

Deno.test('CreateReplySchema rejects an empty body', () => {
  assertFalse(CreateReplySchema.safeParse({ body: '', },).success,);
});

Deno.test('UpdateReplySchema accepts deleted-only update', () => {
  assert(UpdateReplySchema.safeParse({ deleted: true, },).success,);
});

Deno.test('UpdateReplySchema rejects an empty body', () => {
  assertFalse(UpdateReplySchema.safeParse({},).success,);
});
