#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# scripts/verify-format.sh — Fail CI if CLI/tests/scripts are not executable (format contract).
#
# Further reading (exam / study index):
#   Bash tests: https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html (-x)
#   Strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/

# =============================================================================
# Strict mode
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------------------------------------------------------
# assert_executable
# Args: paths relative to ROOT
# Returns: 1 if any file is missing or not executable
# Study: https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html
# -----------------------------------------------------------------------------
assert_executable() {
    local path
    local failed=0
    for path in "$@"; do
        local full="${ROOT}/${path}"
        if [[ ! -f "$full" ]]; then
            printf 'verify-format: missing file %s\n' "$path" >&2
            failed=1
            continue
        fi
        if [[ ! -x "$full" ]]; then
            printf 'verify-format: not executable (run: bash scripts/format.sh): %s\n' "$path" >&2
            failed=1
        fi
    done
    return "$failed"
}

# -----------------------------------------------------------------------------
# main
# Study: multi-line command continuation with backslash — https://www.gnu.org/software/bash/manual/html_node/Escape-Character.html
# -----------------------------------------------------------------------------
main() {
    assert_executable \
        deployctl/deployctl.sh \
        deployctl/install.sh \
        deployctl/uninstall.sh \
        inboxctl/inboxctl.sh \
        inboxctl/install.sh \
        inboxctl/uninstall.sh \
        scripts/lint.sh \
        scripts/format.sh \
        scripts/demo.sh \
        scripts/verify-format.sh \
        scripts/check-docs.sh \
        deployctl/tests/test_light.sh \
        deployctl/tests/test_medium.sh \
        deployctl/tests/test_heavy.sh \
        inboxctl/tests/test_parse_conf.sh \
        inboxctl/tests/test_parse_logs.sh

    printf 'verify-format: OK\n'
    return 0
}

main "$@"
