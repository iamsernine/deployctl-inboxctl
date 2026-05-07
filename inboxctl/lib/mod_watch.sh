#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: MEDINOU Soukaina <soukainamedinou22@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_watch.sh - live monitoring mode
# continuously refreshes project display for a given server
#
# This module:
#   - validates server input (validators.sh)
#   - uses shared constants (constants.sh)
#   - displays live projects using UI pipeline (mod_ui.sh)
#
# requires:
#   shared/constants.sh
#   shared/validators.sh
#   shared/format.sh
#   inboxctl_cmd_show_projects (from inboxctl.sh)
#
# shellcheck shell=bash

# =============================================================================
# Public API
# =============================================================================

# -----------------------------------------------------------------------------
# inboxctl_watch_server
# Live monitoring mode for a server
#
# Description:
#   Continuously refreshes the project list every 2 seconds.
#   Uses the existing show-projects pipeline to avoid code duplication.
#
# Args:
#   $1 = server name
#
# Behavior:
#   - validates server name
#   - checks cache directory existence
#   - loops indefinitely and refreshes UI
#
# Returns:
#   0 on success
#   ERR_INVALID_APP_NAME if server name is invalid
#   ERR_MISSING_PARAM if cache directory not found
# -----------------------------------------------------------------------------
inboxctl_watch_server() {
    local server="${1:?server name required}"

    # -------------------------
    # Validate server name
    # -------------------------
    validate_app_name "$server" || {
        format_log_entry "ERROR" "invalid server name: $server"
        return $ERR_INVALID_APP_NAME
    }

    # -------------------------
    # Locate cache directory
    # -------------------------
    local dir="${INBOXCTL_SERVER_CACHE_DIR}/${server}"

    # -------------------------
    # Validate cache existence
    # -------------------------
    validate_dir_exists "$dir" || {
        format_log_entry "ERROR" "server cache not found: $server"
        return $ERR_MISSING_PARAM
    }

    # -------------------------
    # Live monitoring loop
    # -------------------------
    while true; do
        clear

        # Header
        echo "SERVER: $server"
        echo "-------------------"

        # Reuse existing show pipeline
        inboxctl_cmd_show_projects "$server" "" "name"

        # refresh interval
        sleep 2
    done
}
