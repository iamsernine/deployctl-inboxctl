#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: ACHAHROUR Mustapha <mustaphaachahrour@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_fetch.sh — Read-only copy of remote deployctl metadata and logs.

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

# -----------------------------------------------------------------------------
# inboxctl_fetch_server_data
# Uses scp/rsync-style copies over SSH (read-only on remote).
# Args: $1=server name
# Returns: 0 on success
# Study: scp(1) — https://man.openbsd.org/scp.1
# -----------------------------------------------------------------------------
inboxctl_fetch_server_data() {
    local name="$1"
    local target
    target="$(inboxctl_ssh_target "$name")" || {
        printf 'inboxctl: unknown server %s\n' "$name" >&2
        return 1
    }

    inboxctl_prepare_cache_dirs "$name"
    local root
    root="$(inboxctl_cache_root_for_server "$name")"

    local ssh_opts=(-o BatchMode=yes)
    if [[ "${INBOXCTL_VERBOSE:-0}" == "1" ]]; then
        ssh_opts+=(-v)
    fi

    # Remote paths (read-only fetch)
    local r_proj="/etc/deployctl/projects.d"
    local r_hist="/var/log/deployctl/history.log"
    local r_plogs="/var/log/deployctl/projects"
    local r_state="/var/lib/deployctl/state"

    scp "${ssh_opts[@]}" -q -r \
        "${target}:${r_proj}/*" "${root}/projects.d/" 2>/dev/null || {
        ssh "${ssh_opts[@]}" "$target" "test -d ${r_proj}" || printf 'inboxctl: warning: no projects.d\n' >&2
    }

    scp "${ssh_opts[@]}" -q "${target}:${r_hist}" "${root}/history.log" 2>/dev/null || \
        printf 'inboxctl: warning: history.log missing\n' >&2

    scp "${ssh_opts[@]}" -q -r \
        "${target}:${r_plogs}/*" "${root}/logs/projects/" 2>/dev/null || true

    scp "${ssh_opts[@]}" -q -r \
        "${target}:${r_state}/*" "${root}/state/" 2>/dev/null || true

    local conf
    conf="$(inboxctl_server_conf_path "$name")"
    write_key_value "$conf" "LAST_FETCH" "$(current_timestamp)"
    printf 'inboxctl: fetch complete for %s → %s\n' "$name" "$root"
    return 0
}
