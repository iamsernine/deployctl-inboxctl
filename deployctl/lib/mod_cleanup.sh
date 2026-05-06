#!/bin/bash




#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: deployctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: Naouali Houssam <houssamnaouali04@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_cleanup.sh - cleanup management
# manages cleanup operations for deployctl projects
#
# requires: shared/constants.sh 
# shellcheck shell=bash


# Script for cleaning up temporary files and resources based on the cleanup level
# Arguments: APP_NAME LEVEL

APP_NAME=$1
LEVEL=$2


source "$(dirname "${BASH_SOURCE[0]}")/../../shared/constants.sh"

# Path to app config files
APPS_CONFIG_FILES_PATH="${DEPLOYCTL_PROJECTS_DIR}/"

# Check if APP_NAME is provided
if [ -z "$APP_NAME" ]; then
    echo "Usage: $0 <app_name>"
    exit $ERR_MISSING_PARAM
fi

# Define file paths
TEMP_APP_CONFIG_FILE="${APPS_CONFIG_FILES_PATH}${APP_NAME}_temp.conf"
APP_CONFIG_FILE_CURRENT="${APPS_CONFIG_FILES_PATH}${APP_NAME}.conf"
ENV_FOLDER_PATH="${DEPLOYCTL_ENV_DIR}/"
TEMP_ENV_FILE="${ENV_FOLDER_PATH}${APP_NAME}_temp.env"

# Check if temp config file exists
if [ ! -f "$TEMP_APP_CONFIG_FILE" ]; then
    echo "Configuration file for $APP_NAME not found: $TEMP_APP_CONFIG_FILE"
    log_event "ERROR" "CLONE" "$APP_NAME" "Configuration file not found: $TEMP_APP_CONFIG_FILE"
    exit $ERR_CONFIG_PARSE_ERROR
fi

# Function to get config value from temp config file
get_conf() {
    local key="$1"
    grep "^${key}=" "$TEMP_APP_CONFIG_FILE" | cut -d'=' -f2-
}

# Function to remove pending repository directory
remove_pending_repo() {
    if [ -d "$DEPLOYCTL_PENDING_DIR" ]; then
        rm -rf "$DEPLOYCTL_PENDING_DIR/${APP_NAME}"
        log_event "INFOS" "CLEANUP" "ALL" "Removed pending repository for $APP_NAME from repositories directory: $DEPLOYCTL_PENDING_DIR"
    fi
}

# Function to remove temporary environment file
remove_temp_env_file() {
    TEMP_ENV_FILE_PATH="${DEPLOYCTL_ENV_DIR}/${APP_NAME}_temp.env"
    if [ -f "${TEMP_ENV_FILE_PATH}" ]; then
        rm -f "${TEMP_ENV_FILE_PATH}"
        log_event "INFOS" "CLEANUP" "ALL" "Removed temporary env file for $APP_NAME: ${TEMP_ENV_FILE_PATH}"
    fi
}

# Function to remove temporary app config file
remove_temp_app_config_file() {
    if [ -f "$TEMP_APP_CONFIG_FILE" ]; then
        rm -f "$TEMP_APP_CONFIG_FILE"
        log_event "INFOS" "CLEANUP" "ALL" "Removed temporary app config file for $APP_NAME: $TEMP_APP_CONFIG_FILE"
    fi
}

# Function to remove temporary Docker image
remove_temp_docker_image() {
    TEMP_DOCKER_IMAGE_NAME="deployctl/${APP_NAME}:temp"
    if docker images -q "$TEMP_DOCKER_IMAGE_NAME" > /dev/null 2>&1; then
        docker rmi -f "$TEMP_DOCKER_IMAGE_NAME" > /dev/null 2>&1
        log_event "INFOS" "CLEANUP" "ALL" "Removed temporary Docker image for $APP_NAME: $TEMP_DOCKER_IMAGE_NAME"
    fi
}

