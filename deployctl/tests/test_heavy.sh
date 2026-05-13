#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/tests/test_heavy.sh — Exercise fork/thread/subshell flags with dry-run deploy.
#
# Further reading (exam / study index):
#   Subshell vs background: https://www.gnu.org/software/bash/manual/html_node/Lists.html
#   Strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/

# =============================================================================
# Strict mode
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export DEPLOY_SHARED_ROOT="${ROOT}/shared"
export DEPLOYCTL_LOG_DIR_OVERRIDE="${TMPDIR:-/tmp}/deployctl-test-logs-$$"

# =============================================================================
# -f / -t / -s exercise deployctl_dispatch branches (still dry-run)
# Study: deployctl.sh deployctl_dispatch (fork / thread / subshell hints)
# =============================================================================
bash "${ROOT}/deployctl/deployctl.sh" -n -f -l "${DEPLOYCTL_LOG_DIR_OVERRIDE}" deploy app-one \
    --repo "https://example.com/a.git" --domain "a.example.com" --port "3001" --ssl no

bash "${ROOT}/deployctl/deployctl.sh" -n -t -l "${DEPLOYCTL_LOG_DIR_OVERRIDE}" deploy app-two \
    --repo "https://example.com/b.git" --domain "b.example.com" --port "3002" --ssl no

bash "${ROOT}/deployctl/deployctl.sh" -n -s -l "${DEPLOYCTL_LOG_DIR_OVERRIDE}" deploy app-three \
    --repo "https://example.com/c.git" --domain "c.example.com" --port "3003" --ssl no

printf 'test_heavy: OK\n'
