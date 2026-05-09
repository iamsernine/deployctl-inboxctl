#!/usr/bin/env bash 
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: deployctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: BEN YAMNA Mohammed <iamsernine@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# deployctl/deployctl.sh - server-side CLI entrypoint for docker monolith deployements.
# sources shared contracts and modular libraries; dispatches subcommands


# =============================================================================
# strict mode : exit on failed command (set -e  ), undefined var are errors (set -u  )
# pipelines propagate failure (set -o pipefail) 
# use set -x for debugging purpose 
# find more in http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail 

# Absolute path to this script's directory (deployctl CLI location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Root directory of the deployctl repository (one level up from script)
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Path to shared modules (can be overridden via DEPLOY_SHARED_ROOT)
SHARED="${DEPLOY_SHARED_ROOT:-${REPO_ROOT}/shared}"

# fallback if repo layout differs : ${VAR:-default} above, then re-point SHARED 
if [[ ! -f "${SHARED}/constants.sh" ]]; then 
    SHARED="${SCRIPT_DIR}/../shared"
fi 

# =============================================================================
# shared + inbox modules (sourced into this shell)
# =============================================================================

# shellcheck source=/dev/null 
source "${SHARED}/constants.sh"
# shellcheck source=/dev/null 
source "${SHARED}/format.sh"
# shellcheck source=/dev/null 
source "${SHARED}/validators.sh"

# =============================================================================
# Feature modules: one file per concern (docker, nginx, …). Loop + source keeps
# this entrypoint small; order can matter if modules depend on earlier ones.
# =============================================================================
DEPLOYCTL_LIB="${SCRIPT_DIR}/lib"
for _mod in mod_log.sh mod_error.sh mod_cli.sh mod_check.sh mod_env.sh mod_git.sh mod_docker.sh mod_health.sh mod_nginx.sh mod_archive.sh mod_restore.sh mod_menu.sh; do 
    # shellcheck source=/dev/null
    source "${DEPLOYCTL_LIB}/${_mod}"
done 

# -----------------------------------------------------------------------------
# deployctl_write_project_conf
# writes /etc/deployctl/projects.d/<app>.conf from current deployement context 
# args: key deployement fields via positional or env-style -uses explicit args below 
# returns: 0
# -----------------------------------------------------------------------------
deployctl_write_project_conf(){
    local app="$1"
    local repo="$2"
    local domain="$3"
    local port="$4"
    local dockerfile="$5"
    local ssl_en="$6"
    local status="$7"
    local env_file="${DEPLOYCTL_ENV_DIR}/${app}.env"
    local app_dir="${DEPLOYCTL_LIVE_DIR}/${app}"
    local container="${CONTAINER_PREFIX}${app}"
    local image="${IMAGE_PREFIX}${app}:latest"
    local now
    now="$(current_timestamp)"

    local out="${DEPLOYCTL_PROJECTS_DIR}/${app}.conf"
    mkdir -p "$DEPLOYCTL_PROJECTS_DIR" 
    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_project_info "$app" "[dry-run] would write project conf ${out}"
        return 0
    fi
    local prev_created=""
    if [[ -f "$out" ]]; then
        prev_created="$(read_conf_value "$out" CREATED_AT)" || prev_created=""
    fi
    {
        printf '%s\n' "# deployctl project metadata"
        printf 'APP_NAME=%s\n' "$app"
        printf 'REPO_URL=%s\n' "$repo"
        printf 'DOMAIN=%s\n' "$domain"
        printf 'PORT=%s\n' "$port"
        printf 'DOCKERFILE_PATH=%s\n' "$dockerfile"
        printf 'ENV_FILE=%s\n' "$env_file"
        printf 'APP_DIR=%s\n' "$app_dir"
        printf 'STATUS=%s\n' "$status"
        printf 'SSL_ENABLED=%s\n' "$ssl_en"
        printf 'CONTAINER_NAME=%s\n' "$container"
        printf 'IMAGE_NAME=%s\n' "$image"
        printf 'CREATED_AT=%s\n' "${prev_created:-$now}"
        printf 'LAST_DEPLOY=%s\n' "$now"
    } >"$out"
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_parse_deploy_argv 
# Parses deploy subcommand arguments into globals (read the constants :) from cmd ) .
# Sets: DEPLOY_ARG_APP, DEPLOY_ARG_REPO, DEPLOY_ARG_DOMAIN, DEPLOY_ARG_PORT, DEPLOY_ARG_SSL
# Returns: 0
# -----------------------------------------------------------------------------

deployctl_parse_deploy_argv(){
    DEPLOYCTL_ARG_APP=""
    DEPLOYCTL_ARG_REPO=""
    DEPLOYCTL_ARG_DOMAIN=""
    DEPLOYCTL_ARG_PORT=""
    DEPLOYCTL_ARG_SSL="no"

    while [[ $# -gt 0]]; do
        case "$1" in 
            --repo)
                DEPLOYCTL_ARG_REPO="$2"
                shift 2 
                ;;
            --domain) 
                DEPLOYCTL_ARG_DOMAIN="$2"
                shift 2
                ;;
            --port)
                DEPLOYCTL_ARG_PORT="$2"
                shift 2
                ;;
            --ssl)
                DEPLOYCTL_ARG_SSL="$2"
                shift 2
                ;;
            *)
                if [[ -z "$DEPLOYCTL_ARG_APP" ]]; then 
                    DEPLOYCTL_ARG_APP="$1"
                    shift
                else
                    exit_with_error "$ERR_UNKNOWN_OPTION" "unexpected deploy argument: $1"
                fi
                ;;
        esac
    done
    return 0 
}

# -----------------------------------------------------------------------------
# deployctl_cmd_check
# Verifies dependencies and directory layout.
# Returns: 0 on success
# -----------------------------------------------------------------------------

deployctl_cmd_check(){
    init_logs 
    log_info "deployctl check starting "
    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then 
        log_info "[dry-run] dependency checks skipped (docker/git/nginx/curl/ss)"
        deployctl_ensure_layout || true
        log_info "deployctl check OK (dry-run)" 
        return 0 
    fi 
    if ! deployctl_check_dependencies; then 
        exit_with_error "$ERR_DEPENDENCY_MISSING" "dependency check failed "  # TODO: add mod for installation the missing packages 
    fi 
    if [[ "${DEPLOYCTL_DRY_RUN:-0}" != "1" ]] && ! require_root; then 
        log_error "check: not root - some paths may be inaccessible" 
    fi 
    deployctl_ensure_layout || exit_with_error "$ERR_FILE_PERMISSION_ERROR" "layout failed" 
    log_info "deployctl check OK"
    return 0 
}

