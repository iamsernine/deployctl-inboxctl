#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: ACHAHROUR Mustapha <mustaphaachahrour@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/inboxctl.sh - local-side CLI entrypoint for deployment log collection.
# sources shared contracts and modular libraries; dispatches subcommands

# shellcheck shell=bash

set -euo pipefail
 
# =============================================================================
# Path resolution
# resolves SCRIPT_DIR (inboxctl/), REPO_ROOT (project root), SHARED (shared/)
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SHARED="${REPO_ROOT}/shared"
LIB="${SCRIPT_DIR}/lib"
 
# =============================================================================
# Source shared contracts (order matters)
# =============================================================================
# shellcheck source=../shared/constants.sh
source "${SHARED}/constants.sh"
 
# shellcheck source=../shared/format.sh
source "${SHARED}/format.sh"
 
# shellcheck source=../shared/validators.sh
source "${SHARED}/validators.sh"
 
# =============================================================================
# Source inboxctl modules
# =============================================================================
# shellcheck source=lib/mod_server.sh
source "${LIB}/mod_server.sh"
 
# shellcheck source=lib/mod_ssh.sh
source "${LIB}/mod_ssh.sh"
 
# shellcheck source=lib/mod_fetch.sh
source "${LIB}/mod_fetch.sh"
 
# shellcheck source=lib/mod_parse.sh
source "${LIB}/mod_parse.sh"
 
# shellcheck source=lib/mod_cache.sh
source "${LIB}/mod_cache.sh"
 
# shellcheck source=lib/mod_watch.sh
source "${LIB}/mod_watch.sh"
 
# shellcheck source=lib/mod_ui.sh
source "${LIB}/mod_ui.sh"
 
# shellcheck source=lib/mod_cli.sh
source "${LIB}/mod_cli.sh"
 
# =============================================================================
# Usage / help
# =============================================================================
_usage() {
    cat <<EOF
NAME
    inboxctl - local-side log collector for deployctl
 
SYNOPSIS
    inboxctl [OPTIONS] <subcommand> [args...]
 
DESCRIPTION
    inboxctl connects to a remote server running deployctl over SSH,
    fetches deployment logs, classifies and archives them locally.
 
OPTIONS
    -h          Show this help message
    -f          Run subcommand in a forked subprocess
    -t          Run subcommand using background threads
    -s          Run subcommand in an isolated subshell
    -l <dir>    Use custom log directory (default: ${INBOXCTL_CONFIG_DIR})
    -r          Restore cached logs to default location (admin only)
    -v          Verbose mode
 
SUBCOMMANDS
    server add <name> <host> <user> [port] [key] [remote_log]
                        Add a new server profile
    server remove <name>
                        Remove a server profile
    server list         List all registered servers
    server show <name>  Show details of a server profile
    server update <name> <key> <value>
                        Update a key in a server profile
 
    fetch <name>        Fetch latest logs from server (incremental)
    fetch full <name>   Fetch full log from server
    fetch status <name> Show fetch state for a server
    fetch reset <name>  Reset fetch state (forces full re-fetch)
 
    watch <name>        Stream live logs from server (Ctrl+C to stop)
 
    test <name>         Test SSH connection to a server
 
CODES DE RETOUR
    0    Success
    100  Unknown option
    101  Missing parameter
    113  SSH connection failed
    114  Config parse error
    116  Missing dependency
 
EXAMPLES
    inboxctl server add prod 192.168.1.10 root
    inboxctl test prod
    inboxctl fetch prod
    inboxctl -f fetch full prod
    inboxctl watch prod
 
LOGS
    ${INBOXCTL_CONFIG_DIR}
 
AUTHOR
    ENSET Mohammedia --- 2026
EOF
}
 
# =============================================================================
# Option parsing
# =============================================================================
OPT_FORK=false
OPT_THREAD=false
OPT_SUBSHELL=false
OPT_VERBOSE=false
OPT_RESTORE=false
CUSTOM_LOG_DIR=""
 
while getopts ":hftsvrl:" opt; do
    case "${opt}" in
        h) _usage; exit 0 ;;
        f) OPT_FORK=true ;;
        t) OPT_THREAD=true ;;
        s) OPT_SUBSHELL=true ;;
        v) OPT_VERBOSE=true ;;
        r) OPT_RESTORE=true ;;
        l) CUSTOM_LOG_DIR="${OPTARG}" ;;
        :)
            printf 'ERROR: option -%s requires an argument\n' \
                "${OPTARG}" >&2
            _usage
            exit "${ERR_MISSING_PARAM}"
            ;;
        ?)
            printf 'ERROR: unknown option: -%s\n' "${OPTARG}" >&2
            _usage
            exit "${ERR_UNKNOWN_OPTION}"
            ;;
    esac
done
shift $((OPTIND - 1))
 
