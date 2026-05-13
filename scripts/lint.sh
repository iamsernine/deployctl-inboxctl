#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# scripts/lint.sh — Syntax-check all Bash sources; run shellcheck when installed.
#
# Further reading (exam / study index):
#   bash -n: https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html (syntax check)
#   ShellCheck: https://www.shellcheck.net/
#   Process substitution: https://www.gnu.org/software/bash/manual/html_node/Process-Substitution.html

# =============================================================================
# Strict mode
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

# =============================================================================
# Repo root from this script’s directory
# Study: https://mywiki.wooledge.org/BashFAQ/028
# =============================================================================
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------------------------------------------------------
# lint_all_sh
# Finds *.sh under the repo and runs bash -n.
# Returns: 0 when all pass
# Study: find -print0 + read -d '' — https://mywiki.wooledge.org/BashFAQ/020
# -----------------------------------------------------------------------------
lint_all_sh() {
    local f failed=0
    while IFS= read -r -d '' f; do
        bash -n "$f" || failed=1
    done < <(find "$ROOT" -name '*.sh' -print0 2>/dev/null)

    if command -v shellcheck >/dev/null 2>&1; then
        while IFS= read -r -d '' f; do
            shellcheck -x "$f" || failed=1
        done < <(find "$ROOT" -name '*.sh' -print0 2>/dev/null)
    else
        printf 'lint: shellcheck not installed; skipped (optional)\n'
    fi

    return "$failed"
}

lint_all_sh
