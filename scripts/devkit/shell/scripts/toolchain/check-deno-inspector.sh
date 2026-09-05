#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/../common/logger.sh"

# NOTE: this task depends on 'Deno' in the task graph (DependsOn = Deno).
# Not a separate install - the V8 Inspector is a flag on `deno run`/`deno
# test` (--inspect / --inspect-brk / --inspect-wait), not a standalone
# binary. Unlike lint/fmt/check, there is no dedicated `deno inspect
# --help` subcommand to probe, and actually opening an inspector socket
# just to verify it works would leave a listener behind / needs a real
# script to attach to. Instead this checks that the installed Deno build
# advertises the --inspect flag on `deno run --help`, which is the
# cheapest reliable signal that the Inspector is compiled in.

TOOL_NAME="Deno Inspector"
DRY_RUN="false"
RESULT_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN="true"; shift ;;
        --result-file) RESULT_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

write_result() {
    local status="$1" version="$2"
    [ -z "$RESULT_FILE" ] && return 0
    mkdir -p "$(dirname "$RESULT_FILE")"
    printf 'TOOL=%s\nSTATUS=%s\nVERSION=%s\n' "$TOOL_NAME" "$status" "$version" > "$RESULT_FILE"
}

export PATH="$PATH:$HOME/.deno/bin"

if ! command -v deno >/dev/null 2>&1; then
    log_error "Deno is not on PATH. The Deno task must succeed first." "$TOOL_NAME"
    write_result "Failed" ""
    exit 0
fi

if [ "$DRY_RUN" = "true" ]; then
    log_info "[DryRun] Would verify: deno run --help advertises --inspect." "$TOOL_NAME"
    write_result "DryRun" ""
    exit 0
fi

DENO_VERSION=$(deno --version 2>&1 | head -n1)

if deno run --help 2>&1 | grep -q -- '--inspect'; then
    log_success "Available (--inspect flag present)." "$TOOL_NAME"
    write_result "OK" "$DENO_VERSION"
else
    log_error "This Deno build does not advertise --inspect." "$TOOL_NAME"
    write_result "Failed" "$DENO_VERSION"
fi
