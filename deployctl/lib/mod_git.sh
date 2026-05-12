#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/lib/mod_git.sh — Clone application source into pending directory.

# shellcheck shell=bash
#
# Further reading (exam / study index):
#   Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/
#

# -----------------------------------------------------------------------------
# deployctl_git_clone_repo
# Clones URL into target directory (removes dir first if dry-run skip).
# Args: $1=repo URL, $2=target directory
# Returns: 0 on success
# Study: https://git-scm.com/docs/git-clone (--depth 1)
# -----------------------------------------------------------------------------
deployctl_git_clone_repo() {
    local url="$1"
    local target="$2"

    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_info "[dry-run] git clone ${url} -> ${target}"
        return 0
    fi

    rm -rf "$target"
    mkdir -p "$(dirname "$target")"
    if git clone --depth 1 "$url" "$target"; then
        log_info "cloned ${url} to ${target}"
        return 0
    fi
    log_error "git clone failed for ${url}"
    return 1
}