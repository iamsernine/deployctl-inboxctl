#!/usr/bin/env bash 
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: deployctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: BEN YAMNA Mohammed <iamsernine@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_menu.sh - interactive operator menu wrapper

# shellcheck shell=bash 
# read https://www.shellcheck.net/wiki/ about shellcheck

# -----------------------------------------------------------------------------
# deployctl_run_menu
# Simple numeric menu redirecting to subcommands (requires TTY for read).
# Returns: exit code of chosen action
# -----------------------------------------------------------------------------
deployctl_run_menu(){
    printf 'deployctl menu\n'
    printf '  1) check\n'
    printf '  2) list live\n'
    printf '  3) version\n'
    printf '  4) exit\n'
    printf 'Choice: ' >&2
    local c
    read -r c || c="4"
    case "$c" in
        1) deployctl_cmd_check ;;
        2) deployctl_cmd_list "live" ;;
        3) printf '%s\n' "$DEPLOYCTL_INBOXCTL_VERSION (deployctl)" ;;
        *) return 0 ;;
    esac
}