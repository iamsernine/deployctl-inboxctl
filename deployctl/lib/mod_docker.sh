#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_docker.sh — Image build, network, and container lifecycle.

# shellcheck shell=bash

# -----------------------------------------------------------------------------
# deployctl_docker_ensure_network
# Creates deployctl bridge network if missing.
# Returns: 0
# -----------------------------------------------------------------------------
deployctl_docker_ensure_network() {
    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_info "[dry-run] docker network inspect ${NETWORK_NAME}"
        return 0
    fi
    if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        docker network create "$NETWORK_NAME" || return 1
        log_info "created docker network ${NETWORK_NAME}"
    fi
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_docker_build
# Args: $1=app name, $2=context dir, $3=dockerfile path relative or absolute
# Returns: 0 on success
# -----------------------------------------------------------------------------
deployctl_docker_build() {
    local app="$1"
    local ctx="$2"
    local dockerfile="${3:-Dockerfile}"

    local image="${IMAGE_PREFIX}${app}:latest"
    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_project_info "$app" "[dry-run] docker build -t ${image} ${ctx}"
        return 0
    fi

    local dfpath="$ctx/$dockerfile"
    [[ -f "$dfpath" ]] || dfpath="$dockerfile"

    if docker build -t "$image" -f "$dfpath" "$ctx"; then
        log_project_info "$app" "built image ${image}"
        return 0
    fi
    log_project_error "$app" "docker build failed"
    return 1
}

# -----------------------------------------------------------------------------
# deployctl_docker_run_app
# Runs container with env file and published port.
# Args: $1=app, $2=host port, $3=container internal port
# Returns: 0
# -----------------------------------------------------------------------------
deployctl_docker_run_app() {
    local app="$1"
    local host_port="$2"
    local cport="$3"
    local container="${CONTAINER_PREFIX}${app}"
    local image="${IMAGE_PREFIX}${app}:latest"
    local envf="${DEPLOYCTL_ENV_DIR}/${app}.env"

    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_project_info "$app" "[dry-run] docker run -d --name ${container} -p ${host_port}:${cport} --env-file ${envf}"
        return 0
    fi

    docker rm -f "$container" 2>/dev/null || true
    deployctl_docker_ensure_network || return 1

    if docker run -d \
        --name "$container" \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        --env-file "$envf" \
        -p "${host_port}:${cport}" \
        "$image"; then
        log_project_info "$app" "started container ${container}"
        return 0
    fi
    log_project_error "$app" "docker run failed"
    return 1
}

# -----------------------------------------------------------------------------
# deployctl_docker_stop_remove
# Args: $1=container name
# Returns: 0
# -----------------------------------------------------------------------------
deployctl_docker_stop_remove() {
    local c="$1"
    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_info "[dry-run] docker rm -f $c"
        return 0
    fi
    docker rm -f "$c" 2>/dev/null || true
    return 0
}
