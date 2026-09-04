# Configuration Files

## tool-versions.json
The target minimum version for each toolchain tool. `bootstrap.ps1` (and later `bootstrap.sh`) reads this
file and passes it to each `check-*` script as `-RequiredVersion`. It is sufficient to update the version
here; there is no need to modify the script code.

Included tools:

- `deno` - the Deno runtime itself. **`Deno Lint` / `Deno Fmt` / `Deno Check` / `Deno Inspector` are NOT
  listed separately here** - they ship inside the same `deno` binary and are only verified (not installed)
  as their own steps; they always track `deno.minVersion`.
- `node` / `pnpm` - required for the `src/` React package (`pnpm install`, plus whatever `tsc` / `vite` /
  `orval` scripts need at runtime). `pnpm` is installed/pinned via `corepack`, not a package manager, so its
  `pkg` map is intentionally empty.
- `rustup` / `cargo` - kept **only** to carry `mdbook` (see below); nothing else in this devkit needs Rust.
- `mdbook` - kept from the Coreverse-Engine devkit for docs. Has no winget/pip-style package on any
  platform, only `cargo install --locked mdbook`, which is why `rustup`/`cargo` are still here.
- `semgrep` / `sqlfluff` - **optional** tools. Not installed unless approved via `-Accept`, `--all`, or an
  interactive Y/n answer (see `bootstrap.ps1 -Accept` / `-Reject`). `sqlfluff` covers both SQL lint/style
  and SQL static analysis (rules) - originally two list items, merged here since they're the same package.

`deno audit` is **not** listed in this file - it isn't a versioned tool, it's an optional action (dependency
vulnerability audit) that runs as the last step of the Deno dependency-resolution chain, after
`deno.json`/`deno.lock` has actually been resolved (see `scripts/dependencies/parse-deno.ps1`). It is still
one of the ids accepted by `-Accept` / `-Reject` (`deno-audit`).

- `pkg` (optional per-tool object): package-manager IDs for the future Linux/macOS `bootstrap.sh` side
  (`pacman` / `apt` / `dnf` / `zypper` / `brew`). An empty `{}` means "no OS package, upstream/official
  installer only" (matches how `rustup`/`cargo`/`mdbook`/`pnpm`/`sqlfluff` behave on Windows too).

## project-paths.json
The file that **must be updated** to point at the actual directory structure of the Coreverse-DB
repository. Both fields are shipped blank on purpose - fill in the real relative paths (relative to the
project root, i.e. the parent of `devkit/`) before running `bootstrap.ps1`:

- `denoFunctionsDir` : the directory containing `deno.json`/`deno.jsonc` for the Supabase Edge Functions
  (Deno) side of the project - e.g. `"supabase/functions"`.
- `pnpmPackageDir` : the directory containing `package.json` for the published `src/` React package - e.g.
  `"src"`.

If a field is left blank, the matching dependency-resolution step is skipped (with a warning), not treated
as an error - the toolchain phase still runs normally.

**Note:** `package.json`, `pnpm-lock.yaml`, `tsconfig.json`, and `orval.config.ts` under `pnpmPackageDir` are
never created or modified by this devkit - it only runs `pnpm install` against whatever is already there.
