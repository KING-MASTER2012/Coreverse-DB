import { assert, assertFalse, } from '@std/assert';
import { CastVoteSchema, CreatePollSchema, } from './schemas.ts';

const validPoll = { question: 'Vulkan or OpenGL?', options: ['Vulkan', 'OpenGL',], };

Deno.test('CreatePollSchema accepts a minimal valid poll', () => {
  assert(CreatePollSchema.safeParse(validPoll,).success,);
});

Deno.test('CreatePollSchema rejects a poll with only 1 option', () => {
  assertFalse(CreatePollSchema.safeParse({ ...validPoll, options: ['Only one',], },).success,);
});

Deno.test('CreatePollSchema rejects an empty question', () => {
  assertFalse(CreatePollSchema.safeParse({ ...validPoll, question: '', },).success,);
});

Deno.test('CreatePollSchema accepts a null closes_at', () => {
  assert(CreatePollSchema.safeParse({ ...validPoll, closes_at: null, },).success,);
});

Deno.test('CreatePollSchema rejects a non-datetime closes_at', () => {
  assertFalse(CreatePollSchema.safeParse({ ...validPoll, closes_at: 'next week', },).success,);
});

Deno.test('CastVoteSchema requires a valid uuid option_id', () => {
  assertFalse(CastVoteSchema.safeParse({ option_id: '1', },).success,);
  assert(
    CastVoteSchema.safeParse({ option_id: '550e8400-e29b-41d4-a716-446655440000', },).success,
  );
});
