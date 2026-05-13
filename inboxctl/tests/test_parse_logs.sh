#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# inboxctl/tests/test_parse_logs.sh — Validate deployctl log line shape against sample.
#
# Further reading (exam / study index):
#   Command substitution: https://www.gnu.org/software/bash/manual/html_node/Command-Substitution.html
#   Strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/

# =============================================================================
# Strict mode
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export INBOX_SHARED_ROOT="${ROOT}/shared"

# shellcheck source=/dev/null
source "${ROOT}/shared/format.sh"

# =============================================================================
# format_log_entry contract: substrings must appear in output
# Study: shared/format.sh format_log_entry + [[ == *wildcards* ]]
# =============================================================================
line="$(format_log_entry "INFOS" "hello world")"
[[ "$line" == *"INFOS"* ]] || exit 1
[[ "$line" == *"hello world"* ]] || exit 1
[[ "$line" == *" : "* ]] || exit 1

printf 'test_parse_logs: OK\n'
