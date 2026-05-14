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

    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_project_info "$app" "[dry-run] archive: would stop ${container}"
        log_project_info "$app" "[dry-run] archive: would move ${live_dir} -> ${arch_dir}/src"
        log_project_info "$app" "[dry-run] archive: would remove nginx config and set STATUS=${STATUS_ARCHIVE}"
        return 0
    fi

    if [[ ! -f "$conf" ]]; then
        log_error "no project conf for ${app}"
        return 1
    fi

    local repo domain port status
    repo="$(read_conf_value "$conf" REPO_URL)" || repo=""
    domain="$(read_conf_value "$conf" DOMAIN)" || domain=""
    port="$(read_conf_value "$conf" PORT)" || port=""
    status="$(read_conf_value "$conf" STATUS)" || status=""

    if [[ "$status" != "$STATUS_LIVE" ]]; then
        log_project_error "$app" "archive refused: STATUS=${status:-unknown}, expected ${STATUS_LIVE}"
        return 1
    fi

    if [[ ! -d "$live_dir" ]]; then
        log_project_error "$app" "archive refused: live directory missing (${live_dir})"
        return 1
    fi

    deployctl_docker_stop_remove "$container" || true

    local remove_image=0
    local ans="n"
    if [[ -r /dev/tty && -w /dev/tty ]]; then
        printf 'Remove Docker image %s%s:latest? [y/N] ' "${IMAGE_PREFIX}" "$app" >/dev/tty
        read -r ans </dev/tty || ans="n"
    elif [[ -t 0 ]]; then
        printf 'Remove Docker image %s%s:latest? [y/N] ' "${IMAGE_PREFIX}" "$app" >&2
        read -r ans || ans="n"
    else
        log_project_info "$app" "non-interactive archive: keeping Docker image"
    fi
    [[ "$ans" =~ ^[Yy]$ ]] && remove_image=1

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

    deployctl_nginx_remove_config "$app"

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

    local tarball="${DEPLOYCTL_ARCHIVE_DIR}/${app}-$(current_timestamp).tar.gz"
    if command -v tar >/dev/null 2>&1; then
        if tar -czf "$tarball" -C "$DEPLOYCTL_ARCHIVE_DIR" "$app" 2>/dev/null; then
            log_info "Archive compressee creee: ${tarball}"
            log_project_info "$app" "Archive compressee: ${tarball}"
        else
            log_error "Echec de la compression de l'archive"
        fi
    fi

    write_key_value "$conf" "STATUS" "$STATUS_ARCHIVE"
    write_key_value "$conf" "LAST_DEPLOY" "$(current_timestamp)"
    log_project_info "$app" "archived; STATUS=${STATUS_ARCHIVE}"
    return 0
}
