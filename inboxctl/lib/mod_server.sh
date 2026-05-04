#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: BEN YAMNA Mohammed <iamsernine@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_server.sh - server profile CRUD
# manages connection profiles stored in $INBOXCTL_SERVERS_DIR;
# each profile is a KEY=value file consumed by mod_ssh.sh
#
# requires: shared/constants.sh shared/format.sh shared/validators.sh
# shellcheck shell=bash

# =============================================================================
# Internal helpers
# =============================================================================

# -----------------------------------------------------------------------------
# _server_profile_path
# returns the full path of a server profile file
# Args: $1=server_name
# returns: 0; prints path to stdout
# -----------------------------------------------------------------------------
_server_profile_path() {
    local name="${1:?server name required}"
    printf '%s/%s.conf' "${INBOXCTL_SERVERS_DIR}" "${name}"
}

# -----------------------------------------------------------------------------
# _require_servers_dir
# ensures $INBOXCTL_SERVERS_DIR exists; creates it if not
# returns: 0 on success, exits on failure
# -----------------------------------------------------------------------------
_require_servers_dir() {
    if [[ ! -d "${INBOXCTL_SERVERS_DIR}" ]]; then
        mkdir -p "${INBOXCTL_SERVERS_DIR}" || {
            printf 'ERROR: cannot create servers directory: %s\n' \
                "${INBOXCTL_SERVERS_DIR}" >&2
            exit "${ERR_FILE_PERMISSION_ERROR}"
        }
        chmod 700 "${INBOXCTL_SERVERS_DIR}"
    fi
}

# =============================================================================
# Public API
# =============================================================================

# -----------------------------------------------------------------------------
# server_add
# creates a new server profile interactively or from args
# Args: $1=name $2=host $3=user $4=port $5=ssh_key $6=remote_log_path
# returns: 0 on success
# -----------------------------------------------------------------------------
server_add() {
    local name="${1:?server name required}"
    local host="${2:?host required}"
    local user="${3:?user required}"
    local port="${4:-22}"
    local ssh_key="${5:-${HOME}/.ssh/id_rsa}"
    local remote_log_path="${6:-${DEPLOYCTL_HISTORY_LOG}}"

    _require_servers_dir

    local profile
    profile="$(_server_profile_path "${name}")"

    # refuse to overwrite an existing profile silently
    if [[ -f "${profile}" ]]; then
        printf 'ERROR: server profile already exists: %s\n' "${name}" >&2
        printf 'Use server_update to modify it.\n' >&2
        return 1
    fi

    # validate port
    if ! validate_port "${port}" 2>/dev/null; then
        printf 'ERROR: invalid port: %s\n' "${port}" >&2
        exit "${ERR_MISSING_PARAM}"
    fi

    # validate ssh key exists
    if [[ ! -f "${ssh_key}" ]]; then
        printf 'WARNING: SSH key not found: %s\n' "${ssh_key}" >&2
        printf 'You can update it later with: server_update %s SSH_KEY <path>\n' \
            "${name}" >&2
    fi

    # write profile
    write_key_value "${profile}" "HOST"             "${host}"
    write_key_value "${profile}" "USER"             "${user}"
    write_key_value "${profile}" "PORT"             "${port}"
    write_key_value "${profile}" "SSH_KEY"          "${ssh_key}"
    write_key_value "${profile}" "REMOTE_LOG_PATH"  "${remote_log_path}"

    chmod 600 "${profile}"

    printf 'Server profile created: %s\n' "${name}"
    printf 'Profile path: %s\n' "${profile}"
    return 0
}

# -----------------------------------------------------------------------------
# server_remove
# deletes a server profile by name
# Args: $1=server_name
# returns: 0 on success, 1 if not found
# -----------------------------------------------------------------------------
server_remove() {
    local name="${1:?server name required}"
    local profile
    profile="$(_server_profile_path "${name}")"

    if [[ ! -f "${profile}" ]]; then
        printf 'ERROR: server profile not found: %s\n' "${name}" >&2
        return 1
    fi

    rm -f "${profile}"
    printf 'Server profile removed: %s\n' "${name}"
    return 0
}

