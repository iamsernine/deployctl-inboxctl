#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: MEDINOU Soukaina <soukainamedinou22@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_ui.sh - UI rendering layer
# responsible for formatting, filtering and displaying project data
# used by: show_projects, watch mode
#
# requires: shared/constants.sh shared/format.sh
# shellcheck shell=bash

# =============================================================================
# Internal helpers
# =============================================================================

# -----------------------------------------------------------------------------
# color_status
# applies simple ANSI colors based on STATUS_* constants
#
# Args: $1=status
# Returns: 0; prints colored status
# -----------------------------------------------------------------------------

color_status() {
    case "$1" in
        "$STATUS_LIVE")    printf '\033[32m%s\033[0m' "$1" ;;
        "$STATUS_ERROR")   printf '\033[31m%s\033[0m' "$1" ;;
        "$STATUS_PENDING") printf '\033[33m%s\033[0m' "$1" ;;
        "$STATUS_ARCHIVE") printf '\033[34m%s\033[0m' "$1" ;;
        *) printf '%s' "$1" ;;
    esac
}

# -----------------------------------------------------------------------------
# inboxctl_ui_print_projects_header
# Affiche l'en-tête du tableau des projets
# Utilise print_table_line (format.sh) pour garder un format uniforme
# -----------------------------------------------------------------------------

inboxctl_ui_print_projects_header() {
    print_table_line "NAME" "DOMAIN" "PORT" "STATUS"
    printf '%s\n' "--------------------------------------------"
}

# -----------------------------------------------------------------------------
# inboxctl_ui_print_projects_table
# Affiche la liste des projets ligne par ligne
# Chaque ligne est reçue sous forme : name|domain|port|status
# -----------------------------------------------------------------------------

inboxctl_ui_print_projects_table() {
    while IFS="|" read -r name domain port status || [[ -n "$name" ]]; do
        status="$(color_status "$status")"
        print_table_line "$name" "$domain" "$port" "$status"
    done
}

# -----------------------------------------------------------------------------
# inboxctl_ui_filter_status
# Filtre les projets selon leur statut
# Si filter est vide → affiche tout
# -----------------------------------------------------------------------------

inboxctl_ui_filter_status() {
    local filter="$1"

    while IFS="|" read -r name domain port status; do
        if [[ -z "$filter" || "$status" == "$filter" ]]; then
            printf '%s|%s|%s|%s\n' "$name" "$domain" "$port" "$status"
        fi
    done
}

# -----------------------------------------------------------------------------
# inboxctl_ui_sort
# Trie les projets selon un critère
# name   → tri par nom
# port   → tri numérique par port
# status → tri par statut
# -----------------------------------------------------------------------------

inboxctl_ui_sort() {
    case "$1" in
        name) sort -t"|" -k1 ;;
        port) sort -t"|" -k3 -n ;;
        status) sort -t"|" -k4 ;;
        *) cat ;;
    esac
}
