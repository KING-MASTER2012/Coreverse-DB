#!/usr/bin/env bash
# Coreverse-DB Bootstrap - shared check logic for Deno's built-in sub-tools
# (lint / fmt / check / inspector).
#
# Deno lint, fmt, check (type-checker) and the V8 Inspector are NOT separate
# binaries or packages - they ship inside the single `deno` executable.
# There is nothing to "install" independently of Deno itself (see
# check-deno.sh), but each one is still verified separately so the summary
# table reports each capability on its own row, and so a partially-broken
# Deno build (e.g. a stripped-down distro package missing a subcommand) is
# caught per-feature instead of masked behind a single generic "Deno: OK"
# line.
#
# This is intentionally NOT routed through invoke_tool_check
# (tool-check-helper.sh): there is no install/upgrade path for an
# individual subcommand, only for Deno as a whole. If a subcommand is
# missing/broken, the fix is always "reinstall/upgrade Deno", which
# check-deno.sh already owns (task graph: DependsOn = Deno).
#
# Sourced by check-deno-lint.sh / check-deno-fmt.sh / check-deno-check.sh /
# check-deno-inspector.sh; not intended to be run directly.

SCRIPT_DIR_DENO_SUBTOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR_DENO_SUBTOOL/logger.sh"

# invoke_deno_subcommand_check <tool_name> <result_file> <dry_run> <probe_args...>
#   probe_args: arguments that prove the subcommand is available without
#   requiring a real project on disk (e.g. 'lint --help').
invoke_deno_subcommand_check() {
    local tool_name="$1" result_file="$2" dry_run="$3"
    shift 3
    local probe_args=("$@")

    write_deno_subtool_result() {
        local status="$1" version="$2"
        [ -z "$result_file" ] && return 0
        mkdir -p "$(dirname "$result_file")"
        printf 'TOOL=%s\nSTATUS=%s\nVERSION=%s\n' "$tool_name" "$status" "$version" > "$result_file"
    }

    if ! command -v deno >/dev/null 2>&1; then
        log_error "Deno is not on PATH. The Deno task must succeed first." "$tool_name"
        write_deno_subtool_result "Failed" ""
        return 0
    fi

    if [ "$dry_run" = "true" ]; then
        log_info "[DryRun] Would verify: deno ${probe_args[*]}" "$tool_name"
        write_deno_subtool_result "DryRun" ""
        return 0
    fi

    local deno_version
    deno_version=$(deno --version 2>&1 | head -n1)

    if deno "${probe_args[@]}" >/dev/null 2>&1; then
        log_success "Available." "$tool_name"
        write_deno_subtool_result "OK" "$deno_version"
    else
        log_error "Subcommand check failed." "$tool_name"
        write_deno_subtool_result "Failed" "$deno_version"
    fi
}