# -----------------------------------------------------------------------------
# server_list
# lists all registered server profiles
# returns: 0; prints name and host of each server
# -----------------------------------------------------------------------------
server_list() {
    _require_servers_dir

    local found=0
    for profile in "${INBOXCTL_SERVERS_DIR}"/*.conf; do
        [[ -f "${profile}" ]] || continue
        local name host
        name="$(basename "${profile}" .conf)"
        host="$(read_conf_value "${profile}" "HOST" || printf 'unknown')"
        user="$(read_conf_value "${profile}" "USER" || printf 'unknown')"
        port="$(read_conf_value "${profile}" "PORT" || printf '22')"
        print_table_line "${name}" "${user}@${host}:${port}"
        found=1
    done

    if [[ ${found} -eq 0 ]]; then
        printf 'No server profiles found.\n'
        printf 'Use: inboxctl server add <name> <host> <user>\n'
    fi
    return 0
}

# -----------------------------------------------------------------------------
# server_show
# displays all key=value pairs for a given server profile
# Args: $1=server_name
# returns: 0 on success, 1 if not found
# -----------------------------------------------------------------------------
server_show() {
    local name="${1:?server name required}"
    local profile
    profile="$(_server_profile_path "${name}")"

    if [[ ! -f "${profile}" ]]; then
        printf 'ERROR: server profile not found: %s\n' "${name}" >&2
        return 1
    fi

    printf '=== Server: %s ===\n' "${name}"
    local keys=("HOST" "USER" "PORT" "SSH_KEY" "REMOTE_LOG_PATH")
    for key in "${keys[@]}"; do
        local val
        val="$(read_conf_value "${profile}" "${key}" || printf '<not set>')"
        printf '  %-20s %s\n' "${key}" "${val}"
    done
    return 0
}

# -----------------------------------------------------------------------------
# server_update
# updates a single key in an existing server profile
# Args: $1=server_name $2=key $3=value
# returns: 0 on success, 1 if not found
# -----------------------------------------------------------------------------
server_update() {
    local name="${1:?server name required}"
    local key="${2:?key required}"
    local value="${3:?value required}"
    local profile
    profile="$(_server_profile_path "${name}")"

    if [[ ! -f "${profile}" ]]; then
        printf 'ERROR: server profile not found: %s\n' "${name}" >&2
        return 1
    fi

    write_key_value "${profile}" "${key}" "${value}"
    printf 'Updated %s.%s = %s\n' "${name}" "${key}" "${value}"
    return 0
}

# -----------------------------------------------------------------------------
# server_load
# loads a server profile into local variables for use by mod_ssh.sh
# Args: $1=server_name
# exports: SERVER_HOST SERVER_USER SERVER_PORT SERVER_SSH_KEY SERVER_REMOTE_LOG_PATH
# returns: 0 on success, exits with ERR_CONFIG_PARSE_ERROR on missing keys
# -----------------------------------------------------------------------------
server_load() {
    local name="${1:?server name required}"
    local profile
    profile="$(_server_profile_path "${name}")"

    if [[ ! -f "${profile}" ]]; then
        printf 'ERROR: server profile not found: %s\n' "${name}" >&2
        exit "${ERR_CONFIG_PARSE_ERROR}"
    fi

    SERVER_HOST="$(read_conf_value "${profile}" "HOST")" || {
        printf 'ERROR: HOST missing in profile: %s\n' "${name}" >&2
        exit "${ERR_CONFIG_PARSE_ERROR}"
    }

    SERVER_USER="$(read_conf_value "${profile}" "USER")" || {
        printf 'ERROR: USER missing in profile: %s\n' "${name}" >&2
        exit "${ERR_CONFIG_PARSE_ERROR}"
    }

    SERVER_PORT="$(read_conf_value "${profile}" "PORT" || printf '22')"

    SERVER_SSH_KEY="$(read_conf_value "${profile}" "SSH_KEY" \
        || printf '%s/.ssh/id_rsa' "${HOME}")"

    SERVER_REMOTE_LOG_PATH="$(read_conf_value "${profile}" "REMOTE_LOG_PATH" \
        || printf '%s' "${DEPLOYCTL_HISTORY_LOG}")"

    export SERVER_HOST SERVER_USER SERVER_PORT SERVER_SSH_KEY SERVER_REMOTE_LOG_PATH
    return 0
}