#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/../common/tool-check-helper.sh"

# NOTE: added for the src/ React package (pnpm scripts - tsc, vite, orval
# codegen, etc. - all need a real Node.js runtime on PATH). pnpm depends on
# this task (task graph: DependsOn = 'Node.js').

TOOL_NAME="Node.js"
REQUIRED_VERSION=$(read_config_min_version node)
[ -z "$REQUIRED_VERSION" ] && REQUIRED_VERSION="22.0.0"
PKG_NAME=$(read_config_pkg_name node)
[ -z "$PKG_NAME" ] && PKG_NAME="nodejs"
[ "$PKG_MANAGER" = "brew" ] && PKG_NAME="node"
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
    command -v node >/dev/null 2>&1 && node --version 2>/dev/null | head -n1
}

upstream_install() {
    # macOS: nvm's official installer is the most reliable cross-distro-free
    # upstream path; on Linux, NodeSource's setup script is the closest thing
    # to an "official installer" for a specific major version and is
    # distro-package-manager-driven (fits pkg_install/pkg_update_index
    # already being tried first, so this is really a last resort refresh of
    # the same apt/dnf/zypper/pacman path with a newer upstream repo added).
    case "$OS_PLATFORM" in
        linux)
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL https://deb.nodesource.com/setup_22.x -o /tmp/nodesource_setup.sh 2>/dev/null
                if [ -s /tmp/nodesource_setup.sh ]; then
                    with_pkg_lock "$(sudo_cmd)bash /tmp/nodesource_setup.sh" >/dev/null 2>&1 || true
                fi
            fi
            pkg_update_index
            pkg_install nodejs
            ;;
        macos)
            ensure_homebrew_installed && brew_install node
            ;;
        *)
            return 1 ;;
    esac

    command -v node >/dev/null 2>&1
}

invoke_tool_check "$TOOL_NAME" "$REQUIRED_VERSION" "$PKG_NAME" get_version_raw upstream_install "$DRY_RUN" "$RESULT_FILE"
