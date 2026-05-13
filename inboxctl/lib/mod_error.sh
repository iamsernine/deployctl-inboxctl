#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_error.sh - Centralized errors for inboxctl.

# shellcheck shell=bash

##
# inboxctl_exit_with_error
# Prints a formatted error and exits with the provided code.
##
inboxctl_exit_with_error() {
    local code="${1:-1}"
    local message="${2:-erreur inconnue}"

    printf '\033[1;31m[ERREUR %d]\033[0m %s\n' "$code" "$message" >&2
    printf '\n' >&2
    printf "Pour afficher l'aide : inboxctl --help\n" >&2

    exit "$code"
}
