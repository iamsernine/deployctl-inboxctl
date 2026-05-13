#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# scripts/format.sh — Ensure scripts are executable and use sane permissions.
#
# Further reading (exam / study index):
#   chmod(1): https://pubs.opengroup.org/onlinepubs/9699919799/utilities/chmod.html
#   find -exec: POSIX find — https://pubs.opengroup.org/onlinepubs/9699919799/utilities/find.html

# =============================================================================
# Strict mode
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------------------------------------------------------
# chmod_scripts
# Applies +x to CLI entrypoints and test/lint runners.
# Returns: 0
# Study: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/chmod.html
# -----------------------------------------------------------------------------
chmod_scripts() {
    local targets=(
        "${ROOT}/deployctl/deployctl.sh"
        "${ROOT}/deployctl/install.sh"
        "${ROOT}/deployctl/uninstall.sh"
        "${ROOT}/inboxctl/inboxctl.sh"
        "${ROOT}/inboxctl/install.sh"
        "${ROOT}/inboxctl/uninstall.sh"
        "${ROOT}/scripts/verify-format.sh"
        "${ROOT}/scripts/check-docs.sh"
    )
    local t
    for t in "${targets[@]}"; do
        [[ -f "$t" ]] && chmod 755 "$t"
    done

    find "${ROOT}/scripts" "${ROOT}/deployctl/tests" "${ROOT}/inboxctl/tests" -name '*.sh' -exec chmod 755 {} + 2>/dev/null || true
    return 0
}

chmod_scripts
printf 'format: OK\n'
