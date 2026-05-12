#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_health.sh — HTTP /health probe then TCP listen fallback.

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

# -----------------------------------------------------------------------------
# deployctl_health_check_app
# Tries curl http://127.0.0.1:PORT/health; falls back to ss listening check.
# Args: $1=app name (for logs), $2=port
# Returns: 0 if healthy
# Study: curl(1) — https://curl.se/docs/manpage.html
# -----------------------------------------------------------------------------
deployctl_health_check_app() {
    local app="$1"
    local port="$2"

    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_project_info "$app" "[dry-run] health check skipped"
        return 0
    fi

    if curl -sf --max-time 5 "http://127.0.0.1:${port}/health" >/dev/null 2>&1; then
        log_project_info "$app" "health: HTTP /health OK on port ${port}"
        return 0
    fi

    if ss -ltn 2>/dev/null | grep -q ":${port} "; then
        log_project_info "$app" "health: port ${port} listening (HTTP /health not OK)"
        return 0
    fi
  
    log_project_error "$app" "health check failed for port ${port}"
    return 1
}