#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_error.sh — Centralized fatal exits and deployment rollback hooks.

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

# Rollback context (set during deploy)
DEPLOYCTL_ROLLBACK_APP=""
DEPLOYCTL_ROLLBACK_CONTAINER=""
DEPLOYCTL_ROLLBACK_NGINX_CONF=""
DEPLOYCTL_ROLLBACK_PENDING_DIR=""

# -----------------------------------------------------------------------------
# exit_with_error
# Logs, prints help hint, and exits with numeric code.
# Args: $1=ERR_* constant value, $2=message
# Returns: does not return
# Study: https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html#index-exit
# -----------------------------------------------------------------------------
exit_with_error() {
    local code="${1:-100}"
    local msg="${2:-unknown error}"
    log_error "$msg"
    printf 'deployctl: error [%s]: %s\n' "$code" "$msg" >&2
    printf 'Run: deployctl --help\n' >&2
    exit "$code"
}

# -----------------------------------------------------------------------------
# show_error_help
# Prints mapping of error codes to names for operators.
# Returns: 0
# Study: https://www.gnu.org/software/bash/manual/html_node/Redirections.html (here-documents)
# -----------------------------------------------------------------------------
show_error_help() {
    cat <<'EOF'
Error codes:
  100 UNKNOWN_OPTION      110 NGINX_CONFIG_FAILED
  101 MISSING_PARAM       111 SSL_FAILED
  102 INVALID_APP_NAME    112 NOT_ROOT
  103 INVALID_DOMAIN      113 SSH_FAILED (reserved)
  104 PORT_IN_USE         114 CONFIG_PARSE_ERROR
  105 DOCKERFILE_MISSING  115 UNKNOWN_STATUS
  106 ENV_EXAMPLE_MISSING 116 DEPENDENCY_MISSING
  107 DOCKER_BUILD_FAILED 117 GIT_CLONE_FAILED
  108 CONTAINER_RUN_FAILED 118 FILE_PERMISSION_ERROR
  109 HEALTH_CHECK_FAILED 119 ARCHIVE_FAILED
                         120 RESTORE_FAILED
EOF
    return 0
}

# -----------------------------------------------------------------------------
# cleanup_on_error
# Best-effort rollback after partial deploy: container, pending dir, nginx snippet.
# Uses global rollback pointers set before risky steps.
# Returns: 0 (always attempts cleanup)
# Study: https://mywiki.wooledge.org/BashGuide/Practices#errexit (rollback, || true)
# -----------------------------------------------------------------------------
cleanup_on_error() {
    local app="${DEPLOYCTL_ROLLBACK_APP:-}"
    log_error "cleanup_on_error: rolling back partial deployment for '${app:-unknown}'"

    if [[ -n "${DEPLOYCTL_ROLLBACK_CONTAINER:-}" ]]; then
        docker rm -f "${DEPLOYCTL_ROLLBACK_CONTAINER}" 2>/dev/null || true
        log_error "removed container ${DEPLOYCTL_ROLLBACK_CONTAINER}"
    fi

    if [[ -n "${DEPLOYCTL_ROLLBACK_PENDING_DIR:-}" ]] && [[ -d "${DEPLOYCTL_ROLLBACK_PENDING_DIR}" ]]; then
        rm -rf "${DEPLOYCTL_ROLLBACK_PENDING_DIR}"
        log_error "removed pending directory ${DEPLOYCTL_ROLLBACK_PENDING_DIR}"
    fi

    if [[ -n "${DEPLOYCTL_ROLLBACK_NGINX_CONF:-}" ]] && [[ -f "${DEPLOYCTL_ROLLBACK_NGINX_CONF}" ]]; then
        rm -f "${DEPLOYCTL_ROLLBACK_NGINX_CONF}"
        log_error "removed nginx config ${DEPLOYCTL_ROLLBACK_NGINX_CONF}"
        nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || true
    fi

    if [[ -n "$app" ]] && [[ -f "${DEPLOYCTL_PROJECTS_DIR}/${app}.conf" ]]; then
        write_key_value "${DEPLOYCTL_PROJECTS_DIR}/${app}.conf" "STATUS" "$STATUS_ERROR" || true
        log_error "set STATUS=error for ${app}"
    fi

    DEPLOYCTL_ROLLBACK_APP=""
    DEPLOYCTL_ROLLBACK_CONTAINER=""
    DEPLOYCTL_ROLLBACK_NGINX_CONF=""
    DEPLOYCTL_ROLLBACK_PENDING_DIR=""
    return 0
}