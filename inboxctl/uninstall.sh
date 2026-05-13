#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# inboxctl/uninstall.sh — Remove inboxctl wrapper and library tree.
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash arrays: https://www.gnu.org/software/bash/manual/html_node/Arrays.html

# =============================================================================
# Strict mode
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

# =============================================================================
# Known install locations (system + user)
# Study: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
# =============================================================================
DEST="${INBOXCTL_INSTALL_ROOT:-/usr/local/lib/inboxctl}"
USER_DEST="${HOME}/.local/lib/inboxctl"

# -----------------------------------------------------------------------------
# prompt_yes
# Study: read + [[ =~ ]] for yes/no — https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html#index-read
# -----------------------------------------------------------------------------
prompt_yes() {
    local ans
    printf '%s [y/N] ' "$1" >&2
    read -r ans || ans="n"
    [[ "$ans" =~ ^[Yy]$ ]]
}

# -----------------------------------------------------------------------------
# main
# Study: array of paths — https://www.gnu.org/software/bash/manual/html_node/Arrays.html
# -----------------------------------------------------------------------------
main() {
    local BINDIRS=("${HOME}/.local/bin/inboxctl" "/usr/local/bin/inboxctl")

    if ! prompt_yes "Remove inboxctl from PATH locations and ${DEST}?"; then
        printf 'Aborted.\n'
        exit 0
    fi

    for b in "${BINDIRS[@]}"; do
        [[ -f "$b" ]] && rm -f "$b"
    done
    rm -rf "$DEST"
    rm -rf "$USER_DEST"

    if prompt_yes "Remove ~/.config/inboxctl and ~/.cache/inboxctl?"; then
        rm -rf "${HOME}/.config/inboxctl" "${HOME}/.cache/inboxctl"
    fi

    printf 'inboxctl uninstall finished.\n'
    return 0
}

main "$@"
