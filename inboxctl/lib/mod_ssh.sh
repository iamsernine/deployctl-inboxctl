#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: ACHAHROUR Mustapha <mustaphaachahrour@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_ssh.sh - SSH connection and remote log retrieval
# consumes server profile variables exported by mod_server.sh:server_load;
# provides ssh_test, ssh_fetch, ssh_stream, ssh_exec
#
# requires: shared/constants.sh shared/format.sh shared/validators.sh
#           mod_server.sh (server_load must be called before any function here)
# shellcheck shell=bash

# =============================================================================
# Internal helpers
# =============================================================================

# -----------------------------------------------------------------------------
# _ssh_base_args
# builds the common SSH argument array used by all ssh_* functions
# uses: SERVER_USER SERVER_HOST SERVER_PORT SERVER_SSH_KEY (from server_load)
# returns: 0; populates global array _SSH_ARGS
# -----------------------------------------------------------------------------
_ssh_base_args() {
    _SSH_ARGS=(
        -i "${SERVER_SSH_KEY}"       # identity file
        -p "${SERVER_PORT}"          # port
        -o "BatchMode=yes"           # never prompt for password (key-only)
        -o "StrictHostKeyChecking=accept-new"  # auto-accept new host keys once
        -o "ConnectTimeout=10"       # fail fast if unreachable
        -o "ServerAliveInterval=15"  # detect broken connections
        -o "ServerAliveCountMax=3"
    )
}

# -----------------------------------------------------------------------------
# _ssh_target
# prints user@host for use in SSH commands
# returns: 0
# -----------------------------------------------------------------------------
_ssh_target() {
    printf '%s@%s' "${SERVER_USER}" "${SERVER_HOST}"
}

