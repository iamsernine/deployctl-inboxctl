#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: ACHAHROUR Mustapha <mustaphaachahrour@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_cache.sh - local cache management
# initializes and maintains the cache directory structure for each server;
# stores project configs, logs, server metadata and computed status locally;
# provides read/write helpers consumed by mod_fetch.sh and mod_parse.sh
#
# requires: shared/constants.sh shared/format.sh
#           mod_server.sh mod_ssh.sh
# shellcheck shell=bash

# =============================================================================
# Cache directory structure (per server)
#
# ~/.cache/inboxctl/servers/<server-name>/
# ├── logs/
# │   ├── history.log          ← global deployctl log (written by mod_fetch)
# │   └── projects/            ← per-project logs
# │       └── <app>.log
# ├── projects/                ← .conf files fetched from server
# │   └── <app>.conf
# ├── meta.json                ← server info (os, uptime, disk, memory)
# └── status.json              ← computed status (live/pending/error apps count)
#
# =============================================================================

# =============================================================================
# Internal path helpers
# =============================================================================

# -----------------------------------------------------------------------------
# _cache_server_dir
# returns the root cache directory for a server
# Args: $1=server_name
# -----------------------------------------------------------------------------
_cache_server_dir() {
    printf '%s/%s' "${INBOXCTL_SERVER_CACHE_DIR}" "${1:?server name required}"
}

# -----------------------------------------------------------------------------
# _cache_logs_dir
# returns the logs directory for a server
# Args: $1=server_name
# -----------------------------------------------------------------------------
_cache_logs_dir() {
    printf '%s/logs' "$(_cache_server_dir "${1}")"
}

# -----------------------------------------------------------------------------
# _cache_project_logs_dir
# returns the per-project logs directory for a server
# Args: $1=server_name
# -----------------------------------------------------------------------------
_cache_project_logs_dir() {
    printf '%s/logs/projects' "$(_cache_server_dir "${1}")"
}

# -----------------------------------------------------------------------------
# _cache_projects_dir
# returns the projects config directory for a server
# Args: $1=server_name
# -----------------------------------------------------------------------------
_cache_projects_dir() {
    printf '%s/projects' "$(_cache_server_dir "${1}")"
}

# -----------------------------------------------------------------------------
# _cache_meta_path
# returns the path of the meta.json file for a server
# Args: $1=server_name
# -----------------------------------------------------------------------------
_cache_meta_path() {
    printf '%s/meta.json' "$(_cache_server_dir "${1}")"
}

# -----------------------------------------------------------------------------
# _cache_status_path
# returns the path of the status.json file for a server
# Args: $1=server_name
# -----------------------------------------------------------------------------
_cache_status_path() {
    printf '%s/status.json' "$(_cache_server_dir "${1}")"
}

# =============================================================================
# Public API
# =============================================================================

