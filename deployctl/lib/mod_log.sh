#!/usr/bin/env bash 
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: deployctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: BEN YAMNA Mohammed <iamsernine@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_log.sh - history and per-project logging with fixed format 

# shellcheck shell=bash 
# read https://www.shellcheck.net/wiki/ about shellcheck

# globals set by deployctl main : DEPLOYCTL_VERBOSE, DEPLOYCTL_LOG_DIR_OVERRIDE
# DEPLOYCTL_EFFECTIVE_LOG_BASE - resolved directory for history.log and projects/*.log 

# -----------------------------------------------------------------------------
# deployctl_log_ensure_init
# Ensures init_logs ran so DEPLOYCTL_EFFECTIVE_LOG_BASE is set (e.g. log_error before cmd body).
# Returns: 0
# -----------------------------------------------------------------------------
deployctl_log_ensure_init(){
    [[ -n "${DEPLOYCTL_EFFECTIVE_LOG_BASE:-}" ]] && return 0 
    init_logs
}

# -----------------------------------------------------------------------------
# init_logs
# Picks a writable log root: override, then /var/log/deployctl, then ~/.cache/deployctl/logs.
# Returns: 0 on success
# -----------------------------------------------------------------------------
init_logs(){
    local primary="${DEPLOYCTL_LOG_DIR_OVERRIDE:-$DEPLOYCTL_LOG_DIR}"
    local base="$primary"

    if [[ -z "${DEPLOYCTL_LOG_DIR_OVERRIDE:-}" ]];then 
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
# -----------------------------------------------------------------------------
log_info(){
    deployctl_log_ensure_init 
    local msg="$1"
    local line
    line="$(format_log_entry "INFOS" "$msg" )"
    local hist="${DEPLOYCTL_EFFECTIVE_LOG_BASE}/history.log"
    mkdir -p "$(dirname "$hist")" 2>/dev/null || true
    printf '%s\n' "$line" >>"$hist" 
    if [[ "${DEPLOYCTL_VERBOSE:-0}" == "1" ]];then 
        printf '%s\n' "$line" >&2
    fi 
    return 0 
}


# -----------------------------------------------------------------------------
# log_error
# Appends ERROR line to history log; always visible on stderr.
# Args: $1=message
# Returns: 0
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
