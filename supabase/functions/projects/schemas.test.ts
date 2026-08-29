import { assert, assertFalse } from "@std/assert";
import { CreateProjectSchema, UpdateProjectSchema, UuidSchema } from "./schemas.ts";

const validCreateBody = {
  name: "sample-project",
  archive_path: "project-archives/x/sample-project.tar.zst",
  archive_size_bytes: 1024,
  archive_sha256: "a".repeat(64),
};

Deno.test("CreateProjectSchema accepts a minimal valid body", () => {
  assert(CreateProjectSchema.safeParse(validCreateBody).success);
});

Deno.test("CreateProjectSchema rejects a short sha256", () => {
  assertFalse(
    CreateProjectSchema.safeParse({ ...validCreateBody, archive_sha256: "abc" }).success,
  );
});

Deno.test("CreateProjectSchema rejects an uppercase sha256", () => {
  assertFalse(
    CreateProjectSchema.safeParse({ ...validCreateBody, archive_sha256: "A".repeat(64) }).success,
  );
});

Deno.test("CreateProjectSchema rejects a non-positive size", () => {
  assertFalse(
    CreateProjectSchema.safeParse({ ...validCreateBody, archive_size_bytes: 0 }).success,
  );
});

Deno.test("CreateProjectSchema accepts an optional null team_id", () => {
  assert(CreateProjectSchema.safeParse({ ...validCreateBody, team_id: null }).success);
});

Deno.test("UpdateProjectSchema rejects an empty body", () => {
  assertFalse(UpdateProjectSchema.safeParse({}).success);
});

Deno.test("UpdateProjectSchema accepts description-only update", () => {
  assert(UpdateProjectSchema.safeParse({ description: "updated" }).success);
});

Deno.test("UuidSchema rejects a non-uuid team_id", () => {
  assertFalse(UuidSchema.safeParse("not-a-uuid").success);
});
