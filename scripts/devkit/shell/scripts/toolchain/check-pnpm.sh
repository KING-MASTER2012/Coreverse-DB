#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/../common/tool-check-helper.sh"

# NOTE: this task depends on 'Node.js' in the task graph (DependsOn =
# 'Node.js'). pnpm is installed/pinned via corepack, matching pnpm's current
# official recommendation, rather than a package manager or standalone
# installer.
#
# IMPORTANT: Node.js 25 stopped bundling corepack (it now has to be
# installed separately via `npm install -g corepack`). Node 22/24 LTS still
# ship it. This script does not assume either way - if `corepack` isn't
# found after Node.js is confirmed present, it installs it via npm first,
# then proceeds.

TOOL_NAME="pnpm"
REQUIRED_VERSION=$(read_config_min_version pnpm)
[ -z "$REQUIRED_VERSION" ] && REQUIRED_VERSION="9.0.0"
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
    command -v pnpm >/dev/null 2>&1 && pnpm --version 2>/dev/null | head -n1
}

upstream_install() {
    if ! command -v node >/dev/null 2>&1; then
        log_error "Node.js not found." "$TOOL_NAME"
        return 1
    fi

    if ! command -v corepack >/dev/null 2>&1; then
        log_warning "corepack not found (Node.js 25+ no longer bundles it); installing via npm..." "$TOOL_NAME"
        npm install -g corepack || {
            log_error "npm install -g corepack failed." "$TOOL_NAME"
            return 1
        }
    fi

    corepack enable || { log_error "corepack enable failed." "$TOOL_NAME"; return 1; }
    corepack prepare pnpm@latest --activate || { log_error "corepack prepare pnpm@latest failed." "$TOOL_NAME"; return 1; }

    command -v pnpm >/dev/null 2>&1
}

invoke_tool_check "$TOOL_NAME" "$REQUIRED_VERSION" "" get_version_raw upstream_install "$DRY_RUN" "$RESULT_FILE"
