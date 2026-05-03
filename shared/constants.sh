#!/usr/bin/env bash 
#
# ------------------------------------------------------------------------------
# project: deployctl-inboxctl: deployctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: BEN YAMNA Mohammed <iamsernine@gmail.com>
# Repository: https://github.com/iamsernine/deployctl-inboxctl
# ------------------------------------------------------------------------------
#
# shared/constants.sh Shared paths, statuses, naming, and error codes for deployctl and inboxctl 
# single source of truth for cross-tool contracts; keep in sync with documentation 

# shellcheck shell=bash 
# read https://www.shellcheck.net/wiki/ about shellcheck

# =============================================================================
# Versioning 
# =============================================================================
readonly DEPLOYCTL_INBOXCTL_VERSION="1.0.0"

# =============================================================================
# deployctl filesystem paths (server-side) 
# =============================================================================

# main config folder for deployctl
readonly DEPLOYCTL_ETC="/etc/deployctl"

# projects config files 
readonly DEPLOYCTL_PROJECTS_DIR="/etc/deployctl/projects.d"

# main data folder for deployctl
readonly DEPLOYCTL_VAR="/var/lib/deployctl"

# all apps floder 
readonly DEPLOYCTL_APPS_DIR="/var/lib/deployctl/apps"

# apps waiting to be deployed 
readonly DEPLOYCTL_PENDING_DIR="/var/lib/deployctl/apps/pending"

# apps currently running 
readonly DEPLOYCTL_LIVE_DIR="/var/lib/deployctl/apps/live"

# archived apps 
readonly DEPLOYCTL_ARCHIVE_DIR="/var/lib/deployctl/apps/archive"

# environement files (.env)
readonly DEPLOYCTL_ENV_DIR="/var/lib/deployctl/env"

# state tracking files 
readonly DEPLOYCTL_STATE_DIR="/var/lib/deployctl/state"

# logs folder 
readonly DEPLOYCTL_LOG_DIR="/var/log/deployctl"

# global history log file 
readonly DEPLOYCTL_HISTORY_LOG="/var/log/deployctl/history.log"

# logs per project 
readonly DEPLOYCTL_PROJECT_LOG_DIR="/var/log/deployctl/projects"

# cache folder 
readonly DEPLOYCTL_CACHE_DIR="/var/cache/deployctl"

# temporary builds folder 
readonly DEPLOYCTL_BUILD_DIR="/var/cache/deployctl/builds"

# =============================================================================
# inboxctl paths (local user)
# =============================================================================

# inboxctl config folder 
readonly INBOXCTL_CONFIG_DIR="${HOME}/.config/inboxctl"

# servers config files 
readonly INBOXCTL_SERVERS_DIR="${HOME}/.config/inboxctl/servers.d"

# inboxctl cache folder 
readonly INBOXCTL_CACHE_DIR="${HOME}/.cache/inboxctl"

# server cache 
readonly INBOXCTL_SERVER_CACHE_DIR="${HOME}/.cache/inboxctl/servers"

# =============================================================================
# Application lifecycle statuses
# =============================================================================

# app is waiting 
readonly STATUS_PENDING="pending"

# app is running
readonly STATUS_LIVE="live"

# app is archived
readonly STATUS_ARCHIVE="archive"

# app has error
readonly STATUS_ERROR="error"

# allowed statuses list
readonly ALLOWED_STATUSES="${STATUS_PENDING} ${STATUS_LIVE} ${STATUS_ARCHIVE} ${STATUS_ERROR}"

# =============================================================================
# Docker / network naming
# =============================================================================

# docker container prefix 
readonly CONTAINER_PREFIX="deployctl_"

# docker image prefix
readonly IMAGE_PREFIX="deployctl/"

# docker network name 
readonly NETWORK_NAME="deployctl_net"

# =============================================================================
# Numeric exit codes (contract with exit_with_error)
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

