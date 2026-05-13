#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: ACHAHROUR Mustapha <mustaphaachahrour@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_ssh.sh — Non-interactive SSH helpers (keys only; never passwords).

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

# -----------------------------------------------------------------------------
# inboxctl_ssh_target
# Reads SSH_TARGET from server conf.
# Args: $1=server name
# Prints: user@host
# Returns: 0 if found
# Study: read_conf_value from shared/format.sh
# -----------------------------------------------------------------------------
inboxctl_ssh_target() {
    local name="$1"
    local f
    f="$(inboxctl_server_conf_path "$name")"
    read_conf_value "$f" SSH_TARGET
}

# -----------------------------------------------------------------------------
# inboxctl_ssh_test_connection
# Args: $1=server name
# Returns: 0 if ssh succeeds
# Study: ssh(1) BatchMode=yes for non-interactive use
# -----------------------------------------------------------------------------
inboxctl_ssh_test_connection() {
    local name="$1"
    local target
    target="$(inboxctl_ssh_target "$name")" || return 1
    local ssh_opts=(-o BatchMode=yes -o ConnectTimeout=10)
    if [[ "${INBOXCTL_VERBOSE:-0}" == "1" ]]; then
        ssh_opts+=(-v)
    fi
    ssh "${ssh_opts[@]}" "$target" true
}