# override log dir if provided
if [[ -n "${CUSTOM_LOG_DIR}" ]]; then
    INBOXCTL_CONFIG_DIR="${CUSTOM_LOG_DIR}"
fi
 
# handle restore immediately after option parsing (requires root)
if [[ "${OPT_RESTORE}" == true ]]; then
    require_root || {
        printf 'ERROR: -r requires root privileges\n' >&2
        exit "${ERR_NOT_ROOT}"
    }
    fetch_reset "${1:?server name required for restore}"
    exit $?
fi
 
# export verbose flag so modules can check it
export INBOXCTL_VERBOSE="${OPT_VERBOSE}"
 
# =============================================================================
# Subcommand dispatcher
# =============================================================================
 
# require at least one subcommand
if [[ $# -lt 1 ]]; then
    printf 'ERROR: subcommand required\n' >&2
    _usage
    exit "${ERR_MISSING_PARAM}"
fi
 
SUBCOMMAND="${1}"
shift
 
# -----------------------------------------------------------------------------
# _dispatch
# runs the actual subcommand logic;
# called directly or wrapped in fork/thread/subshell depending on options
# -----------------------------------------------------------------------------
_dispatch() {
    case "${SUBCOMMAND}" in
 
        # --- server management ---
        server)
            local action="${1:-}"
            shift || true
            case "${action}" in
                add)    server_add    "$@" ;;
                remove) server_remove "$@" ;;
                list)   server_list        ;;
                show)   server_show   "$@" ;;
                update) server_update "$@" ;;
                *)
                    printf 'ERROR: unknown server action: %s\n' \
                        "${action}" >&2
                    _usage
                    exit "${ERR_UNKNOWN_OPTION}"
                    ;;
            esac
            ;;
 
        # --- log fetching ---
        fetch)
            local mode="${1:-}"
            case "${mode}" in
                full)
                    shift
                    fetch_full "${1:?server name required}"
                    ;;
                status)
                    shift
                    fetch_status "${1:?server name required}"
                    ;;
                reset)
                    shift
                    fetch_reset "${1:?server name required}"
                    ;;
                *)
                    # default: incremental fetch
                    fetch_incremental "${mode:?server name required}"
                    ;;
            esac
            ;;
 
        # --- live streaming ---
        watch)
            local server_name="${1:?server name required}"
            server_load "${server_name}"
            ssh_stream "${server_name}" "${2:-20}"
            ;;
 
        # --- connection test ---
        test)
            local server_name="${1:?server name required}"
            server_load "${server_name}"
            ssh_test
            ssh_check_remote_log
            ;;
 
        # --- unknown subcommand ---
        *)
            printf 'ERROR: unknown subcommand: %s\n' "${SUBCOMMAND}" >&2
            _usage
            exit "${ERR_UNKNOWN_OPTION}"
            ;;
    esac
}
 
# =============================================================================
# Execution mode — fork / thread / subshell / direct
# =============================================================================
if [[ "${OPT_FORK}" == true ]]; then
    # run in a forked subprocess; parent waits for child
    (
        _dispatch "$@"
    ) &
    FORK_PID=$!
    printf '[inboxctl] fork started (PID: %s)\n' "${FORK_PID}"
    wait "${FORK_PID}"
    FORK_STATUS=$?
    if [[ ${FORK_STATUS} -ne 0 ]]; then
        printf '[inboxctl] fork failed (PID: %s, code: %s)\n' \
            "${FORK_PID}" "${FORK_STATUS}" >&2
        exit "${FORK_STATUS}"
    fi
    printf '[inboxctl] fork completed (PID: %s)\n' "${FORK_PID}"
 
elif [[ "${OPT_THREAD}" == true ]]; then
    # run as background job; simulate thread with &
    _dispatch "$@" &
    THREAD_PID=$!
    printf '[inboxctl] thread started (PID: %s)\n' "${THREAD_PID}"
    wait "${THREAD_PID}"
    THREAD_STATUS=$?
    if [[ ${THREAD_STATUS} -ne 0 ]]; then
        printf '[inboxctl] thread failed (PID: %s, code: %s)\n' \
            "${THREAD_PID}" "${THREAD_STATUS}" >&2
        exit "${THREAD_STATUS}"
    fi
    printf '[inboxctl] thread completed (PID: %s)\n' "${THREAD_PID}"
 
elif [[ "${OPT_SUBSHELL}" == true ]]; then
    # run in an isolated subshell; env changes stay local
    (
        export SUBSHELL_CONTEXT=true
        printf '[inboxctl] subshell started (PID: $$, PPID: %s)\n' "${PPID}"
        _dispatch "$@"
    )
    SUBSHELL_STATUS=$?
    printf '[inboxctl] subshell exited (code: %s)\n' "${SUBSHELL_STATUS}"
    exit "${SUBSHELL_STATUS}"
 
else
    # default: direct execution in current shell
    _dispatch "$@"
fi