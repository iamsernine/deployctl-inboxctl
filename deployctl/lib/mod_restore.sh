#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_restore.sh — Re-deploy from archived metadata using stored env.

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

DEPLOYCTL_RESTORE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------------------------------------------------------
# deployctl_restore_app
# Reads conf, reclones into pending, builds and promotes to live like deploy.
# Args: $1=app name
# Returns: 0 on success
# Study: compose small steps; cleanup_on_error on failure paths
# -----------------------------------------------------------------------------
deployctl_restore_app() {
    local app="$1"
    local conf="${DEPLOYCTL_PROJECTS_DIR}/${app}.conf"
    local envf="${DEPLOYCTL_ENV_DIR}/${app}.env"

    if [[ ! -f "$conf" ]]; then
        log_error "missing ${conf}"
        return 1
    fi
    if [[ ! -f "$envf" ]]; then
        log_error "missing env file ${envf}"
        exit_with_error "$ERR_FILE_PERMISSION_ERROR" "env file required for restore"
    fi

    local repo domain port dockerfile ssl
    repo="$(read_conf_value "$conf" REPO_URL)" || {
        exit_with_error "$ERR_CONFIG_PARSE_ERROR" "REPO_URL missing"
    }
    domain="$(read_conf_value "$conf" DOMAIN)" || domain="localhost"
    port="$(read_conf_value "$conf" PORT)" || port="8080"
    dockerfile="$(read_conf_value "$conf" DOCKERFILE_PATH)" || dockerfile="Dockerfile"
    ssl="$(read_conf_value "$conf" SSL_ENABLED)" || ssl="no"

    DEPLOYCTL_ROLLBACK_APP="$app"
    local pending="${DEPLOYCTL_PENDING_DIR}/${app}"
    DEPLOYCTL_ROLLBACK_PENDING_DIR="$pending"
    local container="${CONTAINER_PREFIX}${app}"
    DEPLOYCTL_ROLLBACK_CONTAINER="$container"

    deployctl_git_clone_repo "$repo" "$pending" || exit_with_error "$ERR_GIT_CLONE_FAILED" "clone failed"

    local dfpath="${pending}/${dockerfile}"
    [[ -f "$dfpath" ]] || dfpath="${pending}/Dockerfile"
    validate_file_exists "$dfpath" || exit_with_error "$ERR_DOCKERFILE_MISSING" "Dockerfile not found"

    deployctl_docker_build "$app" "$pending" "$dockerfile" || {
        cleanup_on_error
        exit_with_error "$ERR_DOCKER_BUILD_FAILED" "build failed"
    }

    deployctl_docker_run_app "$app" "$port" "$port" || {
        cleanup_on_error
        exit_with_error "$ERR_CONTAINER_RUN_FAILED" "run failed"
    }

    deployctl_health_check_app "$app" "$port" || {
        cleanup_on_error
        exit_with_error "$ERR_HEALTH_CHECK_FAILED" "health failed"
    }

    deployctl_nginx_render_config "$app" "$domain" "$port" || {
        cleanup_on_error
        exit_with_error "$ERR_NGINX_CONFIG_FAILED" "nginx render failed"
    }

    deployctl_nginx_test_and_reload "$app" || {
        cleanup_on_error
        exit_with_error "$ERR_NGINX_CONFIG_FAILED" "nginx test failed"
    }

    if [[ "$ssl" == "yes" ]] || [[ "$ssl" == "true" ]]; then
        deployctl_run_certbot_optional "$domain" "$app" || log_project_error "$app" "certbot step failed (non-fatal for restore)"
    fi

    [[ -d "${DEPLOYCTL_LIVE_DIR}/${app}" ]] && rm -rf "${DEPLOYCTL_LIVE_DIR}/${app}"
    mkdir -p "$DEPLOYCTL_LIVE_DIR"
    mv "$pending" "${DEPLOYCTL_LIVE_DIR}/${app}"

    write_key_value "$conf" "STATUS" "$STATUS_LIVE"
    write_key_value "$conf" "LAST_DEPLOY" "$(current_timestamp)"
    printf '%s\n' "LAST_DEPLOY=$(current_timestamp)" >"${DEPLOYCTL_STATE_DIR}/${app}.state"

    DEPLOYCTL_ROLLBACK_CONTAINER=""
    DEPLOYCTL_ROLLBACK_PENDING_DIR=""
    DEPLOYCTL_ROLLBACK_APP=""
    log_project_info "$app" "restore complete; STATUS=${STATUS_LIVE}"
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_run_certbot_optional
# Attempts certbot when present; logs SSL_FAILED-level message but returns 1 only if strict needed.
# Args: $1=domain, $2=app
# Returns: 0 if skipped or success, 1 if certbot missing or failed (caller decides)
# Study: https://eff-certbot.readthedocs.io/
# -----------------------------------------------------------------------------
deployctl_run_certbot_optional() {
    local domain="$1"
    local app="$2"
    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_project_info "$app" "[dry-run] certbot would run for ${domain}"
        return 0
    fi
    if ! command -v certbot >/dev/null 2>&1; then
        log_project_error "$app" "certbot not installed; skipping SSL"
        return 1
    fi
    certbot --nginx -d "$domain" --non-interactive --agree-tos --register-unsafely-without-email 2>/dev/null || {
        log_project_error "$app" "certbot failed for ${domain}"
        return 1
    }
    log_project_info "$app" "certbot completed for ${domain}"
    return 0
}