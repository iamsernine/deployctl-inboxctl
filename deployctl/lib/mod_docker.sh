#!/bin/bash

#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: deployctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: Naouali Houssam <houssamnaouali04@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_docker.sh - Docker management
# manages Docker images build and run containers for deployctl projects
#
# requires: shared/constants.sh 
# shellcheck shell=bash

# IMPORTANT: i suposed that the app config contains REPO_NAME

# this script will take one parameter is the APP_NAME

source "$(dirname "${BASH_SOURCE[0]}")/../../shared/constants.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../shared/format.sh"


# check if the app config file exists in the projects.d directory, if not exit with error
APPS_CONFIG_FILES_PATH="${DEPLOYCTL_PROJECTS_DIR}/"
APP_NAME=$1
ENV_FOLDER_PATH="${DEPLOYCTL_ENV_DIR}/"

if [ -z "$APP_NAME" ]; then
    echo "Usage: $0 <app_name>"
    exit $ERR_MISSING_PARAM
fi

TEMP_APP_CONFIG_FILE="${APPS_CONFIG_FILES_PATH}${APP_NAME}_temp.conf"

if [ ! -f "$TEMP_APP_CONFIG_FILE" ]; then
    echo "Configuration file for $APP_NAME not found: $TEMP_APP_CONFIG_FILE"
    log_event "ERROR" "CLONE" "$APP_NAME" "Configuration file not found: $TEMP_APP_CONFIG_FILE"
    exit $ERR_CONFIG_PARSE_ERROR
fi

# get_conf to Load the configuration file
get_conf() {
    local key="$1"
    grep "^${key}=" "$TEMP_APP_CONFIG_FILE" | cut -d'=' -f2-
}

# check if any port is available
PORT="$(find_free_port)"
if [ -z "$PORT" ]; then
    echo "No available port found in range [3000-4000]." # this print can be modified if the range is changed in the find_free_port function
    log_event "ERROR" "RUN" "$APP_NAME" "No available port found."
    exit $ERR_PORT_IN_USE
fi

# Check if DOCKERFILE_FOLDER_PATH is defined in the configuration file
DOCKERFILE_FOLDER_PATH="${DEPLOYCTL_PENDING_DIR}/${APP_NAME}/$(get_conf "DOCKERFILE_PATH")"

if [ -z "$DOCKERFILE_FOLDER_PATH" ]; then
    echo "DOCKERFILE_FOLDER_PATH not defined in configuration file."
    log_event "ERROR" "BUILD" "$APP_NAME" "DOCKERFILE_FOLDER_PATH not defined in configuration file."
    exit $ERR_DOCKERFILE_MISSING
fi

# Start building the Docker image
echo "Start building Docker image for $APP_NAME using Dockerfile in: $DOCKERFILE_FOLDER_PATH"
log_event "INFOS" "BUILD" "$APP_NAME" "Start building Docker image using Dockerfile in: $DOCKERFILE_FOLDER_PATH"

DOCKER_IMAGE_NAME="deployctl/${APP_NAME}:temp"

docker build -t "$DOCKER_IMAGE_NAME" "$DOCKERFILE_FOLDER_PATH" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "Failed to build Docker image for $APP_NAME"
    log_event "ERROR" "BUILD" "$APP_NAME" "Failed to build Docker image"
    exit $ERR_DOCKER_BUILD_FAILED
fi

echo "Docker image for $APP_NAME built successfully."
log_event "SUCCESS" "BUILD" "$APP_NAME" "Docker image built successfully"


# Now we will run the Docker container

INNER_PORT=$(get_conf "INNER_PORT")
TEMP_ENV_FILE_PATH="$ENV_FOLDER_PATH${APP_NAME}_temp.env"
TIMESTAMP=$(date +%s)
CONTAINER_NAME="deployctl/${APP_NAME}:${TIMESTAMP}"

docker run -d --name "$CONTAINER_NAME" --env-file "$TEMP_ENV_FILE_PATH" -p "$PORT:$INNER_PORT" "$DOCKER_IMAGE_NAME" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "Failed to run Docker container for $APP_NAME"
    log_event "ERROR" "RUN" "$APP_NAME" "Failed to run Docker container"
    exit $ERR_CONTAINER_RUN_FAILED
fi

# Update the app config file with the new temp port so the next steps can use it to update the final config file and to know which port is used by the container
sed -i "s/^PORT=.*/PORT=$PORT/" "$TEMP_APP_CONFIG_FILE"
if [ $? -ne 0 ]; then
   if grep -q "^PORT=" "$TEMP_APP_CONFIG_FILE"; then
      echo "Failed to update PORT in config file for $APP_NAME"
      log_event "ERROR" "RUN" "$APP_NAME" "Failed to update PORT in config file"
      exit $ERR_CONFIG_PARSE_ERROR
   else
      echo "PORT=$PORT" >> "$TEMP_APP_CONFIG_FILE"
   fi
fi

# Update the app config file with the new container name so the next steps can use it to update the final config file and to know which container is running for this app
sed -i "s/^CONTAINER_NAME=.*/CONTAINER_NAME=$CONTAINER_NAME/" "$TEMP_APP_CONFIG_FILE"
if [ $? -ne 0 ]; then
   if grep -q "^CONTAINER_NAME=" "$TEMP_APP_CONFIG_FILE"; then
      echo "Failed to update CONTAINER_NAME in config file for $APP_NAME"
      log_event "ERROR" "RUN" "$APP_NAME" "Failed to update CONTAINER_NAME in config file"
      exit $ERR_CONFIG_PARSE_ERROR
   else
      echo "CONTAINER_NAME=$CONTAINER_NAME" >> "$TEMP_APP_CONFIG_FILE"
   fi
fi

echo "Docker container for $APP_NAME is running successfully on port $PORT."
log_event "SUCCESS" "RUN" "$APP_NAME" "Docker container is running successfully on port $PORT"


exit 0
