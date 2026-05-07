#!/bin/bash

#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: deployctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: Naouali Houssam <houssamnaouali04@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_nginx.sh - Nginx management
# manages Nginx configuration and deployment for deployctl projects
#
# requires: shared/constants.sh 
# shellcheck shell=bash

# IMPORTANT: i suposed that the app config contains REPO_NAME

# this script will take one parameter is the APP_NAME

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
    log_event "ERROR" "NGINX" "$APP_NAME" "Configuration file not found: $TEMP_APP_CONFIG_FILE"
    exit $ERR_CONFIG_PARSE_ERROR
fi

# get_conf to Load the configuration file
get_conf() {
    local key="$1"
    grep "^${key}=" "$TEMP_APP_CONFIG_FILE" | cut -d'=' -f2-
}

#############################################################

APP_CACHE_DIR="${DEPLOYCTL_CACHE_DIR}/temp/${APP_NAME}"
APP_NGINX_TMP_CONFIG_FILE="${APP_CACHE_DIR}/nginx.conf"
APP_NGINX_CONFIG_FILE="/etc/nginx/sites-available/${APP_NAME}"
DOMAIN=$(get_conf "DOMAIN")
PORT=$(get_conf "PORT")

mkdir -p "$APP_CACHE_DIR"
# ///////////// cc
if [ -f "$APP_NGINX_CONFIG_FILE" ]; then
   cat "$APP_NGINX_CONFIG_FILE" > "$APP_NGINX_TMP_CONFIG_FILE" 
fi

if [ -z "$DOMAIN" ] || [ -z "$PORT" ]; then
    echo "DOMAIN or PORT not defined in $TEMP_APP_CONFIG_FILE"
    log_event "ERROR" "NGINX" "$APP_NAME" "DOMAIN or PORT not defined in config"
    exit $ERR_CONFIG_PARSE_ERROR
fi

# generate nginx config file for the app
cat > "$APP_NGINX_CONFIG_FILE" << EOF
server {
    # Listen on standard HTTP port
    listen 80;
    listen [::]:80;
    
    # 1. THE DOMAIN: The domain(s) this app should respond to
    server_name $DOMAIN;

    location / {
        # 2. THE ROUTING: Point to the new Docker container's port
        proxy_pass http://127.0.0.1:$PORT;

        # 3. WEBSOCKET SUPPORT
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        
        # 4. SECURITY & CONTEXT: Pass the original request info to the container
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# //// cc
ln -sf "$APP_NGINX_CONFIG_FILE" "/etc/nginx/sites-enabled/${APP_NAME}"

if ! nginx -t > /dev/null 2>&1; then
    echo "Nginx configuration test failed. Please check the config file: $APP_NGINX_CONFIG_FILE"
    log_event "ERROR" "NGINX" "$APP_NAME" "Nginx configuration test failed"
    exit $ERR_NGINX_CONFIG_FAILED
fi

systemctl reload nginx
if [ "$?" -ne 0 ]; then
    echo "Failed to reload Nginx. Please check the Nginx service status."
    log_event "ERROR" "NGINX" "$APP_NAME" "Failed to reload Nginx"
    exit $ERR_NGINX_CONFIG_FAILED
fi

log_event "INFO" "NGINX" "$APP_NAME" "Nginx configuration applied and reloaded successfully"



SSL_ENABLED=$(get_conf "SSL_ENABLED")
if [ "$SSL_ENABLED" != "true" ]; then
    echo "SSL is not enabled for $APP_NAME. Skipping SSL configuration."
    log_event "INFO" "NGINX" "$APP_NAME" "SSL not enabled, skipping SSL configuration"
    exit 0
fi

# if SSL is enabled, we will generate a self-signed certificate for the domain and configure nginx to use it

GLOBAL_DEPLOYCTL_CONF="${DEPLOYCTL_ETC}/deployctl.conf"

getconf_global() {
    local key="$1"
    grep "^${key}=" "$GLOBAL_DEPLOYCTL_CONF" | cut -d'=' -f2-
}

EMAIL=$(getconf_global "ADMIN_EMAIL")

if [ -z "$EMAIL" ]; then
    echo "ADMIN_EMAIL not defined in global config: $GLOBAL_DEPLOYCTL_CONF"
    log_event "WARN" "NGINX" "$APP_NAME" "ADMIN_EMAIL not defined in global config"
    sudo certbot --nginx -d "$DOMAIN" --register-unsafely-without-email --agree-tos --non-interactive --redirect > /dev/null 2>&1
else
    sudo certbot --nginx -d "$DOMAIN" -m "$EMAIL" --agree-tos --no-eff-email --non-interactive --redirect > /dev/null 2>&1
fi

if [ "$?" -eq 0 ]; then
    log_event "INFO" "NGINX" "$APP_NAME" "SSL certificate obtained and configured successfully"
else
    echo "Failed to obtain SSL certificate for $DOMAIN. Please check certbot logs."
    log_event "ERROR" "NGINX" "$APP_NAME" "Failed to obtain SSL certificate"
    exit $ERR_SSL_FAILED
fi

exit 0

