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
# tool-check-helper.sh already calls detect_os and sources
# os-detect.sh/pkg-lock.sh/all package-managers/*.sh; used here only for
# OS_PLATFORM, brew_install and read_config_min_version - not
# invoke_tool_check, since the macOS-brew-then-pip fallback chain needs
# custom handling.

# Optional tool - only added to the task graph when approved via --accept /
# an interactive Y/n answer (see bootstrap.sh's optional-tool phase).
#
# Homebrew has a semgrep formula on macOS; everywhere else this is a Python
# (pip) package - no apt/dnf/zypper/pacman package. If no Python 3
# interpreter is found, this is logged as a Warning and Skipped rather than
# Failed, matching the project's "warn and continue" policy for secondary
# tools.

TOOL_NAME="Semgrep"
REQUIRED_VERSION=$(read_config_min_version semgrep)
[ -z "$REQUIRED_VERSION" ] && REQUIRED_VERSION="1.0.0"
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
    command -v semgrep >/dev/null 2>&1 && semgrep --version 2>/dev/null | head -n1
}

RAW=$(get_version_raw)

if [ -n "$RAW" ] && version_ge "$RAW" "$REQUIRED_VERSION"; then
    log_success "The version is sufficient (>= $REQUIRED_VERSION)." "$TOOL_NAME"
    write_own_result "OK" "$RAW"
    exit 0
fi

if [ "$OS_PLATFORM" = "macos" ]; then
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DryRun] Would install via Homebrew (brew install semgrep)." "$TOOL_NAME"
        write_own_result "DryRun" ""
        exit 0
    fi
    ensure_homebrew_installed && brew_install semgrep >/dev/null 2>&1
    RAW=$(get_version_raw)
    if [ -n "$RAW" ] && version_ge "$RAW" "$REQUIRED_VERSION"; then
        log_success "Installed via Homebrew: $RAW" "$TOOL_NAME"
        write_own_result "Installed" "$RAW"
        exit 0
    fi
fi

if [ "$DRY_RUN" = "true" ]; then
    log_info "[DryRun] Installation was to be performed (pip install semgrep)." "$TOOL_NAME"
    write_own_result "DryRun" ""
    exit 0
fi

PYTHON_BIN=$(find_python_executable)
if [ -z "$PYTHON_BIN" ]; then
    log_warning "No Python 3 interpreter found; semgrep is a pip package and cannot be installed. Skipping." "$TOOL_NAME"
    write_own_result "Skipped" ""
    exit 0
fi

if ! install_python_pip_package "$PYTHON_BIN" "semgrep" "$TOOL_NAME"; then
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
    log_error "semgrep was not found on PATH after pip install." "$TOOL_NAME"
    write_own_result "Failed" ""
fi
