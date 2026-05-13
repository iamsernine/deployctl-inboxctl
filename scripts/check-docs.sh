#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# scripts/check-docs.sh — Ensure required documentation files exist and are non-empty.
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash arrays: https://www.gnu.org/software/bash/manual/html_node/Arrays.html

# =============================================================================
# Strict mode
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

# =============================================================================
# Repo root from script location
# Study: https://mywiki.wooledge.org/BashFAQ/028
# =============================================================================
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------------------------------------------------------
# require_doc
# Args: $1=relative path from ROOT
# Returns: 1 if missing or empty
# Study: https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html (-s file nonempty)
# -----------------------------------------------------------------------------
require_doc() {
    local rel="$1"
    local full="${ROOT}/${rel}"
    if [[ ! -f "$full" ]]; then
        printf 'check-docs: missing %s\n' "$rel" >&2
        return 1
    fi
    if [[ ! -s "$full" ]]; then
        printf 'check-docs: empty file %s\n' "$rel" >&2
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# main
# Study: iterating arrays — https://mywiki.wooledge.org/BashGuide/Arrays
# -----------------------------------------------------------------------------
main() {
    local failed=0
    local docs=(
        README.md
        CONTRIBUTING.md
        LICENSE
        AUTHORS.md
        SECURITY.md
        CODE_OF_CONDUCT.md
        docs/README.md
        docs/cahier-de-charge.md
        docs/benchmark.md
        docs/architecture.md
        docs/project-information.md
        docs/troubleshooting.md
    )
    local d
    for d in "${docs[@]}"; do
        require_doc "$d" || failed=1
    done

    if [[ $failed -ne 0 ]]; then
        return 1
    fi
    printf 'check-docs: OK\n'
    return 0
}

main "$@"
