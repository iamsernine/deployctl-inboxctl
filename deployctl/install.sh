#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/install.sh — Install deployctl and shared libraries under /usr/local (server).
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   BashFAQ script location: https://mywiki.wooledge.org/BashFAQ/028
#   Here-documents: https://www.gnu.org/software/bash/manual/html_node/Redirections.html

# =============================================================================
# Strict mode — installer mutates system paths; fail fast on errors.
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

# =============================================================================
# Paths and install root (override with DEPLOYCTL_INSTALL_ROOT).
# Study: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEST="${DEPLOYCTL_INSTALL_ROOT:-/usr/local/lib/deployctl}"

# -----------------------------------------------------------------------------
# require_install_root
# deployctl manages system paths; installation must run as root.
# Returns: 0 if root, exits 1 otherwise
# Study: https://www.gnu.org/software/bash/manual/html_node/Bash-Variables.html (EUID)
# -----------------------------------------------------------------------------
require_install_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        printf 'deployctl install: must run as root\n' >&2
        exit 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# main
# Copies payload, wires /usr/local/bin/deployctl wrapper, creates standard dirs.
# Study: cat <<EOF wrapper — https://www.gnu.org/software/bash/manual/html_node/Redirections.html#Here-Documents
# -----------------------------------------------------------------------------
main() {
    require_install_root

    mkdir -p "$DEST"
    cp -a "${ROOT}/shared" "$DEST/"
    cp -a "${SCRIPT_DIR}" "$DEST/deployctl"

    mkdir -p /etc/deployctl/projects.d \
        /var/lib/deployctl/apps/pending /var/lib/deployctl/apps/live /var/lib/deployctl/apps/archive \
        /var/lib/deployctl/env /var/lib/deployctl/state \
        /var/log/deployctl/projects \
        /var/cache/deployctl/builds

    chmod 755 /etc/deployctl /var/lib/deployctl /var/log/deployctl /var/cache/deployctl

    cat >/usr/local/bin/deployctl <<EOF
#!/usr/bin/env bash
export DEPLOY_SHARED_ROOT="$DEST/shared"
exec bash "$DEST/deployctl/deployctl.sh" "\$@"
EOF
    chmod 755 /usr/local/bin/deployctl

    printf 'deployctl installed to %s and /usr/local/bin/deployctl\n' "$DEST"
    return 0
}

main "$@"
