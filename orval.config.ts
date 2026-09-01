import { defineConfig } from "orval";

// Two output targets from the same multi-file spec:
//  - coreverseDb:     typed fetch client + models, one file pair per tag
//                      (releases, teams, requests, profiles, projects,
//                      news, polls, discussions, docs) -- matches the
//                      Edge Functions' domain split 1:1.
//  - coreverseDbZod:  zod schemas generated from the same spec, kept
//                      separate from the fetch client so consumers that
//                      only want runtime validation (e.g. re-checking a
//                      webhook payload) don't have to pull in fetch code.
//
// swagger-parser (used internally by Orval) resolves the spec's external
// $refs (paths/*.yaml, schemas/*.yaml) itself, directly against
// openapi/openapi.yaml -- no separate bundle step needed here.
export default defineConfig({
  coreverseDb: {
    input: {
      target: "./openapi/openapi.yaml",
    },
    output: {
      mode: "tags-split",
      target: "./src/generated/endpoints",
      schemas: "./src/generated/models",
      client: "fetch",
      httpClient: "fetch",
      mock: false,
      clean: true,
      formatter: "prettier",
      override: {
        mutator: {
          path: "./src/client/http.ts",
          name: "coreverseFetch",
        },
      },
    },
  },
  coreverseDbZod: {
    input: {
      target: "./openapi/openapi.yaml",
    },
    output: {
      mode: "tags-split",
      target: "./src/generated/zod",
      client: "zod",
      clean: true,
      formatter: "prettier"
    },
  },
});
