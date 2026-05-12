#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_archive.sh — Stop container, archive app dir, preserve conf/env.

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

DEPLOYCTL_ARCHIVE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------------------------------------------------------
# deployctl_archive_app
# Moves live tree to archive, writes restore.txt, updates STATUS in project conf.
# Args: $1=app name
# Returns: 0 on success
# Study: https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html ([[ =~ ]])
# -----------------------------------------------------------------------------
deployctl_archive_app() {
    local app="$1"
    local live_dir="${DEPLOYCTL_LIVE_DIR}/${app}"
    local arch_dir="${DEPLOYCTL_ARCHIVE_DIR}/${app}"
    local conf="${DEPLOYCTL_PROJECTS_DIR}/${app}.conf"
    local container="${CONTAINER_PREFIX}${app}"

    if [[ ! -f "$conf" ]]; then
        log_error "no project conf for ${app}"
        return 1
    fi

    local repo domain port
    repo="$(read_conf_value "$conf" REPO_URL)" || repo=""
    domain="$(read_conf_value "$conf" DOMAIN)" || domain=""
    port="$(read_conf_value "$conf" PORT)" || port=""

    deployctl_docker_stop_remove "$container" || true

    local remove_image=0
    printf 'Remove Docker image %s%s:latest? [y/N] ' "${IMAGE_PREFIX}" "$app" >&2
    local ans
    read -r ans || ans="n"
    [[ "$ans" =~ ^[Yy]$ ]] && remove_image=1

    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_project_info "$app" "[dry-run] archive: move ${live_dir} -> ${arch_dir}"
        return 0
    fi

    if [[ $remove_image -eq 1 ]]; then
        docker rmi "${IMAGE_PREFIX}${app}:latest" 2>/dev/null || log_project_info "$app" "image remove skipped or failed"
    fi

    mkdir -p "$arch_dir"
    if [[ -d "$live_dir" ]]; then
        rm -rf "${arch_dir}/src" 2>/dev/null || true
        mv "$live_dir" "${arch_dir}/src" || {
            log_project_error "$app" "failed to move live directory to archive"
            return 1
        }
    fi

    local tpl="${DEPLOYCTL_ARCHIVE_LIB_DIR}/templates/restore.txt.tpl"
    if [[ -f "$tpl" ]]; then
        # Safe substitution without sed (URLs may contain slashes).
        APP_NAME="$app" REPO_URL="$repo" DOMAIN="$domain" PORT="$port" envsubst <"$tpl" >"${arch_dir}/restore.txt" 2>/dev/null || \
            true
    fi
    if [[ ! -s "${arch_dir}/restore.txt" ]]; then
        {
            printf 'APP_NAME=%s\n' "$app"
            printf 'REPO_URL=%s\n' "$repo"
            printf 'DOMAIN=%s\n' "$domain"
            printf 'PORT=%s\n' "$port"
        } >"${arch_dir}/restore.txt"
    fi

    write_key_value "$conf" "STATUS" "$STATUS_ARCHIVE"
    write_key_value "$conf" "LAST_DEPLOY" "$(current_timestamp)"
    log_project_info "$app" "archived; STATUS=${STATUS_ARCHIVE}"
    return 0
}