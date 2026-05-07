#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: MEDINOU Soukaina <soukainamedinou22@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# inboxctl/lib/mod_cli.sh - command line interface layer
# handles user arguments parsing and usage display
#
# requires: shared/constants.sh shared/format.sh
# shellcheck shell=bash

# =============================================================================
# Public API
# =============================================================================

# -----------------------------------------------------------------------------
# inboxctl_print_usage
# displays CLI usage instructions
#
# Returns: 0 always
# -----------------------------------------------------------------------------
inboxctl_print_usage() {
    printf 'inboxctl (version %s)\n' "$DEPLOYCTL_INBOXCTL_VERSION"
    printf '\nUsage:\n'
    printf '  inboxctl show projects <server>\n'
    printf '  inboxctl logs\n'
    printf '  inboxctl errors\n'
    printf '  inboxctl watch <server>\n'
    printf '\nOptions:\n'
    printf '  --help        Show this help message\n'
    printf '  --version     Show version\n'
}

# -----------------------------------------------------------------------------
# inboxctl_parse_globals
# parses global CLI options and stores remaining args into ARGS
#
# Args: all CLI arguments
# -----------------------------------------------------------------------------
inboxctl_parse_globals() {
    ARGS=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                inboxctl_print_usage
                exit 0
                ;;
            --version|-v)
                printf 'inboxctl version %s\n' "$DEPLOYCTL_INBOXCTL_VERSION"
                exit 0
                ;;
            *)
                ARGS+=("$1")
                ;;
        esac
        shift
    done
}
