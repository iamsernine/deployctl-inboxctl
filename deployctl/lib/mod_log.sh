#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_log.sh — History and per-project logging with fixed format.

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

# Globals set by deployctl main: DEPLOYCTL_VERBOSE, DEPLOYCTL_LOG_DIR_OVERRIDE
# DEPLOYCTL_EFFECTIVE_LOG_BASE — resolved directory for history.log and projects/*.log

# -----------------------------------------------------------------------------
# deployctl_log_ensure_init
# Ensures init_logs ran so DEPLOYCTL_EFFECTIVE_LOG_BASE is set (e.g. log_error before cmd body).
# Returns: 0
# Study: https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html (short-circuit &&)
# -----------------------------------------------------------------------------
deployctl_log_ensure_init() {
    [[ -n "${DEPLOYCTL_EFFECTIVE_LOG_BASE:-}" ]] && return 0
    init_logs
}

# -----------------------------------------------------------------------------
# init_logs
# Picks a writable log root: override, then /var/log/deployctl, then ~/.cache/deployctl/logs.
# Returns: 0 on success
# Study: https://mywiki.wooledge.org/BashGuide/InputAndOutput (fallback writable paths)
# -----------------------------------------------------------------------------
init_logs() {
    local primary="${DEPLOYCTL_LOG_DIR_OVERRIDE:-$DEPLOYCTL_LOG_DIR}"
    local base="$primary"

    if [[ -z "${DEPLOYCTL_LOG_DIR_OVERRIDE:-}" ]]; then
        if ! mkdir -p "$primary" "${primary}/projects" 2>/dev/null || ! : >>"${primary}/history.log" 2>/dev/null; then
            base="${HOME:-${TMPDIR:-/tmp}}/.cache/deployctl/logs"
        fi
    fi

    mkdir -p "$base" "${base}/projects" 2>/dev/null || true
    DEPLOYCTL_EFFECTIVE_LOG_BASE="$base"
    touch "${DEPLOYCTL_EFFECTIVE_LOG_BASE}/history.log" 2>/dev/null || true
    return 0
}

# -----------------------------------------------------------------------------
# log_info
# Appends INFOS line to history log and echoes when verbose.
# Args: $1=message
# Returns: 0
# Study: https://www.gnu.org/software/bash/manual/html_node/Redirections.html (append >>)
# -----------------------------------------------------------------------------
log_info() {
    deployctl_log_ensure_init
    local msg="$1"
    local line
    line="$(format_log_entry "INFOS" "$msg")"
    local hist="${DEPLOYCTL_EFFECTIVE_LOG_BASE}/history.log"
    mkdir -p "$(dirname "$hist")" 2>/dev/null || true
    printf '%s\n' "$line" >>"$hist"
    if [[ "${DEPLOYCTL_VERBOSE:-0}" == "1" ]]; then
        printf '%s\n' "$line" >&2
    fi
    return 0
}

# -----------------------------------------------------------------------------
# log_error
# Appends ERROR line to history log; always visible on stderr.
# Args: $1=message
# Returns: 0
# Study: https://www.gnu.org/software/bash/manual/html_node/Redirections.html (stderr)
# -----------------------------------------------------------------------------
log_error() {
    deployctl_log_ensure_init
    local msg="$1"
    local line
    line="$(format_log_entry "ERROR" "$msg")"
    local hist="${DEPLOYCTL_EFFECTIVE_LOG_BASE}/history.log"
    mkdir -p "$(dirname "$hist")" 2>/dev/null || true
    printf '%s\n' "$line" >>"$hist"
    printf '%s\n' "$line" >&2
    return 0
}

# -----------------------------------------------------------------------------
# log_project_info
# Logs to project-specific log under projects dir.
# Args: $1=app-name, $2=message
# Returns: 0
# Study: same pattern as log_info; per-application log file
# -----------------------------------------------------------------------------
log_project_info() {
    deployctl_log_ensure_init
    local app="$1"
    local msg="$2"
    local line plog
    line="$(format_log_entry "INFOS" "$msg")"
    plog="${DEPLOYCTL_EFFECTIVE_LOG_BASE}/projects/${app}.log"
    mkdir -p "$(dirname "$plog")" 2>/dev/null || true
    printf '%s\n' "$line" >>"$plog"
    if [[ "${DEPLOYCTL_VERBOSE:-0}" == "1" ]]; then
        printf '%s\n' "$line" >&2
    fi
    return 0
}

# -----------------------------------------------------------------------------
# log_project_error
# Args: $1=app-name, $2=message
# Returns: 0
# Study: same pattern as log_error; per-application log file
# -----------------------------------------------------------------------------
log_project_error() {
    deployctl_log_ensure_init
    local app="$1"
    local msg="$2"
    local line plog
    line="$(format_log_entry "ERROR" "$msg")"
    plog="${DEPLOYCTL_EFFECTIVE_LOG_BASE}/projects/${app}.log"
    mkdir -p "$(dirname "$plog")" 2>/dev/null || true
    printf '%s\n' "$line" >>"$plog"
    printf '%s\n' "$line" >&2
    return 0
}