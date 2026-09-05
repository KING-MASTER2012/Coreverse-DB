#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/../common/tool-check-helper.sh"

# NOTE: Deno Lint / Deno Fmt / Deno Check / Deno Inspector all ship inside
# this same binary (see check-deno-lint.sh etc., task graph: DependsOn =
# Deno). This script is the single place that actually installs/updates
# Deno; the four sub-checks only verify a capability of whatever Deno ends
# up on PATH after this task completes.

TOOL_NAME="Deno"
REQUIRED_VERSION=$(read_config_min_version deno)
[ -z "$REQUIRED_VERSION" ] && REQUIRED_VERSION="2.5.5"
PKG_NAME=$(read_config_pkg_name deno)
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

get_version_raw() {
    export PATH="$PATH:$HOME/.deno/bin"
    command -v deno >/dev/null 2>&1 && deno --version 2>/dev/null | head -n1
}

upstream_install() {
    # Official installer - installs to $HOME/.deno/bin, no root required.
    curl -fsSL https://deno.land/install.sh | sh -s -- >/dev/null 2>&1

    local deno_bin="$HOME/.deno/bin"
    if [ -d "$deno_bin" ]; then
        export PATH="$PATH:$deno_bin"
        add_to_shell_profile "$deno_bin"
    fi

    command -v deno >/dev/null 2>&1
}

# add_to_shell_profile <dir>
# Best-effort: appends a PATH export to the user's shell profile so the tool
# is still available in new terminal sessions after bootstrap finishes.
add_to_shell_profile() {
    local dir="$1"
    local profile="$HOME/.profile"
    [ -n "${ZSH_VERSION:-}" ] && profile="$HOME/.zshrc"
    [ -n "${BASH_VERSION:-}" ] && [ -f "$HOME/.bashrc" ] && profile="$HOME/.bashrc"

    if [ -f "$profile" ] && grep -qF "$dir" "$profile" 2>/dev/null; then
        return 0
    fi
    printf '\nexport PATH="$PATH:%s"\n' "$dir" >> "$profile" 2>/dev/null || true
}

invoke_tool_check "$TOOL_NAME" "$REQUIRED_VERSION" "$PKG_NAME" get_version_raw upstream_install "$DRY_RUN" "$RESULT_FILE"