# -----------------------------------------------------------------------------
# cache_init
# creates the full cache directory structure for a server
# safe to call multiple times (idempotent)
# Args: $1=server_name
# returns: 0 on success, exits with ERR_FILE_PERMISSION_ERROR on failure
# -----------------------------------------------------------------------------
cache_init() {
    local server_name="${1:?server name required}"

    local dirs=(
        "$(_cache_logs_dir        "${server_name}")"
        "$(_cache_project_logs_dir "${server_name}")"
        "$(_cache_projects_dir    "${server_name}")"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "${dir}" || {
            printf 'ERROR: cannot create cache directory: %s\n' "${dir}" >&2
            exit "${ERR_FILE_PERMISSION_ERROR}"
        }
        chmod 700 "${dir}"
    done

    printf '[cache] Initialized cache for server: %s\n' "${server_name}"
    printf '[cache] Location: %s\n' "$(_cache_server_dir "${server_name}")"
    return 0
}

# -----------------------------------------------------------------------------
# cache_store_project_conf
# saves a fetched project .conf file into the local projects/ cache
# Args: $1=server_name $2=app_name $3=content (raw conf file text)
# returns: 0 on success
# -----------------------------------------------------------------------------
cache_store_project_conf() {
    local server_name="${1:?server name required}"
    local app_name="${2:?app name required}"
    local content="${3:?content required}"

    local conf_path
    conf_path="$(_cache_projects_dir "${server_name}")/${app_name}.conf"

    printf '%s\n' "${content}" > "${conf_path}"
    chmod 600 "${conf_path}"

    printf '[cache] Stored project config: %s\n' "${app_name}"
    return 0
}

# -----------------------------------------------------------------------------
# cache_store_project_log
# saves a fetched per-project log into logs/projects/
# Args: $1=server_name $2=app_name $3=content (raw log text)
# returns: 0 on success
# -----------------------------------------------------------------------------
cache_store_project_log() {
    local server_name="${1:?server name required}"
    local app_name="${2:?app name required}"
    local content="${3:?content required}"

    local log_path
    log_path="$(_cache_project_logs_dir "${server_name}")/${app_name}.log"

    printf '%s\n' "${content}" > "${log_path}"
    chmod 600 "${log_path}"

    printf '[cache] Stored project log: %s\n' "${app_name}"
    return 0
}

# -----------------------------------------------------------------------------
# cache_write_meta
# writes server metadata to meta.json
# Args: $1=server_name $2=os $3=uptime $4=disk $5=memory
# returns: 0 on success
# meta.json format:
# {
#   "server": "prod",
#   "os": "Ubuntu 22.04",
#   "uptime": "up 3 days",
#   "disk": "40% used",
#   "memory": "2.1G / 4.0G",
#   "updated_at": "2026-05-06-10-30-00"
# }
# -----------------------------------------------------------------------------
cache_write_meta() {
    local server_name="${1:?server name required}"
    local os="${2:-unknown}"
    local uptime="${3:-unknown}"
    local disk="${4:-unknown}"
    local memory="${5:-unknown}"
    local updated_at
    updated_at="$(current_timestamp)"

    local meta_path
    meta_path="$(_cache_meta_path "${server_name}")"

    # write JSON manually — no external dependencies needed
    cat > "${meta_path}" <<EOF
{
  "server":     "${server_name}",
  "os":         "${os}",
  "uptime":     "${uptime}",
  "disk":       "${disk}",
  "memory":     "${memory}",
  "updated_at": "${updated_at}"
}
EOF

    chmod 600 "${meta_path}"
    printf '[cache] Wrote meta.json for server: %s\n' "${server_name}"
    return 0
}

# -----------------------------------------------------------------------------
# cache_read_meta
# reads a single key from meta.json
# Args: $1=server_name $2=key (os|uptime|disk|memory|updated_at)
# returns: 0 if found (value on stdout), 1 if not found
# -----------------------------------------------------------------------------
cache_read_meta() {
    local server_name="${1:?server name required}"
    local key="${2:?key required}"
    local meta_path
    meta_path="$(_cache_meta_path "${server_name}")"

    if [[ ! -f "${meta_path}" ]]; then
        return 1
    fi

    # extract value from JSON with grep + sed (no jq needed)
    local val
    val="$(grep "\"${key}\"" "${meta_path}" \
        | sed 's/.*: *"\(.*\)".*/\1/')" # replace s/OLD/NEW/

    if [[ -z "${val}" ]]; then
        return 1
    fi

    printf '%s' "${val}"
    return 0
}

# -----------------------------------------------------------------------------
# cache_write_status
# writes computed status counts to status.json
# Args: $1=server_name $2=live $3=pending $4=error $5=archived
# returns: 0 on success
# status.json format:
# {
#   "server": "prod",
#   "live": 3,
#   "pending": 1,
#   "error": 0,
#   "archived": 2,
#   "updated_at": "2026-05-06-10-30-00"
# }
# -----------------------------------------------------------------------------
cache_write_status() {
    local server_name="${1:?server name required}"
    local live="${2:-0}"
    local pending="${3:-0}"
    local error="${4:-0}"
    local archived="${5:-0}"
    local updated_at
    updated_at="$(current_timestamp)"

    local status_path
    status_path="$(_cache_status_path "${server_name}")"

    cat > "${status_path}" <<EOF
{
  "server":     "${server_name}",
  "live":       ${live},
  "pending":    ${pending},
  "error":      ${error},
  "archived":   ${archived},
  "updated_at": "${updated_at}"
}
EOF

    chmod 600 "${status_path}"
    printf '[cache] Wrote status.json for server: %s\n' "${server_name}"
    return 0
}

# -----------------------------------------------------------------------------
# cache_read_status
# reads a single key from status.json
# Args: $1=server_name $2=key (live|pending|error|archived|updated_at)
# returns: 0 if found (value on stdout), 1 if not found
# -----------------------------------------------------------------------------
cache_read_status() {
    local server_name="${1:?server name required}"
    local key="${2:?key required}"
    local status_path
    status_path="$(_cache_status_path "${server_name}")"

    if [[ ! -f "${status_path}" ]]; then
        return 1
    fi

    local val
    val="$(grep "\"${key}\"" "${status_path}" \
        | sed 's/.*: *\(.*\)/\1/' \
        | tr -d '", ')"

    if [[ -z "${val}" ]]; then
        return 1
    fi

    printf '%s' "${val}"
    return 0
}

