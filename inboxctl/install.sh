#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# inboxctl/install.sh — Install inboxctl locally (user-level bin when /usr/local not writable).
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   BashFAQ 028: https://mywiki.wooledge.org/BashFAQ/028
#   Here-documents: https://www.gnu.org/software/bash/manual/html_node/Redirections.html

# =============================================================================
# Strict mode
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

# =============================================================================
# Repo paths
# Study: https://mywiki.wooledge.org/BashFAQ/028
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# -----------------------------------------------------------------------------
# resolve_install_paths
# Sets BINDIR and DEST based on write access (spec: prefer /usr/local when allowed).
# Globals: BINDIR, DEST
# Returns: 0
# Study: https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html ([[ -w ]])
# -----------------------------------------------------------------------------
resolve_install_paths() {
    if [[ "${EUID:-$(id -u)}" -eq 0 ]] || [[ -w "/usr/local/bin" ]] 2>/dev/null; then
        BINDIR="/usr/local/bin"
        DEST="${INBOXCTL_INSTALL_ROOT:-/usr/local/lib/inboxctl}"
    else
        BINDIR="${HOME}/.local/bin"
        DEST="${INBOXCTL_INSTALL_ROOT:-${HOME}/.local/lib/inboxctl}"
    fi
    return 0
}

# -----------------------------------------------------------------------------
# main
# Study: here-doc wrapper + INBOX_SHARED_ROOT — same pattern as deployctl/install.sh
# -----------------------------------------------------------------------------
main() {
    local BINDIR DEST
    resolve_install_paths

    mkdir -p "$BINDIR"
    mkdir -p "$DEST"
    rm -rf "${DEST}/shared" "${DEST}/inboxctl"
    cp -a "${ROOT}/shared" "$DEST/"
    cp -a "${SCRIPT_DIR}" "$DEST/inboxctl"

    mkdir -p "${HOME}/.config/inboxctl/servers.d"
    mkdir -p "${HOME}/.cache/inboxctl/servers"

    cat >"${BINDIR}/inboxctl" <<EOF
#!/usr/bin/env bash
export INBOX_SHARED_ROOT="$DEST/shared"
exec bash "$DEST/inboxctl/inboxctl.sh" "\$@"
EOF
    chmod 755 "${BINDIR}/inboxctl"

    printf 'inboxctl installed to %s/inboxctl (lib %s)\n' "$BINDIR" "$DEST"
    printf 'Ensure %s is on your PATH.\n' "$BINDIR"
    return 0
}

main "$@"