# Function to remove temporary Docker container
remove_temp_container() {
    TEMP_CONTAINER_NAME="$(get_conf "CONTAINER_NAME")"
    if docker ps -a --format '{{.Names}}' | grep -q "^${TEMP_CONTAINER_NAME}$"; then
        docker stop "$TEMP_CONTAINER_NAME" > /dev/null 2>&1
        docker rm -f "$TEMP_CONTAINER_NAME" > /dev/null 2>&1
        log_event "INFOS" "CLEANUP" "ALL" "Removed temporary Docker container for $APP_NAME: $TEMP_CONTAINER_NAME"
    fi
}

# Function to move repository from pending to live
move_repo_to_live() {
    if [ -d "$DEPLOYCTL_PENDING_DIR/${APP_NAME}" ]; then
        mv "$DEPLOYCTL_PENDING_DIR/${APP_NAME}" "$DEPLOYCTL_LIVE_DIR/${APP_NAME}"
        log_event "INFOS" "CLEANUP" "ALL" "Moved repository for $APP_NAME from pending to live: $DEPLOYCTL_LIVE_DIR/${APP_NAME}"
    fi
}

# Function to archive the live repository
archive_live_repo() {
    if [ -d "$DEPLOYCTL_LIVE_DIR/${APP_NAME}" ]; then
        ARCHIVE_NAME="${APP_NAME}_$(date +%Y%m%d%H%M%S)"
        mv "$DEPLOYCTL_LIVE_DIR/${APP_NAME}" "$DEPLOYCTL_ARCHIVE_DIR/${ARCHIVE_NAME}"
        tar -czf "$DEPLOYCTL_ARCHIVE_DIR/${ARCHIVE_NAME}.tar.gz" -C "$DEPLOYCTL_ARCHIVE_DIR" "${ARCHIVE_NAME}"
        rm -rf "$DEPLOYCTL_ARCHIVE_DIR/${ARCHIVE_NAME}"
        log_event "INFOS" "CLEANUP" "ALL" "Archived live repository for $APP_NAME: $DEPLOYCTL_ARCHIVE_DIR/${ARCHIVE_NAME}"
    fi
}

# Function to rollback NGINX config
rollback_nginx_config() {
    local APP_NGINX_TMP_CONFIG_FILE="${APP_CACHE_DIR}/nginx.conf"
    if [ -f "$APP_NGINX_TMP_CONFIG_FILE" ]; then
        cat "$APP_NGINX_TMP_CONFIG_FILE" > "/etc/nginx/sites-available/${APP_NAME}"
        ln -sf "/etc/nginx/sites-available/${APP_NAME}" "/etc/nginx/sites-enabled/${APP_NAME}"
        nginx -t > /dev/null 2>&1 && systemctl reload nginx
        log_event "INFOS" "CLEANUP" "ALL" "Rolled back NGINX configuration for $APP_NAME using backup config file: $APP_NGINX_TMP_CONFIG_FILE"
    else
       rm -f "/etc/nginx/sites-available/${APP_NAME}"
       rm -f "/etc/nginx/sites-enabled/${APP_NAME}"
       nginx -t > /dev/null 2>&1 && systemctl reload nginx
       log_event "INFOS" "CLEANUP" "ALL" "Removed NGINX configuration for $APP_NAME as no backup config file found: $APP_NGINX_TMP_CONFIG_FILE"
    fi
}

# Function to remove current Docker container
remove_current_docker_container() {
    if [ ! -f "$APP_CONFIG_FILE_CURRENT" ]; then
        log_event "INFOS" "CLEANUP" "ALL" "No current app config file found for $APP_NAME, skipping Docker container cleanup"
        return
    fi
    get_conf_current() {
        local key="$1"
        grep "^${key}=" "$APP_CONFIG_FILE_CURRENT" | cut -d'=' -f2-
    }
    CURRENT_CONTAINER_NAME="$(get_conf_current "CONTAINER_NAME")"
    if docker ps -a --format '{{.Names}}' | grep -q "^${CURRENT_CONTAINER_NAME}$"; then
        docker stop "$CURRENT_CONTAINER_NAME" > /dev/null 2>&1
        docker rm -f "$CURRENT_CONTAINER_NAME" > /dev/null 2>&1
        log_event "INFOS" "CLEANUP" "ALL" "Removed current Docker container for $APP_NAME: $CURRENT_CONTAINER_NAME"
    fi
}