# -----------------------------------------------------------------------------
# cache_list_projects
# lists all cached project names for a server (from projects/ dir)
# Args: $1=server_name
# returns: 0; prints one project name per line
# -----------------------------------------------------------------------------
cache_list_projects() {
    local server_name="${1:?server name required}"
    local projects_dir
    projects_dir="$(_cache_projects_dir "${server_name}")"

    if [[ ! -d "${projects_dir}" ]]; then
        printf '[cache] No projects cached for server: %s\n' "${server_name}"
        return 0
    fi

    local found=0
    for conf in "${projects_dir}"/*.conf; do
        [[ -f "${conf}" ]] || continue
        basename "${conf}" .conf
        found=1
    done

    if [[ ${found} -eq 0 ]]; then
        printf '[cache] No project configs cached yet\n'
    fi

    return 0
}

# -----------------------------------------------------------------------------
# cache_status
# prints a human-readable overview of the cache for a server
# Args: $1=server_name
# returns: 0
# -----------------------------------------------------------------------------
cache_status() {
    local server_name="${1:?server name required}"
    local server_dir
    server_dir="$(_cache_server_dir "${server_name}")"

    printf '=== Cache status: %s ===\n' "${server_name}"

    if [[ ! -d "${server_dir}" ]]; then
        printf '  Cache not initialized.\n'
        printf '  Run: inboxctl fetch %s\n' "${server_name}"
        return 0
    fi

    # history.log
    local history_log
    history_log="$(_cache_logs_dir "${server_name}")/history.log"
    if [[ -f "${history_log}" ]]; then
        local lines
        lines="$(wc -l < "${history_log}")"
        printf '  history.log     : %s lines\n' "${lines}"
    else
        printf '  history.log     : not fetched yet\n'
    fi

    # project configs
    local project_count
    project_count="$(find "$(_cache_projects_dir "${server_name}")" \
        -name '*.conf' 2>/dev/null | wc -l)"
    printf '  project configs : %s\n' "${project_count}"

    # project logs
    local log_count
    log_count="$(find "$(_cache_project_logs_dir "${server_name}")" \
        -name '*.log' 2>/dev/null | wc -l)"
    printf '  project logs    : %s\n' "${log_count}"

    # meta.json
    local meta_path
    meta_path="$(_cache_meta_path "${server_name}")"
    if [[ -f "${meta_path}" ]]; then
        local updated
        updated="$(cache_read_meta "${server_name}" "updated_at" || printf 'unknown')"
        printf '  meta.json       : present (updated: %s)\n' "${updated}"
    else
        printf '  meta.json       : not fetched yet\n'
    fi

    # status.json
    local status_path
    status_path="$(_cache_status_path "${server_name}")"
    if [[ -f "${status_path}" ]]; then
        local live pending error
        live="$(cache_read_status    "${server_name}" "live"    || printf '?')"
        pending="$(cache_read_status "${server_name}" "pending" || printf '?')"
        error="$(cache_read_status   "${server_name}" "error"   || printf '?')"
        printf '  status.json     : live=%s pending=%s error=%s\n' \
            "${live}" "${pending}" "${error}"
    else
        printf '  status.json     : not computed yet\n'
    fi

    return 0
}

# -----------------------------------------------------------------------------
# cache_clear
# removes all cached data for a server (forces full re-fetch next time)
# requires root — destructive operation
# Args: $1=server_name
# returns: 0
# -----------------------------------------------------------------------------
cache_clear() {
    local server_name="${1:?server name required}"

    require_root || {
        printf 'ERROR: cache_clear requires root privileges\n' >&2
        exit "${ERR_NOT_ROOT}"
    }

    local server_dir
    server_dir="$(_cache_server_dir "${server_name}")"

    if [[ ! -d "${server_dir}" ]]; then
        printf '[cache] Nothing to clear for server: %s\n' "${server_name}"
        return 0
    fi

    rm -rf "${server_dir}"
    printf '[cache] Cache cleared for server: %s\n' "${server_name}"
    printf '[cache] Next fetch will be a full fetch.\n'
    return 0
}