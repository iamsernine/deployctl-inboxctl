#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# inboxctl/inboxctl.sh — Local CLI to inspect remote deployctl state over SSH (read-only).
#
# Further reading (exam / study index):
#   Bash strict mode (-e -u pipefail): http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual: https://www.gnu.org/software/bash/manual/html_node/
#   BashGuide: https://mywiki.wooledge.org/BashGuide
#   ShellCheck (sourcing): https://www.shellcheck.net/wiki/

# =============================================================================
# Strict mode — same family as deployctl; see article for pitfalls (e.g. pipelines).
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

# =============================================================================
# Paths: script dir, shared contracts, optional INBOX_SHARED_ROOT override.
# Study: https://mywiki.wooledge.org/BashFAQ/028
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SHARED="${INBOX_SHARED_ROOT:-${REPO_ROOT}/shared}"

# Study: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
if [[ ! -f "${SHARED}/constants.sh" ]]; then
    SHARED="${SCRIPT_DIR}/../shared"
fi

# =============================================================================
# Shared + inbox modules (sourced into this shell).
# Study: https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html#index-source
# =============================================================================
# shellcheck source=/dev/null
source "${SHARED}/constants.sh"
# shellcheck source=/dev/null
source "${SHARED}/format.sh"
# shellcheck source=/dev/null
source "${SHARED}/validators.sh"

# =============================================================================
# Feature modules (SSH, cache, fetch, UI, …).
# Study: https://mywiki.wooledge.org/BashGuide/CompoundCommands#Loops
# =============================================================================
INBOX_LIB="${SCRIPT_DIR}/lib"
for _mod in mod_error.sh mod_server.sh mod_ssh.sh mod_cache.sh mod_fetch.sh mod_parse.sh mod_ui.sh mod_watch.sh mod_cli.sh; do
    # shellcheck source=/dev/null
    source "${INBOX_LIB}/${_mod}"
done

