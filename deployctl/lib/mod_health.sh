#!/bin/bash



#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: deployctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: Naouali Houssam <houssamnaouali04@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_health.sh - health check management
# manages health checks for deployctl projects
#
# requires: shared/constants.sh 
# shellcheck shell=bash

# this script will take one parameter is the APP_NAME



####################################
source "$(dirname "${BASH_SOURCE[0]}")/../../shared/constants.sh"

# check if the app config file exists in the projects.d directory, if not exit with error
APPS_CONFIG_FILES_PATH="${DEPLOYCTL_PROJECTS_DIR}/"
APP_NAME=$1

if [ -z "$APP_NAME" ]; then
    echo "Usage: $0 <app_name>"
    exit $ERR_MISSING_PARAM
fi

TEMP_APP_CONFIG_FILE="${APPS_CONFIG_FILES_PATH}${APP_NAME}_temp.conf"

if [ ! -f "$TEMP_APP_CONFIG_FILE" ]; then
    echo "Configuration file for $APP_NAME not found: $TEMP_APP_CONFIG_FILE"
    log_event "ERROR" "HEALTH" "$APP_NAME" "Configuration file not found: $TEMP_APP_CONFIG_FILE"
    exit $ERR_CONFIG_PARSE_ERROR
fi

# get_conf to Load the configuration file
get_conf() {
    local key="$1"
    grep "^${key}=" "$TEMP_APP_CONFIG_FILE" | cut -d'=' -f2-
}
#############################################################


HEALTH_CHECK_PATH=$(get_conf "HEALTH_PATH")
if [ -z "$HEALTH_CHECK_PATH" ]; then
    echo "HEALTH_PATH not defined in configuration file."
    log_event "ERROR" "HEALTH" "$APP_NAME" "HEALTH_PATH not defined in configuration file."
    exit $ERR_CONFIG_PARSE_ERROR
fi

if [[ "$HEALTH_CHECK_PATH" != /* ]]; then
    HEALTH_CHECK_PATH="/$HEALTH_CHECK_PATH"
fi

PORT=$(get_conf "PORT")
HEALTH_CHECK_URL="http://127.0.0.1:$PORT$HEALTH_CHECK_PATH"

# start health check loop
echo "Starting health check for $APP_NAME at $HEALTH_CHECK_URL"
log_event "INFOS" "HEALTH" "$APP_NAME" "Starting health check at $HEALTH_CHECK_URL"

# these parameters will be fetched from the configuration file in the future, for now they are hardcoded
MAX_RETRIES=10
RETRY_INTERVAL=5

while [ $MAX_RETRIES -gt 0 ]; do
    HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "$HEALTH_CHECK_URL")
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo "Health check successful for $APP_NAME. Application is healthy."
        log_event "SUCCESS" "HEALTH" "$APP_NAME" "Health check successful. Application is healthy."
        exit 0
    else
        echo "Health check failed for $APP_NAME. HTTP status: $HTTP_STATUS. Retrying in $RETRY_INTERVAL seconds..."
        log_event "WARNING" "HEALTH" "$APP_NAME" "Health check failed. HTTP status: $HTTP_STATUS. Retrying in $RETRY_INTERVAL seconds..."
        sleep $RETRY_INTERVAL
        ((MAX_RETRIES--))
    fi
done

echo "Health check failed for $APP_NAME after multiple attempts. Application is unhealthy."
log_event "ERROR" "HEALTH" "$APP_NAME" "Health check failed after multiple attempts. Application is unhealthy."
exit $ERR_HEALTH_CHECK_FAILED
