#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: MEDINOU Soukaina <soukainamedinou22@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_parse.sh — Parse cached deployctl .conf files and classify by STATUS.

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

# -----------------------------------------------------------------------------
# inboxctl_parse_project_conf_file
# Loads known keys from a project conf into env-style names with PREFIX.
# Args: $1=path to conf
# Sets: exported PARSE_* variables (best-effort)
# Returns: 0
# Study: https://mywiki.wooledge.org/BashFAQ/105 (set -e and command substitution)
# -----------------------------------------------------------------------------
inboxctl_parse_project_conf_file() {
    local f="$1"
    # Use "|| true" so missing keys do not trip `set -e` inside $(...) substitution.
    PARSE_APP_NAME="$(read_conf_value "$f" APP_NAME || true)"
    PARSE_STATUS="$(read_conf_value "$f" STATUS || true)"
    PARSE_PORT="$(read_conf_value "$f" PORT || true)"
    PARSE_DOMAIN="$(read_conf_value "$f" DOMAIN || true)"
    PARSE_CONTAINER="$(read_conf_value "$f" CONTAINER_NAME || true)"
    PARSE_LAST_DEPLOY="$(read_conf_value "$f" LAST_DEPLOY || true)"
    PARSE_REPO="$(read_conf_value "$f" REPO_URL || true)"
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_collect_projects_from_cache
# Iterates projects.d conf files for a server cache root.
# Args: $1=server cache root directory
# Each project printed as one line: tab-separated fields for UI layer.
# Returns: 0
# Study: TSV rows with printf and tab
# -----------------------------------------------------------------------------
inboxctl_collect_projects_from_cache() {
    local root="${1}/projects.d"
    shopt -s nullglob
    local f
    for f in "${root}"/*.conf; do
        inboxctl_parse_project_conf_file "$f"
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
            "${PARSE_APP_NAME}" "${PARSE_STATUS}" "${PARSE_PORT}" "${PARSE_DOMAIN}" \
            "${PARSE_CONTAINER}" "${PARSE_LAST_DEPLOY}"
    done
    shopt -u nullglob
    return 0
}