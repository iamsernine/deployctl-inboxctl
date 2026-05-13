#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: MEDINOU Soukaina <soukainamedinou22@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_ui.sh — Simple fixed-width terminal tables for project listings.

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

# -----------------------------------------------------------------------------
# inboxctl_ui_print_projects_header
# Prints column headers per README example.
# Returns: 0
# Study: print_table_line helper from shared/format.sh
# -----------------------------------------------------------------------------
inboxctl_ui_print_projects_header() {
    print_table_line "PROJECT" "STATUS" "PORT" "DOMAIN" "CONTAINER" "LAST_DEPLOY"
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_ui_print_projects_table
# Args: $1=server cache root
# Returns: 0
# Study: https://www.gnu.org/software/bash/manual/html_node/Process-Substitution.html
# -----------------------------------------------------------------------------
inboxctl_ui_print_projects_table() {
    local cache="$1"
    inboxctl_ui_print_projects_header
    local line
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        IFS=$'\t' read -r app st port dom cont last <<<"$line"
        print_table_line "${app}" "${st}" "${port}" "${dom}" "${cont}" "${last}"
    done < <(inboxctl_collect_projects_from_cache "$cache")
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_ui_filter_status
# Args: $1=cache root, $2=status (live|pending|archive)
# Returns: 0
# Study: process substitution + filter rows
# -----------------------------------------------------------------------------
inboxctl_ui_filter_status() {
    local cache="$1"
    local want="$2"
    inboxctl_ui_print_projects_header
    local line
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        IFS=$'\t' read -r app st port dom cont last <<<"$line"
        [[ "$st" == "$want" ]] || continue
        print_table_line "${app}" "${st}" "${port}" "${dom}" "${cont}" "${last}"
    done < <(inboxctl_collect_projects_from_cache "$cache")
    return 0
}
