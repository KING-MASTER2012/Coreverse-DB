#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/../common/logger.sh"

# Resolves Deno dependencies (deno.json/deno.lock) for the Supabase Edge
# Functions side of the project, then - if approved - runs `deno audit` as
# the last step of the same chain.
#
# The result file may hold TWO blocks ('Deno Deps' and 'deno audit' when
# --run-audit is set), separated by a blank line - summary-table.sh already
# supports multiple blocks per .result file (see parse-cargo.sh precedent).
#
# `deno audit` is intentionally run here (against a freshly resolved
# deno.lock), not in the toolchain installation phase - it needs a current
# lockfile to audit against, and the toolchain phase runs before any
# lockfile has been resolved.
#
# NOTE: assumes check-deno.sh has already completed successfully.

FUNCTIONS_DIR=""
RUN_AUDIT="false"
DRY_RUN="false"
RESULT_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --functions-dir) FUNCTIONS_DIR="$2"; shift 2 ;;
        --run-audit) RUN_AUDIT="true"; shift ;;
        --dry-run) DRY_RUN="true"; shift ;;
        --result-file) RESULT_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

write_block() {
    local tool="$1" status="$2" version="$3"
    [ -z "$RESULT_FILE" ] && return 0
    mkdir -p "$(dirname "$RESULT_FILE")"
    {
        printf 'TOOL=%s\nSTATUS=%s\nVERSION=%s\n\n' "$tool" "$status" "$version"
    } >> "$RESULT_FILE"
}

# Start the result file fresh (write_block appends).
[ -n "$RESULT_FILE" ] && { mkdir -p "$(dirname "$RESULT_FILE")"; : > "$RESULT_FILE"; }

DEP_TOOL="Deno Dependencies"

if [ -z "$FUNCTIONS_DIR" ] || [ "$FUNCTIONS_DIR" = "null" ]; then
    log_warning "'denoFunctionsDir' is not set in config/project-paths.json. Skipping." "$DEP_TOOL"
    write_block "$DEP_TOOL" "Skipped" ""
    exit 0
fi

if [ ! -f "$FUNCTIONS_DIR/deno.json" ] && [ ! -f "$FUNCTIONS_DIR/deno.jsonc" ]; then
    log_warning "No deno.json/deno.jsonc found under '$FUNCTIONS_DIR'. Skipping." "$DEP_TOOL"
    write_block "$DEP_TOOL" "Skipped" ""
    exit 0
fi

export PATH="$PATH:$HOME/.deno/bin"

if ! command -v deno >/dev/null 2>&1; then
    log_error "deno not found on PATH. The toolchain phase must be completed first." "$DEP_TOOL"
    write_block "$DEP_TOOL" "Failed" ""
    exit 0
fi

if [ "$DRY_RUN" = "true" ]; then
    log_info "[DryRun] In '$FUNCTIONS_DIR', 'deno install' was to be run." "$DEP_TOOL"
    write_block "$DEP_TOOL" "DryRun" ""
    [ "$RUN_AUDIT" = "true" ] && write_block "deno audit" "DryRun" ""
    exit 0
fi

DEP_STATUS="Failed"
(
    cd "$FUNCTIONS_DIR" || exit 1
    log_info "deno install running..." "$DEP_TOOL"
    deno install
)
if [ $? -eq 0 ]; then
    DEP_STATUS="OK"
    log_success "Deno dependencies resolved." "$DEP_TOOL"
else
    log_error "deno install ended with an error." "$DEP_TOOL"
fi
write_block "$DEP_TOOL" "$DEP_STATUS" ""

if [ "$RUN_AUDIT" != "true" ]; then
    exit 0
fi

AUDIT_TOOL="deno audit"

if [ "$DEP_STATUS" != "OK" ]; then
    log_warning "Skipped: dependency resolution did not complete successfully." "$AUDIT_TOOL"
    write_block "$AUDIT_TOOL" "Skipped" ""
    exit 0
fi

(
    cd "$FUNCTIONS_DIR" || exit 1
    log_info "deno audit running..." "$AUDIT_TOOL"
    deno audit
)
AUDIT_EXIT=$?

if [ "$AUDIT_EXIT" -eq 0 ]; then
    log_success "No known vulnerabilities reported." "$AUDIT_TOOL"
    write_block "$AUDIT_TOOL" "OK" ""
else
    # deno audit exits non-zero when it finds vulnerabilities - treat this
    # as a Warning (surface it, don't fail the whole bootstrap).
    log_warning "deno audit reported findings (exit code $AUDIT_EXIT). Review the output above." "$AUDIT_TOOL"
    write_block "$AUDIT_TOOL" "Warning" ""
fi
