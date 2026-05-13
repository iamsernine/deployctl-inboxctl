#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_env.sh — Build /var/lib/deployctl/env/<app>.env from .env.example or prompts.

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

# -----------------------------------------------------------------------------
# deployctl_collect_env_from_example
# Reads .env.example lines KEY= and prompts for values; writes env file (chmod 600).
# Args: $1=app name, $2=repo root directory
# Returns: 0 on success
# Study: https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html#index-read
# -----------------------------------------------------------------------------
deployctl_collect_env_from_example() {
    local app="$1"
    local repo="$2"
    local example="${repo}/.env.example"
    local env_file="${DEPLOYCTL_ENV_DIR}/${app}.env"

    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_project_info "$app" "[dry-run] would create env from ${example}"
        return 0
    fi

    if [[ ! -f "$example" ]]; then
        return 1
    fi

    mkdir -p "$DEPLOYCTL_ENV_DIR"
    : >"$env_file"
    local line key val default
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        if [[ "$line" == *"="* ]]; then
            key="${line%%=*}"
            key="${key%% }"
            default="${line#*=}"
            printf 'Enter value for %s [%s]: ' "$key" "$default" >&2
            read -r val || val="$default"
            [[ -z "$val" ]] && val="$default"
            printf '%s=%s\n' "$key" "$val" >>"$env_file"
        fi
    done <"$example"

    chmod 600 "$env_file" || {
        log_project_error "$app" "chmod env file failed"
        return 1
    }
    log_project_info "$app" "wrote env file ${env_file}"
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_collect_env_interactive_full
# When no .env.example: allows paste or path to env file.
# Args: $1=app name
# Returns: 0
# Study: https://www.gnu.org/software/bash/manual/html_node/Looping-Constructs.html (while read)
# -----------------------------------------------------------------------------
deployctl_collect_env_interactive_full() {
    local app="$1"
    local env_file="${DEPLOYCTL_ENV_DIR}/${app}.env"

    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_project_info "$app" "[dry-run] would prompt for full env"
        return 0
    fi

    mkdir -p "$DEPLOYCTL_ENV_DIR"
    printf 'No .env.example. Paste path to env file (or leave empty to type line by line, end with blank line after last):\n' >&2
    read -r env_path || true
    if [[ -n "$env_path" ]] && [[ -f "$env_path" ]]; then
        cp "$env_path" "$env_file"
    else
        printf 'Enter KEY=value lines. Empty line finishes:\n' >&2
        : >"$env_file"
        while IFS= read -r line; do
            [[ -z "$line" ]] && break
            printf '%s\n' "$line" >>"$env_file"
        done
    fi
    chmod 600 "$env_file"
    log_project_info "$app" "wrote env file ${env_file} (manual)"
    return 0
}
