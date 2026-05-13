#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/uninstall.sh — Remove deployctl binaries and library payload with confirmation.
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Conditional regex match: https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html

# =============================================================================
# Strict mode
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

# =============================================================================
# Install root (must match install.sh)
# Study: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
# =============================================================================
DEST="${DEPLOYCTL_INSTALL_ROOT:-/usr/local/lib/deployctl}"

# -----------------------------------------------------------------------------
# prompt_yes
# Args: $1=prompt string
# Returns: 0 if user answered y/Y
# Study: https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html#index-read; [[ =~ ]]
# -----------------------------------------------------------------------------
prompt_yes() {
    local prompt="$1"
    local ans
    printf '%s [y/N] ' "$prompt" >&2
    read -r ans || ans="n"
    [[ "$ans" =~ ^[Yy]$ ]]
}

# -----------------------------------------------------------------------------
# main
# Study: interactive guard rails before rm -rf — https://mywiki.wooledge.org/BashGuide/Practices
# -----------------------------------------------------------------------------
main() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        printf 'deployctl uninstall: must run as root\n' >&2
        exit 1
    fi

    printf 'This removes /usr/local/bin/deployctl and %s\n' "$DEST"
    if ! prompt_yes "Remove deployctl program files?"; then
        printf 'Aborted.\n'
        exit 0
    fi

    rm -f /usr/local/bin/deployctl
    rm -rf "$DEST"

    if prompt_yes "Also remove /etc/deployctl and /var/lib/deployctl (configs, apps, env)?"; then
        rm -rf /etc/deployctl /var/lib/deployctl
    fi

    if prompt_yes "Also remove /var/log/deployctl and /var/cache/deployctl?"; then
        rm -rf /var/log/deployctl /var/cache/deployctl
    fi

    printf 'deployctl uninstall finished.\n'
    return 0
}

main "$@"
