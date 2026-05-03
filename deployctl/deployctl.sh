#!/usr/bin/env bash 
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: deployctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: BEN YAMNA Mohammed <iamsernine@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# deployctl/deployctl.sh - server-side CLI entrypoint for docker monolith deployements.
# sources shared contracts and modular libraries; dispatches subcommands


# =============================================================================
# strict mode : exit on failed command (set -e  ), undefined var are errors (set -u  )
# pipelines propagate failure (set -o pipefail) 
# use set -x for debugging purpose 
# find more in http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail 

# Absolute path to this script's directory (deployctl CLI location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Root directory of the deployctl repository (one level up from script)
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Path to shared modules (can be overridden via DEPLOY_SHARED_ROOT)
SHARED="${DEPLOY_SHARED_ROOT:-${REPO_ROOT}/shared}"

# fallback if repo layout differs : ${VAR:-default} above, then re-point SHARED 
if [[ ! -f "${SHARED}/constants.sh"]]; then 
    SHARED="${SCRIPT_DIR}/../shared"
fi 


