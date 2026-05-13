#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# scripts/demo.sh — Ordered command list for teaching / classroom demos.
#
# Further reading (exam / study index):
#   Here-documents (quoted EOF): https://www.gnu.org/software/bash/manual/html_node/Redirections.html#Here-Documents
#   Strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/

# =============================================================================
# Strict mode (no-op body except cat; still good habit for growable scripts)
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

# =============================================================================
# Static demo text (<<'EOF' disables expansion inside the here-doc)
# Study: https://www.gnu.org/software/bash/manual/html_node/Redirections.html#Here-Documents
# =============================================================================
cat <<'EOF'
Teacher / demo sequence (run on appropriate hosts):

1. deployctl check
2. deployctl deploy demo-app --repo <URL> --domain <DOMAIN> --port <PORT> --ssl no
3. deployctl archive demo-app
4. deployctl restore demo-app
5. inboxctl add-server prod1 user@host
6. inboxctl fetch prod1
7. inboxctl show projects prod1
8. inboxctl watch prod1
EOF
