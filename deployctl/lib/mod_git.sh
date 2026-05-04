#!/bin/bash

# this script will take one parameter is the APP_NAME

APPS_CONFIG_FILES_PATH="/etc/deployctl/projects.d/"
APP_NAME=$1

if [ -z "$APP_NAME" ]; then
    echo "Usage: $0 <app_name>"
    exit 1
fi

APP_CONFIG_FILE="${APPS_CONFIG_FILES_PATH}${APP_NAME}.conf"

if [ ! -f "$APP_CONFIG_FILE" ]; then
    echo "Configuration file for $APP_NAME not found: $APP_CONFIG_FILE"
    log_event "ERROR" "CLONE" "$APP_NAME" "Configuration file not found: $APP_CONFIG_FILE"
    exit 1
fi

# Load the configuration file
get_conf() {
    local key="$1"
    grep "^${key}=" "$APP_CONFIG_FILE" | cut -d'=' -f2-
}

log_event "INFOS" "CLONE" "$APP_NAME" "Configuration file loaded: $APP_CONFIG_FILE"

REPO_URL=$(get_conf "REPO_URL")

if [ -z "$REPO_URL" ]; then
    echo "REPO_URL not defined in configuration file."
    log_event "ERROR" "CLONE" "$APP_NAME" "REPO_URL not defined in configuration file."
    exit 1
fi

# Clone the repository
CLONE_DIR="/var/lib/deployctl/apps/pending/${APP_NAME}"
mkdir -p "$CLONE_DIR"
git clone "$REPO_URL" "$CLONE_DIR" >/dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "Failed to clone repository: $REPO_URL"
    rm -rf "$CLONE_DIR"
    log_event "ERROR" "CLONE" "$APP_NAME" "Failed to clone repository: $REPO_URL"
    exit 1
fi

echo "Repository cloned successfully: $REPO_URL"
log_event "SUCCESS" "CLONE" "$APP_NAME" "Repository cloned successfully: $REPO_URL"
