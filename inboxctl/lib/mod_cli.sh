#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_cli.sh — Global options, usage, and version display for inboxctl.

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

INBOXCTL_VERBOSE=0

# -----------------------------------------------------------------------------
# inboxctl_print_usage
# Prints help text matching implemented subcommands.
# Returns: 0
# Study: here-doc for static help text
# -----------------------------------------------------------------------------
inboxctl_print_usage() {
    cat <<'EOF'
inboxctl — read-only remote deployctl inspector (local workstation)

Usage:
  inboxctl [global-options] <command> [arguments]

Global options:
  -h, --help      Show help
  -v, --verbose   Verbose SSH/scp diagnostics

Commands:
  add-server <name> <user@host>
  remove-server <name>
  list servers
  show servers
  test <name>
  fetch <name>
  show projects <name>
  show live <name>
  show pending <name>
  show archive <name>
  logs <server> <app>
  errors <name>
  watch <name>
  version
  help
EOF
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_parse_globals
# Parses -v/--verbose; leaves remaining args in INBOXCTL_ARGS array.
# Returns: 0
# Study: argv parsing with case and shift (same idea as deployctl globals)
# -----------------------------------------------------------------------------
inboxctl_parse_globals() {
    INBOXCTL_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h | --help)
                inboxctl_print_usage
                exit 0
                ;;
            -v | --verbose)
                INBOXCTL_VERBOSE=1
                shift
                ;;
            --)
                shift
                while [[ $# -gt 0 ]]; do
                    INBOXCTL_ARGS+=("$1")
                    shift
                done
                return 0
                ;;
            -*)
                inboxctl_exit_with_error "$ERR_UNKNOWN_OPTION" "unknown option ${1}"
                ;;
            *)
                INBOXCTL_ARGS+=("$@")
                return 0
                ;;
        esac
    done
    return 0
}
