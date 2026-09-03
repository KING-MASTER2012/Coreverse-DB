## Summary

<!-- What does this PR change, and why? -->

## Domain(s) touched

<!-- releases / identity (profiles, teams, requests) / projects / content (news, polls, discussions) / docs / openapi+client (src/) / infrastructure -->

## Type of change

- [ ] Bug fix
- [ ] New feature (new endpoint, table, or field)
- [ ] Breaking change (existing endpoint/schema behavior changes)
- [ ] Migration / RLS policy change
- [ ] Generated client update only (`src/generated/**`, via `pnpm run generate`)
- [ ] CI/CD, docs, or tooling only

## Checklist

- [ ] If `openapi/**` changed, `src/generated/**` was regenerated (`pnpm run generate`) and committed — no drift (`pnpm run verify` passes locally).
- [ ] If `supabase/migrations/**` changed, matching pgTAP tests were added/updated under `supabase/tests/`.
- [ ] If Edge Function `schemas.ts` changed, `schemas.test.ts` was updated (`deno task test`).
- [ ] RLS implications considered for any new/changed table or policy.
- [ ] `pnpm run typecheck` passes.
- [ ] Linked issue referenced below (if any).

## Related issue

Closes #

## Notes for reviewers

<!-- Anything a reviewer should pay special attention to: security-sensitive RLS changes, backward compatibility, manual testing done, etc. -->