# -----------------------------------------------------------------------------
# inboxctl_cmd_add_server
# Args: name, user@host
# Study: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html#index-_003a_003f-
# -----------------------------------------------------------------------------
inboxctl_cmd_add_server() {
    local name="${1:?}"
    local target="${2:?}"
    validate_app_name "$name" || {
        inboxctl_exit_with_error "$ERR_INVALID_APP_NAME" "invalid server name (use kebab-case like app names)"
    }
    inboxctl_write_server_conf "$name" "$target"
    printf 'inboxctl: added server %s → %s\n' "$name" "$target"
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_cmd_remove_server
# Study: https://www.gnu.org/software/bash/manual/html_node/Command-Substitution.html ($( ) for paths)
# -----------------------------------------------------------------------------
inboxctl_cmd_remove_server() {
    local name="${1:?}"
    inboxctl_remove_server_conf "$name"
    rm -rf "$(inboxctl_cache_root_for_server "$name")"
    printf 'inboxctl: removed server %s\n' "$name"
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_cmd_list_servers
# Study: delegation — thin wrapper calling library (single responsibility).
# -----------------------------------------------------------------------------
inboxctl_cmd_list_servers() {
    inboxctl_list_server_names
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_cmd_show_servers
# Study: https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html (nullglob)
# -----------------------------------------------------------------------------
inboxctl_cmd_show_servers() {
    shopt -s nullglob
    local p
    for p in "${INBOXCTL_SERVERS_DIR}"/*.conf; do
        printf '--- %s ---\n' "$(basename "${p%.conf}")"
        cat "$p"
        printf '\n'
    done
    shopt -u nullglob
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_cmd_test
# Study: https://man.openbsd.org/ssh.1 (BatchMode); exit status as contract (ERR_SSH_FAILED)
# -----------------------------------------------------------------------------
inboxctl_cmd_test() {
    local name="${1:?}"
    if inboxctl_ssh_test_connection "$name"; then
        printf 'inboxctl: SSH OK for %s\n' "$name"
        return 0
    fi
    inboxctl_exit_with_error "$ERR_SSH_FAILED" "SSH failed for ${name}"
}

# -----------------------------------------------------------------------------
# inboxctl_cmd_fetch
# Study: scp over SSH — https://man.openbsd.org/scp.1
# -----------------------------------------------------------------------------
inboxctl_cmd_fetch() {
    local name="${1:?}"
    inboxctl_fetch_server_data "$name"
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_cmd_show_projects
# Study: cache-as-source-of-truth; https://mywiki.wooledge.org/BashGuide/TestsAndConditionals
# -----------------------------------------------------------------------------
inboxctl_cmd_show_projects() {
    local name="${1:?}"
    local cache
    cache="$(inboxctl_cache_root_for_server "$name")"
    if [[ ! -d "$cache/projects.d" ]]; then
        inboxctl_exit_with_error "$ERR_MISSING_PARAM" "no cache; run: inboxctl fetch ${name}"
    fi
    inboxctl_ui_print_projects_table "$cache"
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_cmd_show_bucket
# Study: reuse UI filter by STATUS_* constants from shared/constants.sh
# -----------------------------------------------------------------------------
inboxctl_cmd_show_bucket() {
    local bucket="$1"
    local name="$2"
    local cache
    cache="$(inboxctl_cache_root_for_server "$name")"
    inboxctl_ui_filter_status "$cache" "$bucket"
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_cmd_logs
# Study: POSIX tail — https://pubs.opengroup.org/onlinepubs/9699919799/utilities/tail.html
# -----------------------------------------------------------------------------
inboxctl_cmd_logs() {
    local name="${1:?}"
    local app="${2:?}"
    local cache f
    cache="$(inboxctl_cache_root_for_server "$name")"
    f="${cache}/logs/projects/${app}.log"
    if [[ ! -f "$f" ]]; then
        inboxctl_exit_with_error "$ERR_MISSING_PARAM" "log not cached for ${app}; run fetch"
    fi
    tail -n 80 "$f"
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_cmd_errors
# Study: https://www.gnu.org/software/bash/manual/html_node/Lists.html (cmd1 || cmd2 if first fails)
# -----------------------------------------------------------------------------
inboxctl_cmd_errors() {
    local name="${1:?}"
    local cache h
    cache="$(inboxctl_cache_root_for_server "$name")"
    h="${cache}/history.log"
    if [[ ! -f "$h" ]]; then
        inboxctl_exit_with_error "$ERR_MISSING_PARAM" "no history cached; run fetch"
    fi
    grep ' : ERROR : ' "$h" || printf '(no ERROR lines)\n'
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_cmd_watch
# Study: https://www.gnu.org/software/bash/manual/html_node/Looping-Constructs.html (while)
# -----------------------------------------------------------------------------
inboxctl_cmd_watch() {
    local name="${1:?}"
    inboxctl_watch_server "$name"
    return 0
}

# -----------------------------------------------------------------------------
# inboxctl_dispatch
# Nested case for `show` subcommands — common CLI pattern.
# Study: https://www.gnu.org/software/bash/manual/html_node/Compound-Commands.html#index-case
# -----------------------------------------------------------------------------
inboxctl_dispatch() {
    local cmd="${1:-help}"
    shift || true
    case "$cmd" in
        add-server)
            inboxctl_cmd_add_server "${1:-}" "${2:-}"
            ;;
        remove-server)
            inboxctl_cmd_remove_server "${1:-}"
            ;;
        list)
            [[ "${1:-}" == "servers" ]] || {
                inboxctl_exit_with_error "$ERR_MISSING_PARAM" "use: list servers"
            }
            inboxctl_cmd_list_servers
            ;;
        show)
            local sub="${1:-}"
            shift || true
            case "$sub" in
                servers) inboxctl_cmd_show_servers ;;
                projects) inboxctl_cmd_show_projects "${1:-}" ;;
                live) inboxctl_cmd_show_bucket "$STATUS_LIVE" "${1:-}" ;;
                pending) inboxctl_cmd_show_bucket "$STATUS_PENDING" "${1:-}" ;;
                archive) inboxctl_cmd_show_bucket "$STATUS_ARCHIVE" "${1:-}" ;;
                *)
                    inboxctl_exit_with_error "$ERR_UNKNOWN_OPTION" "unknown show target"
                    ;;
            esac
            ;;
        test)
            inboxctl_cmd_test "${1:-}"
            ;;
        fetch)
            inboxctl_cmd_fetch "${1:-}"
            ;;
        logs)
            inboxctl_cmd_logs "${1:-}" "${2:-}"
            ;;
        errors)
            inboxctl_cmd_errors "${1:-}"
            ;;
        watch)
            inboxctl_cmd_watch "${1:-}"
            ;;
        version)
            printf 'inboxctl %s\n' "$DEPLOYCTL_INBOXCTL_VERSION"
            ;;
        help | --help | -h)
            inboxctl_print_usage
            ;;
        *)
            inboxctl_print_usage
            inboxctl_exit_with_error "$ERR_UNKNOWN_OPTION" "unknown command: ${cmd}"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# main
# Study: https://www.gnu.org/software/bash/manual/html_node/Set-Builtin.html (set --); Bash arrays
# -----------------------------------------------------------------------------
main() {
    inboxctl_ensure_config_dirs
    mkdir -p "${INBOXCTL_CACHE_DIR}" "${INBOXCTL_SERVER_CACHE_DIR}"
    inboxctl_parse_globals "$@"
    set -- "${INBOXCTL_ARGS[@]}"
    inboxctl_dispatch "$@"
}

main "$@"
