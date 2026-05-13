#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# shared/format.sh — Timestamps, log line formatting, simple conf IO, and path helpers.
# Used by deployctl logging and inboxctl display/parsing utilities.
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/

# shellcheck shell=bash

# Requires: constants.sh sourced first for consistent defaults.

# -----------------------------------------------------------------------------
# current_timestamp
# Returns RFC-style timestamp for logs: yyyy-mm-dd-hh-mm-ss
# Returns: 0 always; prints timestamp to stdout
# Study: https://www.gnu.org/software/bash/manual/html_node/Date-and-time-summaries.html (date formats)
# -----------------------------------------------------------------------------
current_timestamp() {
    date +"%Y-%m-%d-%H-%M-%S"
}

# -----------------------------------------------------------------------------
# format_log_entry
# Formats a single log line per deployctl contract.
# Args: $1=type (INFOS|ERROR), $2=message
# Returns: 0; prints one line to stdout
# Study: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html (${var:-default})
# -----------------------------------------------------------------------------
format_log_entry() {
    local log_type="${1:-INFOS}"
    local message="${2:-}"
    local ts user_name
    ts="$(current_timestamp)"
    user_name="$(whoami 2>/dev/null || printf '%s' "${USER:-unknown}")"
    printf '%s : %s : %s : %s\n' "$ts" "$user_name" "$log_type" "$message"
}

# -----------------------------------------------------------------------------
# print_table_line
# Prints columns separated by two spaces for simple terminal tables.
# Args: arbitrary column strings
# Returns: 0
# Study: https://www.gnu.org/software/bash/manual/html_node/Special-Parameters.html (#index-_0024_0040)
# -----------------------------------------------------------------------------
print_table_line() {
    local out=""
    local first=1
    for col in "$@"; do
        if [[ $first -eq 1 ]]; then
            out="$col"
            first=0
        else
            out+="  $col"
        fi
    done
    printf '%s\n' "$out"
}

# -----------------------------------------------------------------------------
# read_conf_value
# Reads KEY=value from a simple conf file (first match wins).
# Args: $1=file path, $2=key
# Returns: 0 if found (value on stdout), 1 if missing
# Study: https://mywiki.wooledge.org/BashFAQ/001 (read line by line); https://www.gnu.org/software/bash/manual/html_node/Pattern-Matching.html
# -----------------------------------------------------------------------------
read_conf_value() {
    local file="$1"
    local key="$2"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    local line val
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        if [[ "$line" == "$key="* ]]; then
            val="${line#*=}"
            val="${val//$'\r'/}"
            printf '%s' "$val"
            return 0
        fi
    done <"$file"
    return 1
}

# -----------------------------------------------------------------------------
# write_key_value
# Writes or updates KEY=value in a simple conf file (preserves other lines).
# Args: $1=file, $2=key, $3=value
# Returns: 0 on success
# Study: https://www.gnu.org/software/bash/manual/html_node/Redirections.html (while read <in >out); mktemp(1)
# -----------------------------------------------------------------------------
write_key_value() {
    local file="$1"
    local key="$2"
    local value="$3"
    local tmp
    tmp="$(mktemp)"
    local found=0
    if [[ -f "$file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == "$key="* ]]; then
                printf '%s=%s\n' "$key" "$value"
                found=1
            else
                printf '%s\n' "$line"
            fi
        done <"$file" >"$tmp"
    fi
    if [[ $found -eq 0 ]]; then
        printf '%s=%s\n' "$key" "$value" >>"$tmp"
    fi
    mv "$tmp" "$file"
    return 0
}

# -----------------------------------------------------------------------------
# escape_sed_replacement
# Escapes a string for safe use as sed replacement (basic chars).
# Args: $1=raw string
# Returns: 0; escaped string on stdout
# Study: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html (// pattern replacement)
# -----------------------------------------------------------------------------
escape_sed_replacement() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//&/\\&}"
    printf '%s' "$s"
}

# -----------------------------------------------------------------------------
# normalize_path
# Collapses redundant slashes and resolves . / .. where possible.
# Args: $1=path
# Returns: 0; normalized path on stdout
# Study: https://www.gnu.org/software/bash/manual/html_node/Command-Substitution.html; realpath(1)
# -----------------------------------------------------------------------------
normalize_path() {
    local p="${1:-}"
    if command -v realpath >/dev/null 2>&1; then
        realpath -m "$p" 2>/dev/null || printf '%s' "$p"
    else
        # Minimal fallback: strip duplicate slashes
        echo "$p" | sed 's|/\{2,\}|/|g'
    fi
}
