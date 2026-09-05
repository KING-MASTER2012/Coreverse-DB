#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/../common/logger.sh"

# Installs dependencies for the src/ React package via pnpm. Only runs
# 'pnpm install' - package.json / pnpm-lock.yaml / tsconfig.json /
# orval.config.ts already exist in the project and are never written or
# modified by this script.
#
# NOTE: assumes check-node.sh and check-pnpm.sh have already completed
# successfully.

TOOL_NAME="pnpm Dependencies"
PACKAGE_DIR=""
DRY_RUN="false"
RESULT_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --package-dir) PACKAGE_DIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN="true"; shift ;;
        --result-file) RESULT_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

write_result() {
    local status="$1"
    [ -z "$RESULT_FILE" ] && return 0
    mkdir -p "$(dirname "$RESULT_FILE")"
    printf 'TOOL=%s\nSTATUS=%s\nVERSION=%s\n' "$TOOL_NAME" "$status" "" > "$RESULT_FILE"
}

if [ -z "$PACKAGE_DIR" ] || [ "$PACKAGE_DIR" = "null" ]; then
    log_warning "'pnpmPackageDir' is not set in config/project-paths.json. Skipping." "$TOOL_NAME"
    write_result "Skipped"
    exit 0
fi

if [ ! -f "$PACKAGE_DIR/package.json" ]; then
    log_warning "No package.json found under '$PACKAGE_DIR'. Skipping." "$TOOL_NAME"
    write_result "Skipped"
    exit 0
fi

if ! command -v pnpm >/dev/null 2>&1; then
    log_error "pnpm not found on PATH. The toolchain phase must be completed first." "$TOOL_NAME"
    write_result "Failed"
    exit 0
fi

if [ "$DRY_RUN" = "true" ]; then
    log_info "[DryRun] In '$PACKAGE_DIR', 'pnpm install' was to be run." "$TOOL_NAME"
    write_result "DryRun"
    exit 0
fi

(
    cd "$PACKAGE_DIR" || exit 1
    log_info "pnpm install running..." "$TOOL_NAME"
    pnpm install
)

if [ $? -eq 0 ]; then
    log_success "pnpm dependencies installed." "$TOOL_NAME"
    write_result "OK"
else
    log_error "pnpm install ended with an error." "$TOOL_NAME"
    write_result "Failed"
fi
