#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/../common/logger.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../common/version-compare.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../common/python-check.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../common/tool-check-helper.sh"
# tool-check-helper.sh is used here only for read_config_min_version, not
# invoke_tool_check (sqlfluff is pip-only, no package-manager step).

# Optional tool - only added to the task graph when approved via --accept /
# an interactive Y/n answer (see bootstrap.sh's optional-tool phase).
#
# Covers BOTH "SQL lint/style" and "SQL static analysis" from the original
# tool list: SQLFluff is a single package that provides its lint engine and
# rule set together, so a single question/install covers both.
#
# No apt/dnf/zypper/pacman/brew package - installed via pip only.

TOOL_NAME="SQLFluff"
REQUIRED_VERSION=$(read_config_min_version sqlfluff)
[ -z "$REQUIRED_VERSION" ] && REQUIRED_VERSION="3.0.0"
DRY_RUN="false"
RESULT_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --required-version) REQUIRED_VERSION="$2"; shift 2 ;;
        --dry-run) DRY_RUN="true"; shift ;;
        --result-file) RESULT_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

write_own_result() {
    local status="$1" version="$2"
    [ -z "$RESULT_FILE" ] && return 0
    mkdir -p "$(dirname "$RESULT_FILE")"
    printf 'TOOL=%s\nSTATUS=%s\nVERSION=%s\n' "$TOOL_NAME" "$status" "$version" > "$RESULT_FILE"
}

get_version_raw() {
    command -v sqlfluff >/dev/null 2>&1 && sqlfluff --version 2>/dev/null | head -n1
}

RAW=$(get_version_raw)

if [ -n "$RAW" ] && version_ge "$RAW" "$REQUIRED_VERSION"; then
    log_success "The version is sufficient (>= $REQUIRED_VERSION)." "$TOOL_NAME"
    write_own_result "OK" "$RAW"
    exit 0
fi

if [ "$DRY_RUN" = "true" ]; then
    log_info "[DryRun] Installation was to be performed (pip install sqlfluff)." "$TOOL_NAME"
    write_own_result "DryRun" ""
    exit 0
fi

PYTHON_BIN=$(find_python_executable)
if [ -z "$PYTHON_BIN" ]; then
    log_warning "No Python 3 interpreter found; sqlfluff is a pip package and cannot be installed. Skipping." "$TOOL_NAME"
    write_own_result "Skipped" ""
    exit 0
fi

if ! install_python_pip_package "$PYTHON_BIN" "sqlfluff" "$TOOL_NAME"; then
    write_own_result "Failed" ""
    exit 0
fi

RAW=$(get_version_raw)
if [ -n "$RAW" ] && version_ge "$RAW" "$REQUIRED_VERSION"; then
    log_success "Installed: $RAW" "$TOOL_NAME"
    write_own_result "Installed" "$RAW"
elif [ -n "$RAW" ]; then
    log_warning "Installed but version is lower than wanted: $RAW (wanted >= $REQUIRED_VERSION). Continuing." "$TOOL_NAME"
    write_own_result "Warning" "$RAW"
else
    log_error "sqlfluff was not found on PATH after pip install." "$TOOL_NAME"
    write_own_result "Failed" ""
fi