# -----------------------------------------------------------------------------
# _require_server_vars
# ensures server_load has been called before any ssh_* function
# returns: 0 if vars are set, exits with ERR_CONFIG_PARSE_ERROR otherwise
# -----------------------------------------------------------------------------
_require_server_vars() {
    local missing=()
    [[ -z "${SERVER_HOST:-}"            ]] && missing+=("SERVER_HOST")
    [[ -z "${SERVER_USER:-}"            ]] && missing+=("SERVER_USER")
    [[ -z "${SERVER_PORT:-}"            ]] && missing+=("SERVER_PORT")
    [[ -z "${SERVER_SSH_KEY:-}"         ]] && missing+=("SERVER_SSH_KEY")
    [[ -z "${SERVER_REMOTE_LOG_PATH:-}" ]] && missing+=("SERVER_REMOTE_LOG_PATH")

    if [[ ${#missing[@]} -gt 0 ]]; then
        printf 'ERROR: server_load must be called before ssh_*\n' >&2
        printf 'ERROR: missing vars: %s\n' "${missing[*]}" >&2
        exit "${ERR_CONFIG_PARSE_ERROR}"
    fi
}

# =============================================================================
# Public API
# =============================================================================


# TESTING MODE — comment this out for production
source /tmp/mock_ssh.sh
return 0


# -----------------------------------------------------------------------------
# ssh_test
# verifies the SSH connection to the server is working
# Args: none (uses SERVER_* vars from server_load)
# returns: 0 if connection succeeds, exits with ERR_SSH_FAILED otherwise
# -----------------------------------------------------------------------------
ssh_test() {
    _require_server_vars
    _ssh_base_args

    printf 'Testing SSH connection to %s:%s...\n' \
        "${SERVER_HOST}" "${SERVER_PORT}"

    if ssh "${_SSH_ARGS[@]}" "$(_ssh_target)" "exit 0" 2>/dev/null; then
        printf 'Connection OK: %s@%s:%s\n' \
            "${SERVER_USER}" "${SERVER_HOST}" "${SERVER_PORT}"
        return 0
    else
        printf 'ERROR: SSH connection failed to %s@%s:%s\n' \
            "${SERVER_USER}" "${SERVER_HOST}" "${SERVER_PORT}" >&2
        printf 'Check: host reachable, key valid, user exists on server.\n' >&2
        exit "${ERR_SSH_FAILED}"
    fi
}

# -----------------------------------------------------------------------------
# ssh_exec
# runs a single command on the remote server and returns its output
# Args: $1=remote_command (string)
# returns: exit code of the remote command; output on stdout
# -----------------------------------------------------------------------------
ssh_exec() {
    local remote_cmd="${1:?remote command required}"
    _require_server_vars
    _ssh_base_args

    ssh "${_SSH_ARGS[@]}" "$(_ssh_target)" "${remote_cmd}"
    return $?
}

# -----------------------------------------------------------------------------
# ssh_fetch
# fetches the full remote history.log and saves it locally
# saves to: $INBOXCTL_SERVER_CACHE_DIR/<server_name>/history.log
# Args: $1=server_name (used for local cache path)
# returns: 0 on success, exits with ERR_SSH_FAILED on failure
# -----------------------------------------------------------------------------
ssh_fetch() {
    local server_name="${1:?server name required}"
    _require_server_vars
    _ssh_base_args

    # prepare local cache directory for this server
    local cache_dir="${INBOXCTL_SERVER_CACHE_DIR}/${server_name}/logs"
    mkdir -p "${cache_dir}" || {
        printf 'ERROR: cannot create cache dir: %s\n' "${cache_dir}" >&2
        exit "${ERR_FILE_PERMISSION_ERROR}"
    }

    local local_log="${cache_dir}/history.log"
    local tmp_log
    tmp_log="$(mktemp)"

    printf 'Fetching logs from %s:%s...\n' \
        "${SERVER_HOST}" "${SERVER_REMOTE_LOG_PATH}"

    # fetch remote log via SSH cat into temp file
    if ssh "${_SSH_ARGS[@]}" "$(_ssh_target)" \
        "cat '${SERVER_REMOTE_LOG_PATH}'" > "${tmp_log}" 2>/dev/null; then

        local line_count
        line_count="$(wc -l < "${tmp_log}")"

        mv "${tmp_log}" "${local_log}"
        chmod 600 "${local_log}"

        printf 'Fetched %s lines -> %s\n' "${line_count}" "${local_log}"
        return 0
    else
        rm -f "${tmp_log}"
        printf 'ERROR: failed to fetch logs from %s\n' "${SERVER_HOST}" >&2
        printf 'Remote path: %s\n' "${SERVER_REMOTE_LOG_PATH}" >&2
        exit "${ERR_SSH_FAILED}"
    fi
}

# -----------------------------------------------------------------------------
# ssh_fetch_since
# fetches only log lines newer than a given timestamp (incremental fetch)
# avoids re-downloading the full log on every run
# Args: $1=server_name $2=since_timestamp (format: yyyy-mm-dd-hh-mm-ss)
# returns: 0; new lines saved to cache_dir/history_new.log
# -----------------------------------------------------------------------------
ssh_fetch_since() {
    local server_name="${1:?server name required}"
    local since="${2:?since timestamp required}"
    _require_server_vars
    _ssh_base_args

    local cache_dir="${INBOXCTL_SERVER_CACHE_DIR}/${server_name}/logs"
    mkdir -p "${cache_dir}"

    local local_log="${cache_dir}/history.log"
    local tmp_log
    tmp_log="$(mktemp)"

    # count how many lines we already have locally
    local local_lines=0
    if [[ -f "${local_log}" ]]; then
        local_lines="$(wc -l < "${local_log}")"
    fi

    printf 'Fetching logs since %s from %s...\n' "${since}" "${SERVER_HOST}"

    # skip exactly the lines we already have, fetch only what's new
    # tail -n +N means "start from line N" (1-indexed)
    # so tail -n +$(local_lines+1) skips first local_lines lines
    local remote_cmd
    remote_cmd="tail -n +$((local_lines + 1)) '${SERVER_REMOTE_LOG_PATH}'"

    if ssh "${_SSH_ARGS[@]}" "$(_ssh_target)" "${remote_cmd}" \
        > "${tmp_log}" 2>/dev/null; then

        local line_count
        line_count="$(wc -l < "${tmp_log}")"

        if [[ "${line_count}" -eq 0 ]]; then
            printf 'No new lines since %s\n' "${since}"
            rm -f "${tmp_log}"
            return 0
        fi

        # append new lines to the existing history.log
        cat "${tmp_log}" >> "${local_log}"
        chmod 600 "${local_log}"
        rm -f "${tmp_log}"

        printf 'Appended %s new lines -> %s\n' "${line_count}" "${local_log}"
        return 0
    else
        rm -f "${tmp_log}"
        printf 'ERROR: incremental fetch failed from %s\n' "${SERVER_HOST}" >&2
        exit "${ERR_SSH_FAILED}"
    fi
}

# -----------------------------------------------------------------------------
# ssh_stream
# streams the remote log in real time (live tail -f equivalent)
# useful for watch mode (called by mod_watch.sh)
# Args: $1=server_name $2=lines (number of last lines to show first, default 20)
# returns: exits when user interrupts (Ctrl+C)
# -----------------------------------------------------------------------------
ssh_stream() {
    local server_name="${1:?server name required}"
    local lines="${2:-20}"
    _require_server_vars
    _ssh_base_args

    printf 'Streaming logs from %s (Ctrl+C to stop)...\n' "${SERVER_HOST}"
    printf 'Remote: %s\n\n' "${SERVER_REMOTE_LOG_PATH}"

    # tail -f on the remote file over SSH; exits on Ctrl+C
    ssh "${_SSH_ARGS[@]}" "$(_ssh_target)" \
        "tail -n ${lines} -f '${SERVER_REMOTE_LOG_PATH}'"

    # ssh will return when the connection closes or user interrupts
    return 0
}

# -----------------------------------------------------------------------------
# ssh_check_remote_log
# verifies the remote log file exists and is readable on the server
# Args: none (uses SERVER_* vars)
# returns: 0 if accessible, 1 if not found/readable
# -----------------------------------------------------------------------------
ssh_check_remote_log() {
    _require_server_vars
    _ssh_base_args

    printf 'Checking remote log path: %s\n' "${SERVER_REMOTE_LOG_PATH}"

    if ssh "${_SSH_ARGS[@]}" "$(_ssh_target)" \
        "[[ -f '${SERVER_REMOTE_LOG_PATH}' && -r '${SERVER_REMOTE_LOG_PATH}' ]]" \
        2>/dev/null; then

        local size
        size="$(ssh "${_SSH_ARGS[@]}" "$(_ssh_target)" \
            "wc -l < '${SERVER_REMOTE_LOG_PATH}'" 2>/dev/null || printf '?')"

        printf 'Remote log OK: %s lines\n' "${size}"
        return 0
    else
        printf 'ERROR: remote log not found or not readable: %s\n' \
            "${SERVER_REMOTE_LOG_PATH}" >&2
        printf 'Make sure deployctl has run at least once on the server.\n' >&2
        return 1
    fi
}

# -----------------------------------------------------------------------------
# ssh_fetch_projects
# fetches all project .conf files from /etc/deployctl/projects.d/ on the server
# stores each one locally via cache_store_project_conf
# Args: $1=server_name
# returns: 0 on success, exits with ERR_SSH_FAILED on failure
# -----------------------------------------------------------------------------
ssh_fetch_projects() {
    local server_name="${1:?server name required}"
    _require_server_vars
    _ssh_base_args
 
    printf 'Fetching project configs from %s...\n' "${SERVER_HOST}"
 
    # get list of .conf files on the remote server
    local remote_list
    remote_list="$(ssh "${_SSH_ARGS[@]}" "$(_ssh_target)" \
        "ls -1 '${DEPLOYCTL_PROJECTS_DIR}'/*.conf 2>/dev/null" 2>/dev/null)" || {
        printf 'WARNING: no project configs found on server\n' >&2
        return 0
    }
 
    if [[ -z "${remote_list}" ]]; then
        printf 'No project configs found in %s\n' "${DEPLOYCTL_PROJECTS_DIR}"
        return 0
    fi
 
    local count=0
    while IFS= read -r remote_conf; do
        [[ -z "${remote_conf}" ]] && continue
 
        # extract app name from filename (e.g. myapp.conf → myapp)
        local app_name
        app_name="$(basename "${remote_conf}" .conf)"
 
        # fetch content of the .conf file
        local content
        content="$(ssh "${_SSH_ARGS[@]}" "$(_ssh_target)" \
            "cat '${remote_conf}'" 2>/dev/null)" || {
            printf 'WARNING: could not read %s\n' "${remote_conf}" >&2
            continue
        }
 
        # store locally via mod_cache.sh
        cache_store_project_conf "${server_name}" "${app_name}" "${content}"
        ((count++))
 
    done <<< "${remote_list}"
 
    printf '[ssh] Fetched %s project config(s) from %s\n' \
        "${count}" "${SERVER_HOST}"
    return 0
}
 
# -----------------------------------------------------------------------------
# ssh_fetch_project_logs
# fetches per-project log files from /var/log/deployctl/projects/ on the server
# stores each one locally via cache_store_project_log
# Args: $1=server_name
# returns: 0 on success
# -----------------------------------------------------------------------------
ssh_fetch_project_logs() {
    local server_name="${1:?server name required}"
    _require_server_vars
    _ssh_base_args
 
    printf 'Fetching project logs from %s...\n' "${SERVER_HOST}"
 
    # get list of .log files in remote projects log dir
    local remote_list
    remote_list="$(ssh "${_SSH_ARGS[@]}" "$(_ssh_target)" \
        "ls -1 '${DEPLOYCTL_PROJECT_LOG_DIR}'/*.log 2>/dev/null" 2>/dev/null)" || {
        printf 'WARNING: no project logs found on server\n' >&2
        return 0
    }
 
    if [[ -z "${remote_list}" ]]; then
        printf 'No project logs found in %s\n' "${DEPLOYCTL_PROJECT_LOG_DIR}"
        return 0
    fi
 
    local count=0
    while IFS= read -r remote_log; do
        [[ -z "${remote_log}" ]] && continue
 
        local app_name
        app_name="$(basename "${remote_log}" .log)"
 
        local content
        content="$(ssh "${_SSH_ARGS[@]}" "$(_ssh_target)" \
            "cat '${remote_log}'" 2>/dev/null)" || {
            printf 'WARNING: could not read %s\n' "${remote_log}" >&2
            continue
        }
 
        cache_store_project_log "${server_name}" "${app_name}" "${content}"
        ((count++))
 
    done <<< "${remote_list}"
 
    printf '[ssh] Fetched %s project log(s) from %s\n' \
        "${count}" "${SERVER_HOST}"
    return 0
}
 
# -----------------------------------------------------------------------------
# ssh_fetch_meta
# fetches server system info (os, uptime, disk, memory) via SSH
# stores result locally via cache_write_meta
# Args: $1=server_name
# returns: 0 on success, exits with ERR_SSH_FAILED on failure
# -----------------------------------------------------------------------------
ssh_fetch_meta() {
    local server_name="${1:?server name required}"
    _require_server_vars
    _ssh_base_args
 
    printf 'Fetching server metadata from %s...\n' "${SERVER_HOST}"
 
    # fetch all 4 values in one SSH connection using a heredoc command
    local raw
    raw="$(ssh "${_SSH_ARGS[@]}" "$(_ssh_target)" '
        # OS info — extract PRETTY_NAME from /etc/os-release
        os=$(grep "PRETTY_NAME=" /etc/os-release | sed 's/.*="\(.*\)"/\1/' 2>/dev/null)
        [[ -z "$os" ]] && os="unknown"
 
        # uptime — human readable
        uptime_str=$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo "unknown")
 
        # disk usage of / — percentage used
        disk=$(df -h / 2>/dev/null | awk "NR==2 {print \$5}" || echo "unknown")
 
        # memory — used/total
        memory=$(free -h 2>/dev/null \
            | 9
 
        printf "%s\n%s\n%s\n%s\n" "$os" "$uptime_str" "$disk" "$memory"
    ' 2>/dev/null)" || {
        printf 'ERROR: failed to fetch metadata from %s\n' \
            "${SERVER_HOST}" >&2
        exit "${ERR_SSH_FAILED}"
    }
 
    # parse the 4 lines into variables
    local os uptime_str disk memory
    os="$(       printf '%s' "${raw}" | sed -n '1p')"
    uptime_str="$(printf '%s' "${raw}" | sed -n '2p')"
    disk="$(     printf '%s' "${raw}" | sed -n '3p')"
    memory="$(   printf '%s' "${raw}" | sed -n '4p')"
 
    # store locally
    cache_write_meta "${server_name}" "${os}" "${uptime_str}" "${disk}" "${memory}"
 
    printf '[ssh] Metadata fetched and cached for server: %s\n' "${server_name}"
    return 0
}