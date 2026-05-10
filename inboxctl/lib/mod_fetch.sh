#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: ACHAHROUR Mustapha <mustaphaachahrour@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_fetch.sh - orchestration layer for log retrieval
# ties together mod_server.sh and mod_ssh.sh;
# decides full vs incremental fetch based on last line of local history.log,
# appends new lines to local history.log, hands lines to mod_parse.sh
#
# requires: shared/constants.sh shared/format.sh
#           mod_server.sh mod_ssh.sh
# shellcheck shell=bash

# =============================================================================
# Internal helpers
# =============================================================================

# -----------------------------------------------------------------------------
# _fetch_cache_log_path
# returns the path of the locally cached log for a server
# Args: $1=server_name
# returns: 0; prints path to stdout
# -----------------------------------------------------------------------------
_fetch_cache_log_path() {
    local server_name="${1:?server name required}"
    printf '%s/%s/logs/history.log' \
        "${INBOXCTL_SERVER_CACHE_DIR}" "${server_name}"
}

# -----------------------------------------------------------------------------
# _fetch_last_timestamp
# reads the timestamp of the last line in local history.log
# used by fetch_incremental to know where to resume from
# Args: $1=server_name
# returns: 0 if history.log exists and is non-empty (prints timestamp)
#          1 if file does not exist or is empty (first run)
# -----------------------------------------------------------------------------
_fetch_last_timestamp() {
    local server_name="${1:?server name required}"
    local local_log
    local_log="$(_fetch_cache_log_path "${server_name}")"

    # file must exist and be non-empty
    if [[ ! -f "${local_log}" ]] || [[ ! -s "${local_log}" ]]; then
        return 1
    fi

    # log format: yyyy-mm-dd-hh-mm-ss : user : LEVEL : message
    # extract timestamp from the last line
    local since
    since="$(tail -n 1 "${local_log}" | awk -F' : ' '{print $1}')"

    if [[ -z "${since}" ]]; then # check size of since
        return 1
    fi

    printf '%s' "${since}"
    return 0
}

# =============================================================================
# Public API
# =============================================================================

# -----------------------------------------------------------------------------
# fetch_full
# performs a full fetch of the remote history.log for a given server
# use this on first run or when a fresh copy is needed
# Args: $1=server_name
# returns: 0 on success; path of local log printed to stdout
# -----------------------------------------------------------------------------
fetch_full() {
    local server_name="${1:?server name required}"

    printf '[fetch] Full fetch starting for server: %s\n' "${server_name}"

    # load server profile -> exports SERVER_* vars
    server_load "${server_name}"

    # verify SSH connection
    ssh_test

    # verify remote log exists and is readable
    ssh_check_remote_log || exit "${ERR_SSH_FAILED}"

    # initialize cache for this server
    cache_init "${server_name}"

    # fetch full
    ssh_fetch "${server_name}"
    ssh_fetch_projects "${server_name}"
    ssh_fetch_project_logs "${server_name}"
    ssh_fetch_meta "${server_name}"

    local local_log
    local_log="$(_fetch_cache_log_path "${server_name}")"
    printf '[fetch] Full fetch complete: %s\n' "${local_log}"
    printf '%s\n' "${local_log}"
    return 0
}

# -----------------------------------------------------------------------------
# fetch_incremental
# fetches only log lines newer than the last line in local history.log
# falls back to full fetch if history.log does not exist or is empty (first run)
# Args: $1=server_name
# returns: 0 on success; path of local history.log printed to stdout
# -----------------------------------------------------------------------------
fetch_incremental() {
    local server_name="${1:?server name required}"

    # read last timestamp from local history.log
    local since
    if ! since="$(_fetch_last_timestamp "${server_name}")"; then
        printf '[fetch] No local log found — falling back to full fetch\n'
        fetch_full "${server_name}"
        return $?
    fi

    printf '[fetch] Incremental fetch since %s for server: %s\n' \
        "${since}" "${server_name}"

    # load server profile
    server_load "${server_name}"

    # verify connection
    ssh_test

    # fetch only lines newer than last timestamp -> appends to history.log
    ssh_fetch_since "${server_name}" "${since}"

    local local_log
    local_log="$(_fetch_cache_log_path "${server_name}")"

    local line_count
    line_count="$(wc -l < "${local_log}" 2>/dev/null || printf '0')"

    printf '[fetch] Incremental fetch complete: %s total lines -> %s\n' \
        "${line_count}" "${local_log}"

    printf '%s\n' "${local_log}"
    return 0
}

# -----------------------------------------------------------------------------
# fetch_and_pipe
# fetches new logs and pipes each line to a handler function
# designed to be called by mod_parse.sh or mod_cache.sh
# Args: $1=server_name $2=handler_function (called with each log line)
# returns: 0 on success
# Example:
#   fetch_and_pipe "my-server" parse_log_line
# -----------------------------------------------------------------------------
fetch_and_pipe() {
    local server_name="${1:?server name required}"
    local handler="${2:?handler function required}"

    # ensure handler is a callable function
    if ! declare -f "${handler}" > /dev/null 2>&1; then
        printf 'ERROR: handler function not found: %s\n' "${handler}" >&2
        exit "${ERR_CONFIG_PARSE_ERROR}"
    fi

    # fetch incrementally
    local log_path
    log_path="$(fetch_incremental "${server_name}")"

    if [[ ! -f "${log_path}" ]]; then
        printf '[fetch] Nothing to pipe — log file missing: %s\n' "${log_path}"
        return 0
    fi

    # pipe each line to the handler
    local count=0
    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ -z "${line// /}" ]] && continue   # skip blank lines: //(" ") :search and replace space (" ") with /"" (nothing)
        "${handler}" "${line}"
        ((count++))
    done < "${log_path}"

    printf '[fetch] Piped %s lines to %s\n' "${count}" "${handler}"
    return 0
}

# -----------------------------------------------------------------------------
# fetch_status
# shows the current fetch state for a server (last timestamp, cache size)
# Args: $1=server_name
# returns: 0
# -----------------------------------------------------------------------------
fetch_status() {
    local server_name="${1:?server name required}"
    local cache_log
    cache_log="$(_fetch_cache_log_path "${server_name}")"

    printf '=== Fetch status: %s ===\n' "${server_name}"

    if [[ -f "${cache_log}" ]] && [[ -s "${cache_log}" ]]; then
        local total_lines last_ts
        total_lines="$(wc -l < "${cache_log}")"
        last_ts="$(tail -n 1 "${cache_log}" | awk -F' : ' '{print $1}')"
        printf '  Last fetch  : %s\n' "${last_ts}"
        printf '  Local log   : %s (%s lines)\n' "${cache_log}" "${total_lines}"
    else
        printf '  Last fetch  : never\n'
        printf '  Local log   : not fetched yet\n'
    fi

    return 0
}

# -----------------------------------------------------------------------------
# fetch_reset
# deletes the local cached log for a server (forces full re-fetch next time)
# Args: $1=server_name
# returns: 0
# -----------------------------------------------------------------------------
fetch_reset() {
    local server_name="${1:?server name required}"

    printf '[fetch] Resetting fetch state for server: %s\n' "${server_name}"

    rm -f "$(_fetch_cache_log_path "${server_name}")"

    printf '[fetch] Reset complete. Next fetch will be a full fetch.\n'
    return 0
}