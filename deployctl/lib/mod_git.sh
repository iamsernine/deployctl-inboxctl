#!/bin/bash



#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: deployctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: Naouali Houssam <houssamnaouali04@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_git.sh - git repository management
# manages git repositories cloning for deployctl projects
#
# requires: shared/constants.sh 
# shellcheck shell=bash


# this script will take one parameter is the APP_NAME

# shellcheck source=../../shared/constants.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../shared/constants.sh"

APPS_CONFIG_FILES_PATH="${DEPLOYCTL_PROJECTS_DIR}/"
APP_NAME=$1

if [ -z "$APP_NAME" ]; then
    echo "Usage: $0 <app_name>"
    exit $ERR_MISSING_PARAM
fi

TEMP_APP_CONFIG_FILE="${APPS_CONFIG_FILES_PATH}${APP_NAME}_temp.conf"

if [ ! -f "$TEMP_APP_CONFIG_FILE" ]; then
    echo "Configuration file for $APP_NAME not found: $TEMP_APP_CONFIG_FILE"
    log_event "ERROR" "CLONE" "$APP_NAME" "Configuration file not found: $TEMP_APP_CONFIG_FILE"
    exit $ERR_CONFIG_FILE_MISSING
fi

# Load the configuration file
get_conf() {
    local key="$1"
    grep "^${key}=" "$TEMP_APP_CONFIG_FILE" | cut -d'=' -f2-
}

log_event "INFOS" "CLONE" "$APP_NAME" "Configuration file loaded: $TEMP_APP_CONFIG_FILE"


REPO_URL=$(get_conf "REPO_URL")

if [ -z "$REPO_URL" ]; then
    echo "REPO_URL not defined in configuration file."
    log_event "ERROR" "CLONE" "$APP_NAME" "REPO_URL not defined in configuration file."
    exit $ERR_CONFIG_PARSE_ERROR
fi

CLONE_DIR="${DEPLOYCTL_PENDING_DIR}/${APP_NAME}"
mkdir -p "$CLONE_DIR"
git clone "$REPO_URL" "$CLONE_DIR" >/dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "Failed to clone repository: $REPO_URL"
    rm -rf "$CLONE_DIR"
    log_event "ERROR" "CLONE" "$APP_NAME" "Failed to clone repository: $REPO_URL"
    exit $ERR_GIT_CLONE_FAILED
fi

echo "Repository cloned successfully: $REPO_URL"
log_event "SUCCESS" "CLONE" "$APP_NAME" "Repository cloned successfully: $REPO_URL"



exit 0