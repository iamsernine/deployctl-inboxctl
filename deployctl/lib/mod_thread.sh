#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_thread.sh - Thread-like parallel execution for deployctl.

# shellcheck shell=bash

##
# deployctl_thread_deploy
# Runs independent deployment stages in background Bash jobs and waits for them.
##
deployctl_thread_deploy() {
    local app="$DEPLOY_ARG_APP"
    local repo="$DEPLOY_ARG_REPO"
    local domain="$DEPLOY_ARG_DOMAIN"
    local port="$DEPLOY_ARG_PORT"
    local ssl="${DEPLOY_ARG_SSL:-no}"
    local dockerfile="Dockerfile"

    while [[ -z "$app" ]]; do
        printf 'Application name (kebab-case): ' >&2
        read -r app || true
    done
    validate_app_name "$app" || exit_with_error "$ERR_INVALID_APP_NAME" "invalid app name"

    while [[ -z "$repo" ]]; do
        printf 'Git repository URL: ' >&2
        read -r repo || true
    done

    while [[ -z "$domain" ]]; do
        printf 'Public domain: ' >&2
        read -r domain || true
    done
    validate_domain "$domain" || exit_with_error "$ERR_INVALID_DOMAIN" "invalid domain"

    while [[ -z "$port" ]]; do
        printf 'Host/container TCP port: ' >&2
        read -r port || true
    done
    validate_port "$port" || exit_with_error "$ERR_MISSING_PARAM" "invalid port"

    log_info "[thread] lancement du deploiement parallele pour '${app}'"
    log_info "[thread] PID principal: $$, BASHPID: $BASHPID"

    if [[ "${DEPLOYCTL_DRY_RUN:-0}" != "1" ]]; then
        require_root || exit_with_error "$ERR_NOT_ROOT" "deploy requires root"
    fi

    local pending="${DEPLOYCTL_PENDING_DIR}/${app}"
    DEPLOYCTL_ROLLBACK_APP="$app"
    DEPLOYCTL_ROLLBACK_PENDING_DIR="$pending"
    DEPLOYCTL_ROLLBACK_CONTAINER="${CONTAINER_PREFIX}${app}"

    (
        log_info "[thread:git] PID=${BASHPID} - clone de ${repo}"
        if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
            log_info "[thread:git] DRY-RUN - clone simule"
        else
            deployctl_git_clone_repo "$repo" "$pending"
        fi
    ) &
    local pid_git=$!

    (
        log_info "[thread:check] PID=${BASHPID} - verification des dependances"
        if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
            log_info "[thread:check] DRY-RUN - verification simulee"
        else
            deployctl_check_dependencies
            deployctl_ensure_layout
            deployctl_check_port_free "$port"
        fi
    ) &
    local pid_check=$!

    local fail=0
    wait "$pid_git" || {
        log_error "[thread:git] echec du clone (PID ${pid_git})"
        fail=1
    }
    wait "$pid_check" || {
        log_error "[thread:check] echec des verifications (PID ${pid_check})"
        fail=1
    }

    if [[ "$fail" -ne 0 ]]; then
        exit_with_error "$ERR_GIT_CLONE_FAILED" "thread: echec en phase de preparation"
    fi

    log_info "[thread] phase 1 terminee - clone et verifications OK"

    if [[ "${DEPLOYCTL_DRY_RUN:-0}" != "1" ]] && [[ ! -f "${pending}/${dockerfile}" ]]; then
        cleanup_on_error
        exit_with_error "$ERR_DOCKERFILE_MISSING" "Dockerfile not found in repo"
    fi

    (
        log_info "[thread:env] PID=${BASHPID} - preparation du fichier .env"
        if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
            log_info "[thread:env] DRY-RUN - env simule"
        else
            if [[ -f "${pending}/.env.example" ]]; then
                deployctl_collect_env_from_example "$app" "$pending"
            else
                deployctl_collect_env_interactive_full "$app"
            fi
        fi
    ) &
    local pid_env=$!

    (
        log_info "[thread:docker] PID=${BASHPID} - build de l'image Docker"
        if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
            log_info "[thread:docker] DRY-RUN - build simule"
        else
            deployctl_docker_build "$app" "$pending" "$dockerfile"
        fi
    ) &
    local pid_docker=$!

    fail=0
    wait "$pid_env" || {
        log_error "[thread:env] echec env (PID ${pid_env})"
        fail=1
    }
    wait "$pid_docker" || {
        log_error "[thread:docker] echec build (PID ${pid_docker})"
        fail=1
    }

    if [[ "$fail" -ne 0 ]]; then
        cleanup_on_error
        exit_with_error "$ERR_DOCKER_BUILD_FAILED" "thread: echec en phase de build"
    fi

    log_info "[thread] phase 2 terminee - env et build OK"
    log_info "[thread] phase 3 - lancement sequentiel"

    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_info "[thread] DRY-RUN - run/health/nginx simules"
    else
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
            exit_with_error "$ERR_NGINX_CONFIG_FAILED" "nginx write failed"
        }
        deployctl_nginx_test_and_reload "$app" || {
            cleanup_on_error
            exit_with_error "$ERR_NGINX_CONFIG_FAILED" "nginx test/reload failed"
        }

        if [[ "$ssl" == "yes" || "$ssl" == "true" ]]; then
            deployctl_run_certbot_optional "$domain" "$app" || log_project_error "$app" "SSL step failed (deployment continues)"
        fi

        mkdir -p "$DEPLOYCTL_LIVE_DIR"
        if [[ -d "${DEPLOYCTL_LIVE_DIR}/${app}" ]]; then
            rm -rf "${DEPLOYCTL_LIVE_DIR}/${app}.old" 2>/dev/null || true
            mv "${DEPLOYCTL_LIVE_DIR}/${app}" "${DEPLOYCTL_LIVE_DIR}/${app}.old" || true
        fi
        mv "$pending" "${DEPLOYCTL_LIVE_DIR}/${app}"
        deployctl_write_project_conf "$app" "$repo" "$domain" "$port" "$dockerfile" "$ssl" "$STATUS_LIVE"
        printf '%s\n' "LAST_DEPLOY=$(current_timestamp)" >"${DEPLOYCTL_STATE_DIR}/${app}.state"
    fi

    DEPLOYCTL_ROLLBACK_NGINX_CONF=""
    DEPLOYCTL_ROLLBACK_PENDING_DIR=""
    DEPLOYCTL_ROLLBACK_CONTAINER=""
    DEPLOYCTL_ROLLBACK_APP=""

    log_project_info "$app" "thread deploy completed successfully"
    log_info "[thread] deploiement parallele termine pour '${app}'"
    return 0
}
