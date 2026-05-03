#!/usr/bin/env bash 
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl 
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: BEN YAMNA Mohammed <iamsernine@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# shared/validators.sh - input validation and environement checks shared by deployctl and inboxctl 

# shellcheck shell=bash 
# read https://www.shellcheck.net/wiki/ about shellcheck

# -----------------------------------------------------------------------------
# validate_app_name
# ensures kebab-case : ^[a-z0-9][a-z0-9]*[a-z0-9]$ (min length 2 implied by pattern)
# Args: $1=app name 
# returns: 0 if valid 1 otherwise 
# -----------------------------------------------------------------------------
validate_app_name(){
    local name="${1:-}"
    if [[ -z "$name"]]; then 
        return 1 
    fi 
    if [[ "$name" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then 
        return 0 
    fi 
    return 1
}

# -----------------------------------------------------------------------------
# validate_domain
# basic hostname/FQDN check (labels , no spaces)
# args: $1=domain 
# returns: 0 if plausible , 1 otherwise 
# -----------------------------------------------------------------------------
validate_domain() {
    local d="${1:-}"
    if [[ -z "$d" ]]; then
        return 1
    fi
    if [[ ${#d} -gt 253 ]]; then
        return 1
    fi
    if [[ "$d" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    fi
    return 1
}

# -----------------------------------------------------------------------------
# validate_port
# TCP port 1-65525
# args: $1=port string 
# returns: 0 if valid 
# -----------------------------------------------------------------------------
validate_port() {
    local port="${1:-}"
    if [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)); then
        return 0
    fi
    return 1
}

# -----------------------------------------------------------------------------
# validate_status
# args: $1=status string  
# returns: 0 if one of allowed statuses 
# -----------------------------------------------------------------------------
validate_status() {
    local s="${1:-}"
    case "$s" in
        pending | live | archive | error) return 0 ;;
        *) return 1 ;;
    esac
}

# -----------------------------------------------------------------------------
# validate_file_exists
# args: $1=path 
# returns: 0 if regular file exists  
# -----------------------------------------------------------------------------
validate_file_exists(){
    [[ -f "${1:-}" ]]
}

# -----------------------------------------------------------------------------
# validate_dir_exists
# Args: $1=path
# Returns: 0 if directory exists
# -----------------------------------------------------------------------------
validate_dir_exists() {
    [[ -d "${1:-}" ]]
}

# -----------------------------------------------------------------------------
# require_command
# Args: $1=command name for error message, $2=binary name to check
# Returns: 0 if found, 1 if missing (caller may exit_with_error)
# -----------------------------------------------------------------------------
require_command() {
    local bin="${2:-$1}"
    if ! command -v "$bin" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# require_root
# Ensures EUID is 0 when deployctl mutates system paths.
# Returns: 0 if root, 1 if not root
# -----------------------------------------------------------------------------
require_root() {
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        return 0
    fi
    return 1
}