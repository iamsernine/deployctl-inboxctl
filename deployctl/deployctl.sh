#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Project: deployctl-inboxctl
# SPDX-License-Identifier: MIT (see LICENSE)
# Maintainer: YOUR_NAME <YOUR_EMAIL>
# Repository: https://github.com/YOUR_ORG/YOUR_REPO
# ------------------------------------------------------------------------------
#
# deployctl/deployctl.sh — Server-side CLI entrypoint for Docker monolith deployments.
# Sources shared contracts and modular libraries; dispatches subcommands.
#
# Further reading (exam / study index):
#   Bash strict mode (-e -u pipefail): http://redsymbol.net/articles/unofficial-bash-strict-mode/
#   Bash manual (parameters, [[ ]], case): https://www.gnu.org/software/bash/manual/html_node/
#   BashFAQ & pitfalls: https://mywiki.wooledge.org/BashGuide
#   ShellCheck wiki (e.g. sourcing): https://www.shellcheck.net/wiki/

# =============================================================================
# Strict mode: exit on failed command (-e), unset vars are errors (-u),
# pipelines propagate failure (-o pipefail). Trade-offs in the article below.
# Study: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# =============================================================================
set -euo pipefail

# =============================================================================
# Bootstrap paths: resolve this script's directory (not cwd). ${BASH_SOURCE[0]}
# is the path to the current file when sourced or executed.
# Study: https://mywiki.wooledge.org/BashFAQ/028 (getting script's location)
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SHARED="${DEPLOY_SHARED_ROOT:-${REPO_ROOT}/shared}"

# Fallback if repo layout differs: ${VAR:-default} above, then re-point SHARED.
# Study: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
if [[ ! -f "${SHARED}/constants.sh" ]]; then
    SHARED="${SCRIPT_DIR}/../shared"
fi

# =============================================================================
# Shared layer: constants, formatting, validators. "source" runs in the same
# shell (defines functions/vars). shellcheck source=/dev/null silences SC1091
# when the path is dynamic.
# Study: https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html#index-source
#        https://www.shellcheck.net/wiki/SC1091
# =============================================================================
# shellcheck source=/dev/null
source "${SHARED}/constants.sh"
# shellcheck source=/dev/null
source "${SHARED}/format.sh"
# shellcheck source=/dev/null
source "${SHARED}/validators.sh"

# =============================================================================
# Feature modules: one file per concern (docker, nginx, …). Loop + source keeps
# this entrypoint small; order can matter if modules depend on earlier ones.
# Study: https://mywiki.wooledge.org/BashGuide/CompoundCommands#Loops
# =============================================================================
DEPLOYCTL_LIB="${SCRIPT_DIR}/lib"
for _mod in mod_log.sh mod_error.sh mod_cli.sh mod_check.sh mod_env.sh mod_git.sh mod_docker.sh mod_health.sh mod_nginx.sh mod_archive.sh mod_restore.sh mod_menu.sh; do
    # shellcheck source=/dev/null
    source "${DEPLOYCTL_LIB}/${_mod}"
done