# Function to remove current Docker image
remove_current_docker_image() {
    if [ ! -f "$APP_CONFIG_FILE_CURRENT" ]; then
        log_event "INFOS" "CLEANUP" "ALL" "No current app config file found for $APP_NAME, skipping Docker image cleanup"
        return
    fi
    get_conf_current() {
        local key="$1"
        grep "^${key}=" "$APP_CONFIG_FILE_CURRENT" | cut -d'=' -f2-
    }
    CURRENT_DOCKER_IMAGE_NAME="$(get_conf_current "DOCKER_IMAGE")"
    if docker images -q "$CURRENT_DOCKER_IMAGE_NAME" > /dev/null 2>&1; then
        docker rmi -f "$CURRENT_DOCKER_IMAGE_NAME" > /dev/null 2>&1
        log_event "INFOS" "CLEANUP" "ALL" "Removed current Docker image for $APP_NAME: $CURRENT_DOCKER_IMAGE_NAME"
    fi
}

# Function to rename temp files to final
rename_temp_files() {
    if [ -f "$TEMP_APP_CONFIG_FILE" ]; then
        mv "$TEMP_APP_CONFIG_FILE" "$APP_CONFIG_FILE_CURRENT"
        log_event "INFOS" "CLEANUP" "ALL" "Renamed temporary app config file to current for $APP_NAME: $APP_CONFIG_FILE_CURRENT"
    fi
    if [ -f "$TEMP_ENV_FILE" ]; then
        FINAL_ENV_FILE="${ENV_FOLDER_PATH}${APP_NAME}.env"
        mv "$TEMP_ENV_FILE" "$FINAL_ENV_FILE"
        log_event "INFOS" "CLEANUP" "ALL" "Renamed temporary env file to final for $APP_NAME: $FINAL_ENV_FILE"
    fi
}

# Function to rename Docker image from temp to latest
rename_docker_image() {
    TEMP_DOCKER_IMAGE_NAME="deployctl/${APP_NAME}:temp"
    FINAL_DOCKER_IMAGE_NAME="deployctl/${APP_NAME}:latest"
    if docker images -q "$TEMP_DOCKER_IMAGE_NAME" > /dev/null 2>&1; then
        docker tag "$TEMP_DOCKER_IMAGE_NAME" "$FINAL_DOCKER_IMAGE_NAME" > /dev/null 2>&1
        docker rmi -f "$TEMP_DOCKER_IMAGE_NAME" > /dev/null 2>&1
        sed -i "s/^DOCKER_IMAGE=.*$/DOCKER_IMAGE=${FINAL_DOCKER_IMAGE_NAME}/" "$APP_CONFIG_FILE_CURRENT"
        log_event "INFOS" "CLEANUP" "ALL" "Renamed temporary Docker image to final for $APP_NAME: $FINAL_DOCKER_IMAGE_NAME"
    fi
}

# Case statement to handle different cleanup levels
case "$LEVEL" in
        "clone")
            remove_pending_repo
            remove_temp_app_config_file
            ;;
        "env")
            remove_pending_repo
            remove_temp_env_file
            remove_temp_app_config_file
            ;;
        "run")
            remove_pending_repo
            remove_temp_env_file
            remove_temp_docker_image
            remove_temp_container
            remove_temp_app_config_file
            ;;
        "deploy")
            remove_pending_repo
            remove_temp_env_file
            remove_temp_docker_image
            remove_temp_container
            rollback_nginx_config
            remove_temp_app_config_file
            ;;
        "finalize")
            archive_live_repo
            move_repo_to_live
            remove_current_docker_container
            remove_current_docker_image
            rename_temp_files
            rename_docker_image
            ;;

        *)
        echo "Invalid cleanup level: $LEVEL."
        exit $ERR_MISSING_PARAM
        ;;
esac


