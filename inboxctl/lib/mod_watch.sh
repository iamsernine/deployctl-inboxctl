#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: MEDINOU Soukaina <soukainamedinou22@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_watch.sh — Periodic refresh of fetched deployctl snapshot (read-only).

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

# -----------------------------------------------------------------------------
# inboxctl_watch_server
# Refetches every 3 seconds by default and redraws project table.
# Args: $1=server name, optional $2=interval seconds
# Returns: 0 when interrupted (SIGINT)
# Study: terminal escape sequences (clear/redraw)
# -----------------------------------------------------------------------------
inboxctl_watch_server() {
    local name="$1"
    local interval="${2:-3}"
    printf 'Watching %s (every %ss). Ctrl+C to stop.\n' "$name" "$interval"
    while true; do
        inboxctl_fetch_server_data "$name" || true
        local cache
        cache="$(inboxctl_cache_root_for_server "$name")"
        printf '\033[2J\033[H'
        inboxctl_ui_print_projects_table "$cache"
        sleep "$interval"
    done
}
