#!/usr/bin/env bash 
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: deployctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: BEN YAMNA Mohammed <iamsernine@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_cli.sh - global CLI flags and usage text 

# shellcheck shell=bash 
# read https://www.shellcheck.net/wiki/ about shellcheck

DEPLOYCTL_VERBOSE=0
DEPLOYCTL_DRY_RUN=0
DEPLOYCTL_LOG_DIR_OVERRIDE=""
DEPLOYCTL_FORK_MODE=0
DEPLOYCTL_THREAD_MODE=0
DEPLOYCTL_SUBSHELL_MODE=0
DEPLOYCTL_RESTORE_MODE=0

# -----------------------------------------------------------------------------
# deployctl_reset_globals
# Resets parsed CLI state (used in tests).
# Returns: 0
# -----------------------------------------------------------------------------
deployctl_reset_globals() {
    DEPLOYCTL_VERBOSE=0
    DEPLOYCTL_DRY_RUN=0
    DEPLOYCTL_LOG_DIR_OVERRIDE=""
    DEPLOYCTL_FORK_MODE=0
    DEPLOYCTL_THREAD_MODE=0
    DEPLOYCTL_SUBSHELL_MODE=0
    DEPLOYCTL_RESTORE_MODE=0
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_parse_global_options
# Consumes leading global flags from argv; leaves command at position $1.
# Args: pass "$@" — outputs remaining args via stdout one per line is complex;
#       uses nameref-style: sets global REMAINING_ARGS array.
# Returns: 0
# -----------------------------------------------------------------------------
deployctl_parse_global_options() {
    REMAINING_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h | --help)
                deployctl_print_usage
                exit 0
                ;;
            -v | --verbose)
                DEPLOYCTL_VERBOSE=1
                shift
                ;;
            -n | --dry-run)
                DEPLOYCTL_DRY_RUN=1
                shift
                ;;
            -l | --log-dir)
                DEPLOYCTL_LOG_DIR_OVERRIDE="${2:?}"
                shift 2
                ;;
            -f | --fork)
                DEPLOYCTL_FORK_MODE=1
                shift
                ;;
            -t | --thread)
                DEPLOYCTL_THREAD_MODE=1
                shift
                ;;
            -s | --subshell)
                DEPLOYCTL_SUBSHELL_MODE=1
                shift
                ;;
            -r | --restore-mode)
                DEPLOYCTL_RESTORE_MODE=1
                shift
                ;;
            --)
                shift
                while [[ $# -gt 0 ]]; do
                    REMAINING_ARGS+=("$1")
                    shift
                done
                return 0
                ;;
            -*)
                exit_with_error "$ERR_UNKNOWN_OPTION" "unknown global option: $1"
                ;;
            *)
                REMAINING_ARGS+=("$@")
                return 0
                ;;
        esac
    done
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_print_usage
# Prints command summary.
# Returns: 0
# -----------------------------------------------------------------------------
deployctl_print_usage() {
    cat <<'EOF'
deployctl — Docker deploy helper 

Usage:
  deployctl [global-options] <command> [arguments]

Global options:
  -h, --help           Show this help
  -v, --verbose        Verbose logging to stderr
  -n, --dry-run        Simulate steps without changing system (best-effort)
  -l, --log-dir DIR    Override log directory (testing)
  -f, --fork           Hint: run heavy steps in forked context (demo/tests)
  -t, --thread         Hint: threaded execution mode flag (reserved)
  -s, --subshell       Hint: run deploy body in subshell (demo/tests)
  -r, --restore-mode   Restrict certain destructive ops (root checks)

Commands:
  check                          Verify dependencies and directories
  deploy [app] [--repo URL] [--domain D] [--port P] [--ssl yes|no]
  status <app>
  logs <app>
  archive <app>
  restore <app>
  list <live|pending|archive>
  ssl <app>
  menu                           Interactive menu
  version                        Show version

Examples:
  deployctl check
  deployctl deploy my-app --repo https://example.git --domain app.example.com --port 8080 --ssl no
EOF
    return 0
}
