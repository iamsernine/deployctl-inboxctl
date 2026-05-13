#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: ACHAHROUR Mustapha <mustaphaachahrour@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_cache.sh — Local cache layout for fetched remote deployctl files.

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

# -----------------------------------------------------------------------------
# inboxctl_cache_root_for_server
# Args: $1=server name
# Prints: cache directory path
# Returns: 0
# Study: predictable cache directory per server alias
# -----------------------------------------------------------------------------
inboxctl_cache_root_for_server() {
    printf '%s/%s' "${INBOXCTL_SERVER_CACHE_DIR}" "$1"
}

# -----------------------------------------------------------------------------
# inboxctl_prepare_cache_dirs
# Args: $1=server name
# Returns: 0
# Study: mkdir -p before scp targets
# -----------------------------------------------------------------------------
inboxctl_prepare_cache_dirs() {
    local name="$1"
    local root
    root="$(inboxctl_cache_root_for_server "$name")"
    mkdir -p "${root}/projects.d" "${root}/logs/projects" "${root}/state"
    return 0
}
