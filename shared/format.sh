#!/usr/bin/env bash 
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl 
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: BEN YAMNA Mohammed <iamsernine@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# shared/format.sh - timestamps ,log line formatting , simple conf IO , and path helpers 
# used by deployctl logging and inboxctl display/parsing utilities 

# shellcheck shell=bash 
# read https://www.shellcheck.net/wiki/ about shellcheck

# requires: constants.sh 

# -----------------------------------------------------------------------------
# current_timestamp 
# returns RFC-style timestamp for logs : yyyy-mm-dd-hh-mm-statuses
# returns: 0 always; prints timestamp to stdout
# -----------------------------------------------------------------------------
current_timestamp(){
    date +"%Y-%m-%d-%H-%M-%S"
}

# -----------------------------------------------------------------------------
# format_log_entry 
# formats a single log line per deployctl contract 
# Args: $1=type (INFOS|ERROR), $2=message
# returns: 0; prints one line to stdout 
# -----------------------------------------------------------------------------
format_log_entry(){
    local log_type="${1:-INFOS}"
    local message="${2:-}"
    local ts user_name
    ts="$(current_timestamp)"
    user_name="${USER:-unknown}"
    printf '%s : %s : %s : %s \n' "$ts" "$user_name" "$log_type" "$message"
}

# -----------------------------------------------------------------------------
# print_table_line 
# prints columns seeparated by two spaces for simple terminal tables 
# args : arbitrary column strings 
# returns: 0 
# -----------------------------------------------------------------------------
print_table_line(){
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
# reads KEY=value from a simple conf file (first match wiins )
# args: $1=file path , $2=key 
# returns: 0 if found (value on stdout) , 1 if missing 
# -----------------------------------------------------------------------------
read_conf_value(){
    local file="$1"
    local key="$2"
    if [[ ! -f "$file" ]]; then 
        return 1 
    fi 
    local line val
    while IFS= read -r line || [[ -n "$line" ]]; do # IFS ensure that bash do not split the line or trim it
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
# writes or updates KEY=value in a simple conf file (preserves other lines )
# Args: $1=file, $2=key, $3=value
# returns: 0 on success
# -----------------------------------------------------------------------------
write_key_value(){
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
        done <"$file">"$tmp"
    fi 
    if [[ $found -eq 0 ]]; then
        printf '%s=%s\n' "$key" "$value" >>"$tmp"
    fi
    mv "$tmp" "$file"
    return 0
}

# -----------------------------------------------------------------------------
# escape_sed_replacement 
# Escapes a string for safe use as sed replacement (basic chars )
# Args: $1=raw string 
# returns: 0; escaped string on stdout 
# -----------------------------------------------------------------------------
escape_sed_replacement(){
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//&/\\&}"
    printf '%s' "$s"
}


# -----------------------------------------------------------------------------
# normalize_path 
# collapses redundant slashes and resolves . / .. where possible 
# Args: $1=path
# returns: 0; normalized path on stdout 
# -----------------------------------------------------------------------------
normalize_path(){
    local p="${1:-}"
    if command -v realpath >/dev/null 2>&1; then
        realpath -m "$p" 2>/dev/null || printf '%s' "$p"
    else
        # Minimal fallback: strip duplicate slashes
        echo "$p" | sed 's|/\{2,\}|/|g'
    fi
}


# -----------------------------------------------------------------------------
# find_free_port 
# finds an available port in the range 3000-4000
# returns: 0 if port found (port number on stdout), 1 if none available
# -----------------------------------------------------------------------------
find_free_port() {
    local start_port=3000
    local end_port=4000

    for port in $(seq $start_port $end_port); do
        if ! ss -tuln | grep -Eq ":$port\b"; then
            echo "$port"
            return 0
        fi
    done
    return 1
}