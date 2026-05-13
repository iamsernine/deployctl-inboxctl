#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/tests/test_medium.sh — Dry-run deploy with explicit flags (non-interactive).
#
# Further reading (exam / study index):
#   Strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Long options / argv: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameters.html

# =============================================================================
# Strict mode
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

# =============================================================================
# Test environment: shared root + log override
# Study: https://www.gnu.org/software/bash/manual/html_node/Environment.html (export)
# =============================================================================
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export DEPLOY_SHARED_ROOT="${ROOT}/shared"
export DEPLOYCTL_LOG_DIR_OVERRIDE="${TMPDIR:-/tmp}/deployctl-test-logs-$$"

# =============================================================================
# Dry-run deploy with all parameters on CLI (no prompts)
# Study: deployctl_parse_deploy_argv / flags in deployctl.sh
# =============================================================================
bash "${ROOT}/deployctl/deployctl.sh" -n -l "${DEPLOYCTL_LOG_DIR_OVERRIDE}" deploy demo-app \
    --repo "https://example.com/demo.git" \
    --domain "demo.example.com" \
    --port "8080" \
    --ssl "no"

printf 'test_medium: OK\n'
