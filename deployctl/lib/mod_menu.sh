#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_menu.sh — Interactive operator menu wrapper.

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

# -----------------------------------------------------------------------------
# deployctl_run_menu
# Simple numeric menu redirecting to subcommands (requires TTY for read).
# Returns: exit code of chosen action
# Study: https://www.gnu.org/software/bash/manual/html_node/Compound-Commands.html#index-case
# -----------------------------------------------------------------------------
deployctl_run_menu() {
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
