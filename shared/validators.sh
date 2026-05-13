#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# shared/validators.sh — Input validation and environment checks shared by deployctl and inboxctl.
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash [[ =~ ]] regex: https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html
#   BashGuide tests: https://mywiki.wooledge.org/BashGuide/TestsAndConditionals

# shellcheck shell=bash

# Requires: constants.sh sourced first.

# -----------------------------------------------------------------------------
# validate_app_name
# Ensures kebab-case: ^[a-z0-9][a-z0-9-]*[a-z0-9]$ (min length 2 implied by pattern).
# Args: $1=app name
# Returns: 0 if valid, 1 otherwise
# Study: https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html ( =~ )
# -----------------------------------------------------------------------------
validate_app_name() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        return 1
    fi
    if [[ "$name" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
        return 0
    fi
    return 1
}

# -----------------------------------------------------------------------------
# validate_domain
# Basic hostname/FQDN check (labels, no spaces).
# Args: $1=domain
# Returns: 0 if plausible, 1 otherwise
# Study: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameters.html (${#parameter} string length)
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
# TCP port 1-65535.
# Args: $1=port string
# Returns: 0 if valid
# Study: https://www.gnu.org/software/bash/manual/html_node/Shell-Arithmetic.html (( ))
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
# Args: $1=status string
# Returns: 0 if one of allowed statuses
# Study: https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html#index-case
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
# Args: $1=path
# Returns: 0 if regular file exists
# Study: https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html
# -----------------------------------------------------------------------------
validate_file_exists() {
    [[ -f "${1:-}" ]]
}

# -----------------------------------------------------------------------------
# validate_dir_exists
# Args: $1=path
# Returns: 0 if directory exists
# Study: https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html
# -----------------------------------------------------------------------------
validate_dir_exists() {
    [[ -d "${1:-}" ]]
}

# -----------------------------------------------------------------------------
# require_command
# Args: $1=command name for error message, $2=binary name to check
# Returns: 0 if found, 1 if missing (caller may exit_with_error)
# Study: https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html#index-command
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
# Study: https://wiki.bash-hackers.org/syntax/shellvars#euid (EUID); id(1)
# -----------------------------------------------------------------------------
require_root() {
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        return 0
    fi
    return 1
}
