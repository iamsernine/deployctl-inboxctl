#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# inboxctl/tests/test_parse_conf.sh — Parse example project metadata from examples.
#
# Further reading (exam / study index):
#   Sourcing libraries in tests: https://www.shellcheck.net/wiki/SC1091
#   Strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/

# =============================================================================
# Strict mode
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export INBOX_SHARED_ROOT="${ROOT}/shared"

# =============================================================================
# Minimal source stack: constants + format + parser module only
# Study: https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html#index-source
# =============================================================================
# shellcheck source=/dev/null
source "${ROOT}/shared/constants.sh"
# shellcheck source=/dev/null
source "${ROOT}/shared/format.sh"
# shellcheck source=/dev/null
source "${ROOT}/inboxctl/lib/mod_parse.sh"

# =============================================================================
# Assertions on PARSE_* globals set by inboxctl_parse_project_conf_file
# Study: https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html
# =============================================================================
EX="${ROOT}/deployctl/examples/demo-app.conf"
inboxctl_parse_project_conf_file "$EX"

[[ "${PARSE_APP_NAME}" == "demo-app" ]] || exit 1
[[ "${PARSE_STATUS}" == "live" ]] || exit 1

printf 'test_parse_conf: OK\n'