# -----------------------------------------------------------------------------
# deployctl_write_project_conf
# Writes /etc/deployctl/projects.d/<app>.conf from current deployment context.
# Args: key deployment fields via positional or env-style — uses explicit args below.
# Returns: 0
# Study: https://www.gnu.org/software/bash/manual/html_node/Local-Builtins.html#index-local
#        https://www.gnu.org/software/bash/manual/html_node/Command-Grouping.html ( { } >file )
# -----------------------------------------------------------------------------
deployctl_write_project_conf() {
    local app="$1"
    local repo="$2"
    local domain="$3"
    local port="$4"
    local dockerfile="$5"
    local ssl_en="$6"
    local status="$7"
    local env_file="${DEPLOYCTL_ENV_DIR}/${app}.env"
    local app_dir="${DEPLOYCTL_LIVE_DIR}/${app}"
    local container="${CONTAINER_PREFIX}${app}"
    local image="${IMAGE_PREFIX}${app}:latest"
    local now
    now="$(current_timestamp)"

    local out="${DEPLOYCTL_PROJECTS_DIR}/${app}.conf"
    mkdir -p "$DEPLOYCTL_PROJECTS_DIR"
    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_project_info "$app" "[dry-run] would write project conf ${out}"
        return 0
    fi
    local prev_created=""
    if [[ -f "$out" ]]; then
        prev_created="$(read_conf_value "$out" CREATED_AT)" || prev_created=""
    fi
    {
        printf '%s\n' "# deployctl project metadata"
        printf 'APP_NAME=%s\n' "$app"
        printf 'REPO_URL=%s\n' "$repo"
        printf 'DOMAIN=%s\n' "$domain"
        printf 'PORT=%s\n' "$port"
        printf 'DOCKERFILE_PATH=%s\n' "$dockerfile"
        printf 'ENV_FILE=%s\n' "$env_file"
        printf 'APP_DIR=%s\n' "$app_dir"
        printf 'STATUS=%s\n' "$status"
        printf 'SSL_ENABLED=%s\n' "$ssl_en"
        printf 'CONTAINER_NAME=%s\n' "$container"
        printf 'IMAGE_NAME=%s\n' "$image"
        printf 'CREATED_AT=%s\n' "${prev_created:-$now}"
        printf 'LAST_DEPLOY=%s\n' "$now"
    } >"$out"
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_parse_deploy_argv
# Parses deploy subcommand arguments into globals.
# Sets: DEPLOY_ARG_APP, DEPLOY_ARG_REPO, DEPLOY_ARG_DOMAIN, DEPLOY_ARG_PORT, DEPLOY_ARG_SSL
# Returns: 0
# Study: https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html#index-case
#        https://www.gnu.org/software/bash/manual/html_node/Shell-Builtin-Commands.html#index-shift
# -----------------------------------------------------------------------------
deployctl_parse_deploy_argv() {
    DEPLOY_ARG_APP=""
    DEPLOY_ARG_REPO=""
    DEPLOY_ARG_DOMAIN=""
    DEPLOY_ARG_PORT=""
    DEPLOY_ARG_SSL="no"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo)
                DEPLOY_ARG_REPO="$2"
                shift 2
                ;;
            --domain)
                DEPLOY_ARG_DOMAIN="$2"
                shift 2
                ;;
            --port)
                DEPLOY_ARG_PORT="$2"
                shift 2
                ;;
            --ssl)
                DEPLOY_ARG_SSL="$2"
                shift 2
                ;;
            *)
                if [[ -z "$DEPLOY_ARG_APP" ]]; then
                    DEPLOY_ARG_APP="$1"
                    shift
                else
                    exit_with_error "$ERR_UNKNOWN_OPTION" "unexpected deploy argument: $1"
                fi
                ;;
        esac
    done
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_cmd_check
# Verifies dependencies and directory layout.
# Returns: 0 on success
# Study: https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html#index-_005b_005b
#        https://mywiki.wooledge.org/BashGuide/TestsAndConditionals (if ! cmd)
# -----------------------------------------------------------------------------
deployctl_cmd_check() {
    init_logs
    log_info "deployctl check starting"
    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_info "[dry-run] dependency checks skipped (docker/git/nginx/curl/ss)"
        deployctl_ensure_layout || true
        log_info "deployctl check OK (dry-run)"
        return 0
    fi
    if ! deployctl_check_dependencies; then
        exit_with_error "$ERR_DEPENDENCY_MISSING" "dependency check failed"
    fi
    if [[ "${DEPLOYCTL_DRY_RUN:-0}" != "1" ]] && ! require_root; then
        log_error "check: not root — some paths may be inaccessible"
    fi
    deployctl_ensure_layout || exit_with_error "$ERR_FILE_PERMISSION_ERROR" "layout failed"
    log_info "deployctl check OK"
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_cmd_deploy
# Full deployment pipeline with rollback on failure.
# Args: remaining args from deploy subcommand
# Returns: does not return on fatal error
# Study: https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html#index-read
#        https://mywiki.wooledge.org/BashGuide/InputAndOutput (read -r, prompts on stderr)
# -----------------------------------------------------------------------------
deployctl_cmd_deploy() {
    init_logs
    deployctl_parse_deploy_argv "$@"

    local app="${DEPLOY_ARG_APP}"
    local repo="${DEPLOY_ARG_REPO}"
    local domain="${DEPLOY_ARG_DOMAIN}"
    local port="${DEPLOY_ARG_PORT}"
    local ssl="${DEPLOY_ARG_SSL}"

    while [[ -z "$app" ]]; do
        printf 'Application name (kebab-case): ' >&2
        read -r app || true
    done
    validate_app_name "$app" || exit_with_error "$ERR_INVALID_APP_NAME" "invalid app name"

    while [[ -z "$repo" ]]; do
        printf 'Git repository URL: ' >&2
        read -r repo || true
    done

    while [[ -z "$domain" ]]; do
        printf 'Public domain: ' >&2
        read -r domain || true
    done
    validate_domain "$domain" || exit_with_error "$ERR_INVALID_DOMAIN" "invalid domain"

    while [[ -z "$port" ]]; do
        printf 'Host/container TCP port: ' >&2
        read -r port || true
    done
    validate_port "$port" || exit_with_error "$ERR_MISSING_PARAM" "invalid port"

    if [[ "${DEPLOYCTL_DRY_RUN:-0}" == "1" ]]; then
        log_info "[dry-run] deploy pipeline for '${app}' skipped (no clone/build/run/nginx)"
        return 0
    fi

    require_root || exit_with_error "$ERR_NOT_ROOT" "deploy requires root"

    if ! deployctl_check_port_free "$port"; then
        exit_with_error "$ERR_PORT_IN_USE" "port ${port} appears in use"
    fi

    deployctl_check_dependencies || exit_with_error "$ERR_DEPENDENCY_MISSING" "missing dependency"
    deployctl_ensure_layout || exit_with_error "$ERR_FILE_PERMISSION_ERROR" "cannot create dirs"

    local pending="${DEPLOYCTL_PENDING_DIR}/${app}"
    DEPLOYCTL_ROLLBACK_APP="$app"
    DEPLOYCTL_ROLLBACK_PENDING_DIR="$pending"
    DEPLOYCTL_ROLLBACK_CONTAINER="${CONTAINER_PREFIX}${app}"

    local dockerfile="Dockerfile"
    local df_full=""

    deployctl_git_clone_repo "$repo" "$pending" || exit_with_error "$ERR_GIT_CLONE_FAILED" "clone failed"

    df_full="${pending}/${dockerfile}"
    if [[ ! -f "$df_full" ]]; then
        cleanup_on_error
        exit_with_error "$ERR_DOCKERFILE_MISSING" "Dockerfile not found in repo"
    fi

    if [[ -f "${pending}/.env.example" ]]; then
        if ! deployctl_collect_env_from_example "$app" "$pending"; then
            cleanup_on_error
            exit_with_error "$ERR_ENV_EXAMPLE_MISSING" "env creation failed"
        fi
    else
        deployctl_collect_env_interactive_full "$app" || true
    fi

    if ! deployctl_docker_build "$app" "$pending" "$dockerfile"; then
        cleanup_on_error
        exit_with_error "$ERR_DOCKER_BUILD_FAILED" "build failed"
    fi

    if ! deployctl_docker_run_app "$app" "$port" "$port"; then
        cleanup_on_error
        exit_with_error "$ERR_CONTAINER_RUN_FAILED" "run failed"
    fi

    if ! deployctl_health_check_app "$app" "$port"; then
        cleanup_on_error
        exit_with_error "$ERR_HEALTH_CHECK_FAILED" "health failed"
    fi

    if ! deployctl_nginx_render_config "$app" "$domain" "$port"; then
        cleanup_on_error
        exit_with_error "$ERR_NGINX_CONFIG_FAILED" "nginx write failed"
    fi

    if ! deployctl_nginx_test_and_reload "$app"; then
        cleanup_on_error
        exit_with_error "$ERR_NGINX_CONFIG_FAILED" "nginx test/reload failed"
    fi

    if [[ "$ssl" == "yes" ]] || [[ "$ssl" == "true" ]]; then
        if ! deployctl_run_certbot_optional "$domain" "$app"; then
            log_project_error "$app" "SSL step failed (deployment continues)"
        fi
    fi

    mkdir -p "$DEPLOYCTL_LIVE_DIR"
    if [[ -d "${DEPLOYCTL_LIVE_DIR}/${app}" ]]; then
        rm -rf "${DEPLOYCTL_LIVE_DIR}/${app}.old" 2>/dev/null || true
        mv "${DEPLOYCTL_LIVE_DIR}/${app}" "${DEPLOYCTL_LIVE_DIR}/${app}.old" || true
    fi
    mv "$pending" "${DEPLOYCTL_LIVE_DIR}/${app}"

    deployctl_write_project_conf "$app" "$repo" "$domain" "$port" "$dockerfile" "$ssl" "$STATUS_LIVE"
    printf '%s\n' "LAST_DEPLOY=$(current_timestamp)" >"${DEPLOYCTL_STATE_DIR}/${app}.state"

    DEPLOYCTL_ROLLBACK_NGINX_CONF=""
    DEPLOYCTL_ROLLBACK_PENDING_DIR=""
    DEPLOYCTL_ROLLBACK_CONTAINER=""
    DEPLOYCTL_ROLLBACK_APP=""

    log_project_info "$app" "deploy completed successfully"
    log_info "deploy ${app} completed"
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_cmd_status
# Args: $1=app
# Study: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html#index-_003a_003f-
#        (${var:?word} requires a value or exits)
# -----------------------------------------------------------------------------
deployctl_cmd_status() {
    local app="${1:?}"
    validate_app_name "$app" || exit_with_error "$ERR_INVALID_APP_NAME" "invalid app"
    local conf="${DEPLOYCTL_PROJECTS_DIR}/${app}.conf"
    [[ -f "$conf" ]] || exit_with_error "$ERR_CONFIG_PARSE_ERROR" "unknown app"
    local st port dom
    st="$(read_conf_value "$conf" STATUS)"
    port="$(read_conf_value "$conf" PORT)"
    dom="$(read_conf_value "$conf" DOMAIN)"
    printf '%s status=%s domain=%s port=%s\n' "$app" "$st" "$dom" "$port"
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_cmd_logs
# Args: $1=app — tails project log when possible
# Study: POSIX tail: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/tail.html
# -----------------------------------------------------------------------------
deployctl_cmd_logs() {
    local app="${1:?}"
    validate_app_name "$app" || exit_with_error "$ERR_INVALID_APP_NAME" "invalid app"
    local f="${DEPLOYCTL_PROJECT_LOG_DIR}/${app}.log"
    [[ -f "$f" ]] || exit_with_error "$ERR_MISSING_PARAM" "no log file yet"
    tail -n 100 "$f"
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_cmd_list
# Args: $1=pending|live|archive
# Study: https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html (nullglob)
#        https://mywiki.wooledge.org/glob#nullglob
# -----------------------------------------------------------------------------
deployctl_cmd_list() {
    local kind="${1:?}"
    local dir=""
    case "$kind" in
        pending) dir="$DEPLOYCTL_PENDING_DIR" ;;
        live) dir="$DEPLOYCTL_LIVE_DIR" ;;
        archive) dir="$DEPLOYCTL_ARCHIVE_DIR" ;;
        *) exit_with_error "$ERR_UNKNOWN_STATUS" "list needs pending|live|archive" ;;
    esac
    shopt -s nullglob
    local entry
    for entry in "${dir}"/*; do
        [[ -d "$entry" ]] && printf '%s\n' "$(basename "$entry")"
    done
    shopt -u nullglob
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_cmd_ssl
# Runs certbot for existing app domain from conf.
# Study: command substitution $(...) — https://www.gnu.org/software/bash/manual/html_node/Command-Substitution.html
# -----------------------------------------------------------------------------
deployctl_cmd_ssl() {
    require_root || exit_with_error "$ERR_NOT_ROOT" "ssl command requires root"
    local app="${1:?}"
    local conf="${DEPLOYCTL_PROJECTS_DIR}/${app}.conf"
    [[ -f "$conf" ]] || exit_with_error "$ERR_CONFIG_PARSE_ERROR" "unknown app"
    local domain
    domain="$(read_conf_value "$conf" DOMAIN)"
    deployctl_run_certbot_optional "$domain" "$app" || exit_with_error "$ERR_SSL_FAILED" "certbot failed"
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_cmd_archive
# Study: https://www.gnu.org/software/bash/manual/html_node/Shell-Functions.html
#        (compose CLI from small functions; fail fast with exit_with_error)
# -----------------------------------------------------------------------------
deployctl_cmd_archive() {
    require_root || exit_with_error "$ERR_NOT_ROOT" "archive requires root"
    init_logs
    local app="${1:?}"
    validate_app_name "$app" || exit_with_error "$ERR_INVALID_APP_NAME" "invalid app"
    deployctl_archive_app "$app" || exit_with_error "$ERR_ARCHIVE_FAILED" "archive failed"
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_cmd_restore
# Study: https://www.gnu.org/software/bash/manual/html_node/Shell-Functions.html
#        https://mywiki.wooledge.org/BashGuide/Practices#errexit (|| exit_with_error)
# -----------------------------------------------------------------------------
deployctl_cmd_restore() {
    require_root || exit_with_error "$ERR_NOT_ROOT" "restore requires root"
    init_logs
    local app="${1:?}"
    validate_app_name "$app" || exit_with_error "$ERR_INVALID_APP_NAME" "invalid app"
    deployctl_restore_app "$app" || exit_with_error "$ERR_RESTORE_FAILED" "restore failed"
    return 0
}

# -----------------------------------------------------------------------------
# deployctl_dispatch
# Routes subcommand after global parsing.
# Study: https://www.gnu.org/software/bash/manual/html_node/Compound-Commands.html#index-case
#        Subshell ( ... ) vs background & : https://www.gnu.org/software/bash/manual/html_node/Lists.html
# -----------------------------------------------------------------------------
deployctl_dispatch() {
    local cmd="${1:-}"
    shift || true
    case "$cmd" in
        "")
            deployctl_print_usage
            exit 1
            ;;
        check)
            deployctl_cmd_check
            ;;
        deploy)
            if [[ "${DEPLOYCTL_SUBSHELL_MODE:-0}" == "1" ]]; then
                ( deployctl_cmd_deploy "$@" )
            elif [[ "${DEPLOYCTL_FORK_MODE:-0}" == "1" ]]; then
                deployctl_cmd_deploy "$@" &
                wait $!
            else
                deployctl_cmd_deploy "$@"
            fi
            ;;
        status)
            deployctl_cmd_status "${1:-}"
            ;;
        logs)
            deployctl_cmd_logs "${1:-}"
            ;;
        archive)
            deployctl_cmd_archive "${1:-}"
            ;;
        restore)
            deployctl_cmd_restore "${1:-}"
            ;;
        list)
            deployctl_cmd_list "${1:-}"
            ;;
        ssl)
            deployctl_cmd_ssl "${1:-}"
            ;;
        menu)
            deployctl_run_menu
            ;;
        version)
            printf 'deployctl %s\n' "$DEPLOYCTL_INBOXCTL_VERSION"
            ;;
        help | --help)
            deployctl_print_usage
            ;;
        errors-help)
            show_error_help
            ;;
        *)
            exit_with_error "$ERR_UNKNOWN_OPTION" "unknown command: $cmd"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# main
# Re-applies argv after global option parsing (set -- …).
# Study: https://www.gnu.org/software/bash/manual/html_node/Set-Builtin.html (set --)
#        https://www.gnu.org/software/bash/manual/html_node/Special-Parameters.html (positional params)
# -----------------------------------------------------------------------------
main() {
    deployctl_parse_global_options "$@"
    set -- "${REMAINING_ARGS[@]}"
    if [[ "${DEPLOYCTL_RESTORE_MODE:-0}" == "1" ]] && [[ "${1:-}" != "restore" ]] && [[ "${1:-}" != "check" ]]; then
        require_root || exit_with_error "$ERR_NOT_ROOT" "restore-mode requires root"
    fi
    deployctl_dispatch "$@"
}

main "$@"
