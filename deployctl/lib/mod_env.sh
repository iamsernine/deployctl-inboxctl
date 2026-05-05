#!/bin/bash



#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: deployctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: Naouali Houssam <houssamnaouali04@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_env.sh - environment variables management
# manages environment variables for deployctl projects
#
# requires: shared/constants.sh 
# shellcheck shell=bash

# IMPORTANT: i suposed that the app config contains REPO_NAME
# this script will take one parameter is the APP_NAME

# shellcheck source=../../shared/constants.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../shared/constants.sh"

APPS_CONFIG_FILES_PATH="${DEPLOYCTL_PROJECTS_DIR}/"
APP_NAME=$1
ENV_FOLDER_PATH="${DEPLOYCTL_ENV_DIR}/"

if [ -z "$APP_NAME" ]; then
    echo "Usage: $0 <app_name>"
    exit $ERR_MISSING_PARAM
fi

APP_CONFIG_FILE="${APPS_CONFIG_FILES_PATH}${APP_NAME}.conf"

if [ ! -f "$APP_CONFIG_FILE" ]; then
    echo "Configuration file for $APP_NAME not found: $APP_CONFIG_FILE"
    log_event "ERROR" "BUILD" "$APP_NAME" "Configuration file not found: $APP_CONFIG_FILE"
    exit $ERR_CONFIG_FILE_MISSING
fi

touch "${ENV_FOLDER_PATH}${APP_NAME}.env"

# Load the configuration file
get_conf() {
    local key="$1"
    grep "^${key}=" "$APP_CONFIG_FILE" | cut -d'=' -f2-
}

log_event "INFOS" "BUILD" "$APP_NAME" "Configuration file loaded: $APP_CONFIG_FILE"

REPO_PATH="${DEPLOYCTL_PENDING_DIR}/${APP_NAME}/$(get_conf "REPO_NAME")"

if [ ! -d "$REPO_PATH" ]; then
    echo "Repository path not found: $REPO_PATH"
    log_event "ERROR" "BUILD" "$APP_NAME" "Repository path not found: $REPO_PATH"
    exit 1
fi



ENV_EXAMPLE_FILE="${REPO_PATH}/.env.example"

if [ ! -f "$ENV_EXAMPLE_FILE" ]; then
    echo ".env.example file not found in repository .... ignoring .env file: $ENV_EXAMPLE_FILE"
    log_event "WARN" "BUILD" "$APP_NAME" ".env.example file not found in repository: $ENV_EXAMPLE_FILE"
    exit $ERR_ENV_EXAMPLE_MISSING #this for warning
fi

# notice : this is a temporary env file in case of error it will be removed and if the build is successful it will be renamed to the final env file with the name of the app
ENV_FILE="${ENV_FOLDER_PATH}${APP_NAME}_temp.env"

cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"

if [ $? -ne 0 ]; then
    echo "Failed to copy .env.example to $ENV_FILE"
    log_event "ERROR" "BUILD" "$APP_NAME" "Failed to copy .env.example to $ENV_FILE"
    exit 1
fi


echo "--------- env values for $APP_NAME : "

while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    if [ -z "$line" ] || [[ "$line" == \#* ]]; then
        continue
    fi
    # Extract the key from the line
    key=$(echo "$line" | cut -d'=' -f1)
    default_value=$(echo "$line" | cut -d'=' -f2-)

    # Prompt the user for input, showing the default value
    read -p "Enter value for $key (default: $default_value): " input_value
    if [ -z "$input_value" ]; then
        input_value="$default_value"
    fi
    # Update the .env file with the new value
    sed -i "s/^$key=.*/$key=$input_value/" "$ENV_FILE"

done < "$ENV_EXAMPLE_FILE"

echo "Environment variables for $APP_NAME have been set successfully."
log_event "SUCCESS" "BUILD" "$APP_NAME" "Environment variables set successfully for $APP_NAME"


exit 0