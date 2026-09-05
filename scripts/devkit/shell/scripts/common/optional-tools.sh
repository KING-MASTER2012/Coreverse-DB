#!/usr/bin/env bash
# Coreverse-DB Bootstrap - resolves yes/no install decisions for optional
# tools (Semgrep, SQLFluff, deno audit) up front, before any parallel
# installation work starts. Mirrors
# setup/powershell/scripts/common/optional-tools.ps1.
#
# Precedence, per tool id:
#   1) --reject <id> or --reject none  -> not installed, never asked.
#   2) --accept <id> or --accept all   -> installed, never asked.
#   3) neither given                   -> interactive Y/n prompt (defaults
#                                          to "No" in --yes / non-interactive
#                                          runs).
# If an id appears in both --accept and --reject (and neither 'all' nor
# 'none' was used), --reject wins and a warning is logged.
#
# This intentionally does NOT pre-check whether the tool is already
# installed before asking: invoke_tool_check (tool-check-helper.sh) is
# already idempotent, so answering "y" for an already-installed tool is
# harmless.
#
# Sourced by bootstrap.sh; not intended to be run directly.

SCRIPT_DIR_OPTIONAL_TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR_OPTIONAL_TOOLS/logger.sh"

# resolve_optional_tool_decisions <accept_csv> <reject_csv> <yes>
# accept_csv/reject_csv are comma-separated id lists (e.g. "semgrep,sqlfluff"),
# or the literal "all"/"none" respectively. Fills the global associative
# array OPTIONAL_DECISIONS[id]=true|false for every catalog entry below.
declare -A OPTIONAL_DECISIONS

resolve_optional_tool_decisions() {
    local accept_csv="$1" reject_csv="$2" yes="$3"

    local ids=(semgrep sqlfluff deno-audit)
    local names=(
        "Semgrep (static analyzer)"
        "SQLFluff (SQL lint + static analysis)"
        "deno audit (dependency vulnerability audit)"
    )

    local accept_all="false" reject_all="false"
    [ "$accept_csv" = "all" ] && accept_all="true"
    [ "$reject_csv" = "none" ] && reject_all="true"

    local i id name in_accept in_reject answer
    for i in "${!ids[@]}"; do
        id="${ids[$i]}"
        name="${names[$i]}"

        in_accept="false"
        in_reject="false"
        [ "$accept_all" = "true" ] && in_accept="true"
        [ "$reject_all" = "true" ] && in_reject="true"

        case ",$accept_csv," in *",$id,"*) in_accept="true" ;; esac
        case ",$reject_csv," in *",$id,"*) in_reject="true" ;; esac

        if [ "$in_reject" = "true" ] && [ "$in_accept" = "true" ] && [ "$accept_all" = "false" ] && [ "$reject_all" = "false" ]; then
            log_warning "'$id' is listed in both --accept and --reject; --reject takes precedence." "OptionalTools"
        fi

        if [ "$in_reject" = "true" ]; then
            OPTIONAL_DECISIONS["$id"]="false"
            log_info "${name}: skipped (--reject)." "OptionalTools"
            continue
        fi

        if [ "$in_accept" = "true" ]; then
            OPTIONAL_DECISIONS["$id"]="true"
            log_info "${name}: approved (--accept)." "OptionalTools"
            continue
        fi

        if [ "$yes" = "true" ]; then
            OPTIONAL_DECISIONS["$id"]="false"
            log_warning "${name}: --yes given without --accept/--reject for this tool; defaulting to skipped." "OptionalTools"
            continue
        fi

        if [ ! -t 0 ]; then
            OPTIONAL_DECISIONS["$id"]="false"
            log_warning "${name}: non-interactive session and no --accept/--reject given; defaulting to skipped." "OptionalTools"
            continue
        fi

        read -r -p "Install ${name}? [y/N] " answer
        case "$answer" in
            y|Y|yes|YES) OPTIONAL_DECISIONS["$id"]="true" ;;
            *) OPTIONAL_DECISIONS["$id"]="false" ;;
        esac
    done
}
