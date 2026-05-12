#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_nginx.sh — Render site config from template, test, reload nginx.

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

DEPLOYCTL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------------------------------------------------------
# deployctl_nginx_render_config
# Substitutes placeholders into nginx.conf.tpl and writes sites-available file.
# Args: $1=app, $2=domain, $3=port
# Returns: 0 on success; sets DEPLOYCTL_ROLLBACK_NGINX_CONF on write
# Study: sed(1) — https://www.gnu.org/software/sed/manual/sed.html
# -----------------------------------------------------------------------------
deployctl_nginx_render_config() {
    local app="$1"
    local domain="$2"
    local port="$3"
    local tpl="${DEPLOYCTL_LIB_DIR}/templates/nginx.conf.tpl"
    local out="/etc/nginx/sites-available/deployctl-${app}.conf"

    if [[ ! -f "$tpl" ]]; then
        tpl="$(dirname "$DEPLOYCTL_LIB_DIR")/templates/nginx.conf.tpl"
    fi

    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_project_info "$app" "[dry-run] would write nginx config ${out}"
        return 0
    fi

    local tmp
    tmp="$(mktemp)"
    sed \
        -e "s/{{DOMAIN}}/${domain}/g" \
        -e "s/{{PORT}}/${port}/g" \
        -e "s/{{APP_NAME}}/${app}/g" \
        "$tpl" >"$tmp"
    mv "$tmp" "$out"
    DEPLOYCTL_ROLLBACK_NGINX_CONF="$out"

    ln -sf "$out" "/etc/nginx/sites-enabled/deployctl-${app}.conf" 2>/dev/null || \
        ln -sf "$out" "/etc/nginx/conf.d/deployctl-${app}.conf" 2>/dev/null || true

    log_project_info "$app" "wrote nginx config ${out}"
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_nginx_test_and_reload
# Runs nginx -t and reloads service.
# Args: $1=app (for logs)
# Returns: 0 on success
# Study: nginx -t / reload — https://nginx.org/en/docs/control.html
# -----------------------------------------------------------------------------
deployctl_nginx_test_and_reload() {
    local app="$1"
    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_project_info "$app" "[dry-run] nginx -t && reload"
        return 0
    fi
    if nginx -t 2>/tmp/deployctl-nginx-test.log; then
        systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || nginx -s reload
        log_project_info "$app" "nginx reloaded"
        return 0
    fi
    log_project_error "$app" "nginx -t failed"
    cat /tmp/deployctl-nginx-test.log >&2 || true
    return 1
}

# -----------------------------------------------------------------------------
# deployctl_nginx_remove_config
# Removes site config for app (rollback/archive cleanup).
# Args: $1=app
# Returns: 0
# Study: Debian-style sites-available / sites-enabled nginx layout
# -----------------------------------------------------------------------------
deployctl_nginx_remove_config() {
    local app="$1"
    local out="/etc/nginx/sites-available/deployctl-${app}.conf"
    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_info "[dry-run] remove nginx ${out}"
        return 0
    fi
    rm -f "/etc/nginx/sites-enabled/deployctl-${app}.conf"
    rm -f "/etc/nginx/conf.d/deployctl-${app}.conf"
    rm -f "$out"
    nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
    return 0
}