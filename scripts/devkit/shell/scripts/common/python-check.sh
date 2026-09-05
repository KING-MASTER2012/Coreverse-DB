#!/usr/bin/env bash
# Coreverse-DB Bootstrap - reusable Python interpreter / pip-install helpers.
#
# Mirrors setup/powershell/scripts/common/python-check.ps1. Deliberately
# generic - not Semgrep/SQLFluff-specific - so any future check-*.sh that
# needs a Python 3 interpreter can source this instead of writing its own
# ad-hoc version of the same check.
#
# Sourced by check-*.sh scripts that need it; not intended to be run
# directly.

# find_python_executable
# Prints the first working 'python3' or 'python' on PATH that reports as
# Python 3, or nothing if none found.
find_python_executable() {
    local candidate
    for candidate in python3 python; do
        command -v "$candidate" >/dev/null 2>&1 || continue
        if "$candidate" --version 2>&1 | grep -q 'Python 3'; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

# install_python_pip_package <python_bin> <package_name> [source_tag]
# Best-effort `pip install --user`; logs and returns non-zero rather than
# aborting the caller, matching this project's "warn and continue" policy
# for secondary/optional dependencies.
install_python_pip_package() {
    local python_bin="$1" package_name="$2" source_tag="${3:-}"

    log_info "Installing python package '$package_name' (pip install --user)..." "$source_tag"

    if "$python_bin" -m pip install --user --quiet "$package_name" >/dev/null 2>&1; then
        log_success "Installed python package '$package_name'." "$source_tag"
        return 0
    fi

    log_warning "Could not install python package '$package_name' (pip install failed). Continuing." "$source_tag"
    return 1
}
