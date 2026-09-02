export { configureCoreverseClient, CoreverseApiError } from "./client/http";
export type { CoreverseClientConfig, CoreverseErrorBody } from "./client/http";

// The lines below are what `pnpm run generate` (Orval, see orval.config.ts)
// produces under src/generated/ -- one endpoints module per OpenAPI tag,
// `tags-split` mode, mirroring the Edge Functions' domain split:
//
// export * from "./generated/endpoints/releases/releases.ts";
// export * from "./generated/endpoints/teams/teams.ts";
// export * from "./generated/endpoints/requests/requests.ts";
// export * from "./generated/endpoints/profiles/profiles.ts";
// export * from "./generated/endpoints/projects/projects.ts";
// export * from "./generated/endpoints/news/news.ts";
// export * from "./generated/endpoints/polls/polls.ts";
// export * from "./generated/endpoints/discussions/discussions.ts";
// export * from "./generated/endpoints/docs/docs.ts";
//
// They're commented out rather than guessed at, because this sandbox has
// no network access to actually run Orval and confirm the exact file
// names it emits for this Orval version -- see the note left in
// src/generated/.gitkeep. Uncomment (or regenerate this file) once you've
// run `pnpm install && pnpm run generate` locally and can see what landed
// under src/generated/endpoints/.
