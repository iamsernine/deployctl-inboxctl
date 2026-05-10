#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: MEDINOU Soukaina <soukainamedinou22@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_parse.sh - project cache parsing layer
# reads project configuration files stored in $INBOXCTL_SERVER_CACHE_DIR
# parses .conf files and outputs normalized project data for UI consumption
#
# requires: shared/constants.sh shared/format.sh shared/validators.sh
# shellcheck shell=bash

# =============================================================================
# Public API
# =============================================================================

# -----------------------------------------------------------------------------
# inboxctl_parse_project_conf_file
# parses a single project configuration file (.conf)
# extracts APP_NAME, DOMAIN, PORT, STATUS
#
# Args: $1=file path
# Returns: 0 on success, 1 on validation or parsing error
# Output: prints "name|domain|port|status" to stdout
# -----------------------------------------------------------------------------
inboxctl_parse_project_conf_file() {
    local file="$1"

    # -------------------------
    # validate file existence
    # -------------------------
    validate_file_exists "$file" || return 1

    local name domain port status

    # -------------------------
    # read configuration values
    # -------------------------
    name="$(read_conf_value "$file" "APP_NAME")"
    domain="$(read_conf_value "$file" "DOMAIN")"
    port="$(read_conf_value "$file" "PORT")"
    status="$(read_conf_value "$file" "STATUS")"

    # fallback compatibility (legacy key)
    [[ -z "$name" ]] && name="$(read_conf_value "$file" "PROJECT_NAME")"

    # -------------------------
    # validate extracted values
    # -------------------------
    validate_app_name "$name" || return 1
    validate_domain "$domain" || return 1
    validate_port "$port" || return 1
    validate_status "$status" || return 1

    # -------------------------
    # output normalized format
    # -------------------------
    printf '%s|%s|%s|%s\n' "$name" "$domain" "$port" "$status"
}

# -----------------------------------------------------------------------------
# inboxctl_collect_projects_from_cache
# scans all project configuration files for a given server
# collects and parses project data from cache directory
#
# Args: $1=server_name
# Returns: 0 if at least one project found, 1 otherwise
# Output: stream of "name|domain|port|status"
# -----------------------------------------------------------------------------

inboxctl_parse_project_conf_file() {
    local file="$1"

    [[ -f "$file" ]] || return 1

    local name domain port status

    name=$(read_conf_value "$file" "PROJECT_NAME") || name="UNKNOWN"
    domain=$(read_conf_value "$file" "DOMAIN") || domain="UNKNOWN"
    port=$(read_conf_value "$file" "PORT") || port="0"
    status=$(read_conf_value "$file" "STATUS") || status="$STATUS_ERROR"

    validate_app_name "$name" || name="INVALID"
    validate_domain "$domain" || domain="INVALID"
    validate_port "$port" || port="0"
    validate_status "$status" || status="$STATUS_ERROR"

    printf '%s|%s|%s|%s\n' "$name" "$domain" "$port" "$status"
}

inboxctl_collect_projects_from_cache() {
    local dir="$1"
    local projects_dir="${dir}/projects"

    [[ -d "$projects_dir" ]] || return 1

    shopt -s nullglob
    local files=("$projects_dir"/*.conf)

    [[ ${#files[@]} -eq 0 ]] && return 1

    for file in "${files[@]}"; do
        inboxctl_parse_project_conf_file "$file"
    done
}
