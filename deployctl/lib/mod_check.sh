#!/usr/bin/env bash 
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: deployctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: BEN YAMNA Mohammed <iamsernine@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_check.sh - dependency and filesystem prerequisite checks.

# shellcheck shell=bash 
# read https://www.shellcheck.net/wiki/ about shellcheck

# -----------------------------------------------------------------------------
# deployctl_check_dependencies
# Verifies docker, git, nginx, curl, ss are available.
# Returns: 0 if all present, 1 if any missing
# -----------------------------------------------------------------------------
deployctl_check_dependencies(){
    local missing=()
    require_command docker docker || missing+=("docker")
    require_command git git || missing+=("git")
    require_command nginx nginx  || missing+=("nginx")
    require_command curl curl || missing+=("curl")
    require_command ss ss || missing+=("iproute2/ss")
    if [[ ${#missing[@]} -gt 0 ]]; then 
        log_error "missing dependencies: ${missing[*]}"
        return 1 
    fi 
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_ensure_layout
# Creates standard deployctl directories when root or dry-run simulates.
# Returns: 0
# -----------------------------------------------------------------------------
deployctl_ensure_layout(){
    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]];then 
        log_info "[dry-run] would create deployctl directories under /etc /var /var/log /var/cache"
        return 0
    fi 
    mkdir -p "$DEPLOYCTL_ETC" "$DEPLOYCTL_PROJECTS_DIR" \
        "$DEPLOYCTL_PENDING_DIR" "$DEPLOYCTL_LIVE_DIR" "$DEPLOYCTL_ARCHIVE_DIR" \
        "$DEPLOYCTL_ENV_DIR" "$DEPLOYCTL_STATE_DIR" \
        "$DEPLOYCTL_LOG_DIR" "$DEPLOYCTL_PROJECT_LOG_DIR" "$DEPLOYCTL_CACHE_DIR" "$DEPLOYCTL_BUILD_DIR" ||{
            log_error "failed to create deployctl directories "
            return 1 
        }
        chmod 755 "$DEPLOYCTL_ETC" "$DEPLOYCTL_VAR" 2>/dev/null || true 
        return 0 
}

# -----------------------------------------------------------------------------
# deployctl_check_port_free
# Uses ss to see if TCP port is listening (optional check before bind).
# Args: $1=port
# Returns: 0 if free, 1 if in use
# for more: ss(8) / iproute2 — inspect listening sockets from scripts
# -----------------------------------------------------------------------------
deployctl_check_port_free(){
    local port="$1"
    if ss -ltn 2>/dev/null | grep -q ":${port}"; then 
        return 1
    fi 
    if ss -ltn 2>/dev/null | grep -q ":${port}$"; then 
        return 1
    fi 
    return 0 
}