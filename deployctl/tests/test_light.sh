#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/tests/test_light.sh — Minimal smoke: dry-run check avoids mutating the system.
#
# Further reading (exam / study index):
#   Strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Export + subprocess: https://www.gnu.org/software/bash/manual/html_node/Environment.html

# =============================================================================
# Strict mode in the test driver
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

# =============================================================================
# Point deployctl at repo shared/ and isolated log dir ($$ = PID)
# Study: https://www.gnu.org/software/bash/manual/html_node/Special-Parameters.html
# =============================================================================
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export DEPLOY_SHARED_ROOT="${ROOT}/shared"
export DEPLOYCTL_LOG_DIR_OVERRIDE="${TMPDIR:-/tmp}/deployctl-test-logs-$$"

# =============================================================================
# Invoke CLI in clean bash subprocess (integration-style smoke)
# Study: bash(1) invoking a script path; deployctl -n dry-run
# =============================================================================
bash "${ROOT}/deployctl/deployctl.sh" -n -l "${DEPLOYCTL_LOG_DIR_OVERRIDE}" check

printf 'test_light: OK\n'
