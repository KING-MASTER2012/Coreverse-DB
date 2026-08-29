import { assert, assertFalse } from "@std/assert";
import {
  CreateTeamSchema,
  InviteSchema,
  MemberActionSchema,
  OwnershipTransferSchema,
  RenameTeamSchema,
  UuidSchema,
} from "./schemas.ts";

Deno.test("CreateTeamSchema accepts a non-empty name", () => {
  assert(CreateTeamSchema.safeParse({ name: "Coreverse Core" }).success);
});

Deno.test("CreateTeamSchema rejects an empty name", () => {
  assertFalse(CreateTeamSchema.safeParse({ name: "" }).success);
});

Deno.test("RenameTeamSchema rejects a name over 100 chars", () => {
  assertFalse(RenameTeamSchema.safeParse({ name: "x".repeat(101) }).success);
});

Deno.test("InviteSchema requires a valid uuid user_id", () => {
  assertFalse(InviteSchema.safeParse({ user_id: "not-a-uuid" }).success);
  assert(InviteSchema.safeParse({ user_id: "11111111-1111-1111-1111-111111111111" }).success);
});

Deno.test("OwnershipTransferSchema requires a valid uuid user_id", () => {
  assertFalse(OwnershipTransferSchema.safeParse({}).success);
});

Deno.test("MemberActionSchema only accepts promote/demote/remove", () => {
  assert(MemberActionSchema.safeParse({ action: "promote" }).success);
  assert(MemberActionSchema.safeParse({ action: "demote" }).success);
  assert(MemberActionSchema.safeParse({ action: "remove" }).success);
  assertFalse(MemberActionSchema.safeParse({ action: "delete" }).success);
});

Deno.test("UuidSchema rejects a plain string", () => {
  assertFalse(UuidSchema.safeParse("42").success);
});
