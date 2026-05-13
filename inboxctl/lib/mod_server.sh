#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: ACHAHROUR Mustapha <mustaphaachahrour@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_server.sh — Server definition files under ~/.config/inboxctl/servers.d/

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

# -----------------------------------------------------------------------------
# inboxctl_server_conf_path
# Args: $1=server name
# Prints: path to conf file
# Returns: 0
# Study: printf for safe path construction
# -----------------------------------------------------------------------------
inboxctl_server_conf_path() {
    printf '%s/%s.conf' "${INBOXCTL_SERVERS_DIR}" "$1"
}

# -----------------------------------------------------------------------------
# inboxctl_ensure_config_dirs
# Creates config and servers.d when missing.
# Returns: 0
# Study: mkdir -p idempotency
# -----------------------------------------------------------------------------
inboxctl_ensure_config_dirs() {
    mkdir -p "${INBOXCTL_SERVERS_DIR}"
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_write_server_conf
# Args: $1=name, $2=ssh target user@host
# Returns: 0
# Study: https://www.gnu.org/software/bash/manual/html_node/Command-Grouping.html (braces + redirect)
# -----------------------------------------------------------------------------
inboxctl_write_server_conf() {
    local name="$1"
    local target="$2"
    local f
    f="$(inboxctl_server_conf_path "$name")"
    inboxctl_ensure_config_dirs
    local now
    now="$(current_timestamp)"
    {
        printf 'SERVER_NAME=%s\n' "$name"
        printf 'SSH_TARGET=%s\n' "$target"
        printf 'CREATED_AT=%s\n' "$now"
        printf 'LAST_FETCH=\n'
    } >"$f"
    chmod 600 "$f"
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_remove_server_conf
# Args: $1=name
# Returns: 0 if removed
# Study: rm -f semantics
# -----------------------------------------------------------------------------
inboxctl_remove_server_conf() {
    local f
    f="$(inboxctl_server_conf_path "$1")"
    rm -f "$f"
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_list_server_names
# Prints basename of each *.conf in servers.d
# Returns: 0
# Study: https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html (nullglob)
# -----------------------------------------------------------------------------
inboxctl_list_server_names() {
    shopt -s nullglob
    local p
    for p in "${INBOXCTL_SERVERS_DIR}"/*.conf; do
        printf '%s\n' "$(basename "${p%.conf}")"
    done
    shopt -u nullglob
    return 0
}