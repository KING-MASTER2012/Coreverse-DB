#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/../common/deno-subtool-check.sh"

# NOTE: this task depends on 'Deno' in the task graph (DependsOn = Deno).
# Not a separate install - see deno-subtool-check.sh.

DRY_RUN="false"
RESULT_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN="true"; shift ;;
        --result-file) RESULT_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

export PATH="$PATH:$HOME/.deno/bin"

invoke_deno_subcommand_check "Deno Fmt" "$RESULT_FILE" "$DRY_RUN" fmt --help
