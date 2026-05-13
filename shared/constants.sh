#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# shared/constants.sh — Shared paths, statuses, naming, and error codes for deployctl and inboxctl.
# Single source of truth for cross-tool contracts; keep in sync with documentation.
#
# Further reading (exam / study index):
#   Bash strict mode (for callers that use set -euo): http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck: https://www.shellcheck.net/wiki/

# shellcheck shell=bash

# =============================================================================
# Versioning
# Study: https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html#index-readonly
# =============================================================================
readonly DEPLOYCTL_INBOXCTL_VERSION="1.0.0"

# =============================================================================
# deployctl filesystem paths (server-side)
# Study: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameters.html (constants as contract)
# =============================================================================
readonly DEPLOYCTL_ETC="/etc/deployctl"
readonly DEPLOYCTL_PROJECTS_DIR="/etc/deployctl/projects.d"
readonly DEPLOYCTL_VAR="/var/lib/deployctl"
readonly DEPLOYCTL_APPS_DIR="/var/lib/deployctl/apps"
readonly DEPLOYCTL_PENDING_DIR="/var/lib/deployctl/apps/pending"
readonly DEPLOYCTL_LIVE_DIR="/var/lib/deployctl/apps/live"
readonly DEPLOYCTL_ARCHIVE_DIR="/var/lib/deployctl/apps/archive"
readonly DEPLOYCTL_ENV_DIR="/var/lib/deployctl/env"
readonly DEPLOYCTL_STATE_DIR="/var/lib/deployctl/state"
readonly DEPLOYCTL_LOG_DIR="/var/log/deployctl"
readonly DEPLOYCTL_HISTORY_LOG="/var/log/deployctl/history.log"
readonly DEPLOYCTL_PROJECT_LOG_DIR="/var/log/deployctl/projects"
readonly DEPLOYCTL_CACHE_DIR="/var/cache/deployctl"
readonly DEPLOYCTL_BUILD_DIR="/var/cache/deployctl/builds"

# =============================================================================
# inboxctl paths (local user)
# Study: https://www.gnu.org/software/bash/manual/html_node/Tilde-Expansion.html (${HOME})
# =============================================================================
readonly INBOXCTL_CONFIG_DIR="${HOME}/.config/inboxctl"
readonly INBOXCTL_SERVERS_DIR="${HOME}/.config/inboxctl/servers.d"
readonly INBOXCTL_CACHE_DIR="${HOME}/.cache/inboxctl"
readonly INBOXCTL_SERVER_CACHE_DIR="${HOME}/.cache/inboxctl/servers"

# =============================================================================
# Application lifecycle statuses
# Study: https://mywiki.wooledge.org/BashGuide/CompoundCommands#Patterns (case / string sets)
# =============================================================================
readonly STATUS_PENDING="pending"
readonly STATUS_LIVE="live"
readonly STATUS_ARCHIVE="archive"
readonly STATUS_ERROR="error"

# Ordered list for validation iteration
readonly ALLOWED_STATUSES="${STATUS_PENDING} ${STATUS_LIVE} ${STATUS_ARCHIVE} ${STATUS_ERROR}"

# =============================================================================
# Docker / network naming
# Study: Docker naming: https://docs.docker.com/engine/containers/container-networking/
# =============================================================================
readonly CONTAINER_PREFIX="deployctl_"
readonly IMAGE_PREFIX="deployctl/"
readonly NETWORK_NAME="deployctl_net"

# =============================================================================
# Numeric exit codes (contract with exit_with_error)
# Study: https://mywiki.wooledge.org/BashGuide/Practices#Exit_codes (meaningful exit statuses)
# =============================================================================
readonly ERR_UNKNOWN_OPTION=100
readonly ERR_MISSING_PARAM=101
readonly ERR_INVALID_APP_NAME=102
readonly ERR_INVALID_DOMAIN=103
readonly ERR_PORT_IN_USE=104
readonly ERR_DOCKERFILE_MISSING=105
readonly ERR_ENV_EXAMPLE_MISSING=106
readonly ERR_DOCKER_BUILD_FAILED=107
readonly ERR_CONTAINER_RUN_FAILED=108
readonly ERR_HEALTH_CHECK_FAILED=109
readonly ERR_NGINX_CONFIG_FAILED=110
readonly ERR_SSL_FAILED=111
readonly ERR_NOT_ROOT=112
readonly ERR_SSH_FAILED=113
readonly ERR_CONFIG_PARSE_ERROR=114
readonly ERR_UNKNOWN_STATUS=115
readonly ERR_DEPENDENCY_MISSING=116
readonly ERR_GIT_CLONE_FAILED=117
readonly ERR_FILE_PERMISSION_ERROR=118
readonly ERR_ARCHIVE_FAILED=119
readonly ERR_RESTORE_FAILED=120
