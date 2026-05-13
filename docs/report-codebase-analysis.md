# 1. Project overview

`deployctl-inboxctl` is a Bash project composed of two command-line tools:

- `deployctl`: a server-side deployment helper for a single VPS. It clones an application from Git, prepares environment variables, builds a Docker image, runs a Docker container, checks health, writes an nginx reverse-proxy configuration, optionally runs certbot, and stores project metadata.
- `inboxctl`: a workstation-side inspection tool. It connects to a remote server by SSH and copies deployctl metadata and logs into a local cache so the operator can review deployment state without modifying the server.

The real user need is simple operational deployment and supervision for small teams that do not need Kubernetes or a large platform-as-a-service. The project tries to make one-server Docker deployments predictable and auditable.

The typical `deployctl` user is a server administrator or DevOps/operator with root access on the VPS. This user performs sensitive actions: writing under `/etc`, `/var/lib`, `/var/log`, managing Docker containers, and reloading nginx.

The typical `inboxctl` user is a developer, teacher, reviewer, or operator on a local workstation. This user needs visibility into project status and logs but should not directly mutate remote deployctl state.

The two tools complement each other through shared filesystem contracts:

- `deployctl` writes metadata to `/etc/deployctl/projects.d/<app>.conf`.
- `deployctl` writes global logs to `/var/log/deployctl/history.log`.
- `deployctl` writes project logs to `/var/log/deployctl/projects/<app>.log`.
- `inboxctl` fetches those remote files over SSH/SCP into `~/.cache/inboxctl/servers/<server>/`.
- Both tools source shared constants, validators, and formatting helpers from `shared/`.

# 2. Repository structure

Directory tree found in the repository:

```text
deployctl-inboxctl/
|-- .github/
|   `-- workflows/
|       `-- ci.yml
|-- deployctl/
|   |-- deployctl.sh
|   |-- install.sh
|   |-- uninstall.sh
|   |-- examples/
|   |   |-- demo-app.conf
|   |   `-- demo.env.example
|   |-- lib/
|   |   |-- mod_archive.sh
|   |   |-- mod_check.sh
|   |   |-- mod_cli.sh
|   |   |-- mod_docker.sh
|   |   |-- mod_env.sh
|   |   |-- mod_error.sh
|   |   |-- mod_git.sh
|   |   |-- mod_health.sh
|   |   |-- mod_log.sh
|   |   |-- mod_menu.sh
|   |   |-- mod_nginx.sh
|   |   `-- mod_restore.sh
|   |-- templates/
|   |   |-- nginx.conf.tpl
|   |   |-- project.conf.tpl
|   |   `-- restore.txt.tpl
|   `-- tests/
|       |-- test_heavy.sh
|       |-- test_light.sh
|       `-- test_medium.sh
|-- docs/
|   |-- architecture.md
|   |-- benchmark.md
|   |-- cahier-de-charge.md
|   |-- project-information.md
|   |-- README.md
|   |-- report.tex
|   |-- troubleshooting.md
|   `-- diagrams/
|       `-- .gitkeep
|-- inboxctl/
|   |-- inboxctl.sh
|   |-- install.sh
|   |-- uninstall.sh
|   |-- examples/
|   |   `-- servers.conf.example
|   |-- lib/
|   |   |-- mod_cache.sh
|   |   |-- mod_cli.sh
|   |   |-- mod_fetch.sh
|   |   |-- mod_parse.sh
|   |   |-- mod_server.sh
|   |   |-- mod_ssh.sh
|   |   |-- mod_ui.sh
|   |   `-- mod_watch.sh
|   |-- templates/
|   |   `-- server.conf.tpl
|   `-- tests/
|       |-- test_parse_conf.sh
|       `-- test_parse_logs.sh
|-- scripts/
|   |-- check-docs.sh
|   |-- demo.sh
|   |-- embed-project-headers.ps1
|   |-- format.sh
|   |-- lint.sh
|   `-- verify-format.sh
|-- shared/
|   |-- constants.sh
|   |-- format.sh
|   `-- validators.sh
|-- README.md
|-- AUTHORS.md
|-- CODE_OF_CONDUCT.md
|-- CONTRIBUTING.md
|-- LICENSE
`-- SECURITY.md
```

Folder and file roles:

| Path | Role | Why it exists | Used by |
|---|---|---|---|
| `README.md` | Main project documentation | Introduces purpose, installation, quick start, commands, security notes, tests | Human users, report writers |
| `.github/workflows/ci.yml` | GitHub Actions workflow | Runs format checks, lint, docs check, and test scripts | GitHub CI |
| `shared/constants.sh` | Shared constants | Defines version, standard paths, statuses, Docker names, error codes | `deployctl.sh`, `inboxctl.sh`, tests |
| `shared/format.sh` | Formatting and simple config I/O | Provides timestamps, log line format, table output, key/value file helpers | Logging, parsers, UI, tests |
| `shared/validators.sh` | Validation helpers | Validates app names, domains, ports, status, commands, root user | Both CLIs and deploy modules |
| `deployctl/deployctl.sh` | Server CLI entry point | Sources shared files and deploy modules, dispatches commands | Executed as `deployctl` |
| `deployctl/lib/mod_cli.sh` | deployctl option parser and help | Implements `-h`, `-v`, `-n`, `-l`, `-f`, `-t`, `-s`, `-r` parsing | `deployctl.sh` |
| `deployctl/lib/mod_log.sh` | deployctl logging | Creates log directories and writes history/project logs | Deploy, check, archive, restore, errors |
| `deployctl/lib/mod_error.sh` | Fatal error and rollback helpers | Centralizes `exit_with_error`, error-code help, cleanup | Deploy and restore failure paths |
| `deployctl/lib/mod_check.sh` | Dependency/layout checks | Checks Docker, Git, nginx, curl, ss; creates standard directories | `check`, `deploy` |
| `deployctl/lib/mod_env.sh` | Environment file creation | Builds `/var/lib/deployctl/env/<app>.env` from `.env.example` or user input | `deploy` |
| `deployctl/lib/mod_git.sh` | Git clone helper | Clones app source into pending directory | `deploy`, `restore` |
| `deployctl/lib/mod_docker.sh` | Docker lifecycle | Builds images, creates network, runs/removes containers | `deploy`, `restore`, `archive` |
| `deployctl/lib/mod_health.sh` | Health checking | Tests `http://127.0.0.1:<port>/health`, then checks listening TCP port | `deploy`, `restore` |
| `deployctl/lib/mod_nginx.sh` | nginx config management | Renders nginx template, tests and reloads nginx, removes config | `deploy`, `restore`, rollback/archive cleanup |
| `deployctl/lib/mod_archive.sh` | Archive operation | Stops container, moves live app source to archive, updates metadata | `archive` command |
| `deployctl/lib/mod_restore.sh` | Restore/redeploy operation | Rebuilds archived app from stored metadata and env file | `restore`, `ssl`, deploy SSL step |
| `deployctl/lib/mod_menu.sh` | Interactive menu | Provides simple numeric menu for check/list/version | `menu` command |
| `deployctl/templates/*.tpl` | Reference/render templates | nginx config, project metadata shape, restore metadata | nginx/archive/reference docs |
| `deployctl/examples/*` | Example project metadata and env shape | Demonstrates config format without real secrets | Tests, docs, users |
| `deployctl/tests/*` | deployctl test scenarios | Light check, medium dry-run deploy, heavy execution-mode dry runs | CI, local QA |
| `deployctl/install.sh` | Server installer | Installs shared files and wrapper under `/usr/local`, creates system dirs | Administrators |
| `deployctl/uninstall.sh` | Server uninstaller | Removes installed files with confirmation | Administrators |
| `inboxctl/inboxctl.sh` | Workstation CLI entry point | Sources shared files and inbox modules, dispatches commands | Executed as `inboxctl` |
| `inboxctl/lib/mod_cli.sh` | inboxctl option parser and help | Implements `-h`, `-v`, command help | `inboxctl.sh` |
| `inboxctl/lib/mod_server.sh` | Local server config management | Writes/removes/lists `~/.config/inboxctl/servers.d/*.conf` | `add-server`, `remove-server`, `list servers`, `show servers` |
| `inboxctl/lib/mod_ssh.sh` | SSH helper | Reads target and tests key-based SSH | `test`, `fetch` |
| `inboxctl/lib/mod_cache.sh` | Local cache paths | Builds `~/.cache/inboxctl/servers/<name>` layout | `fetch`, `show`, `logs`, `watch` |
| `inboxctl/lib/mod_fetch.sh` | Remote fetch | Uses `scp` and `ssh` to copy remote deployctl metadata/logs | `fetch`, `watch` |
| `inboxctl/lib/mod_parse.sh` | Project metadata parser | Reads cached project `.conf` files and produces TSV rows | `show projects`, filters, tests |
| `inboxctl/lib/mod_ui.sh` | Terminal table display | Prints project tables and filters by status | `show projects`, `show live`, `show pending`, `show archive` |
| `inboxctl/lib/mod_watch.sh` | Periodic refresh | Repeats fetch/table display every few seconds | `watch` |
| `inboxctl/templates/server.conf.tpl` | Reference server config template | Documents local server config fields | Users/docs |
| `inboxctl/examples/servers.conf.example` | Example server config | Shows `SERVER_NAME`, `SSH_TARGET`, `CREATED_AT`, `LAST_FETCH` | Users/docs |
| `inboxctl/tests/*` | inboxctl parser/log tests | Validates metadata parsing and log format | CI, local QA |
| `scripts/lint.sh` | Bash lint driver | Runs `bash -n` on shell scripts and ShellCheck if installed | CI, developers |
| `scripts/format.sh` | Permission formatter | Applies executable bits to scripts/tests | CI, developers |
| `scripts/verify-format.sh` | Executable-bit verifier | Fails if key scripts are missing or not executable | CI |
| `scripts/check-docs.sh` | Documentation verifier | Ensures required docs exist and are non-empty | CI |
| `scripts/demo.sh` | Static demo sequence | Prints suggested classroom demo commands | Users/teacher |
| `scripts/embed-project-headers.ps1` | PowerShell helper | Appears intended to embed standard project headers | Maintainers |
| `docs/*.md` | Existing documentation | Architecture, benchmark, requirements, project info, troubleshooting | Report writer |
| `docs/report.tex` | Existing LaTeX report draft | A report artifact already present in the repository | Human report writer |

# 3. Main execution flow

## deployctl execution flow

When the user runs `deployctl`, the entry point is `deployctl/deployctl.sh`.

1. Bash strict mode is enabled with `set -euo pipefail`.
2. The script resolves its own location using `${BASH_SOURCE[0]}` and computes `SCRIPT_DIR`, `REPO_ROOT`, and `SHARED`.
3. It sources `shared/constants.sh`, `shared/format.sh`, and `shared/validators.sh`.
4. It loops over deployment modules in `deployctl/lib/` and sources them in a fixed order: logging, error handling, CLI parsing, checks, env, git, docker, health, nginx, archive, restore, menu.
5. `main "$@"` calls `deployctl_parse_global_options`.
6. Global options are converted into global flags such as `DEPLOYCTL_DRY_RUN`, `DEPLOYCTL_LOG_DIR_OVERRIDE`, `DEPLOYCTL_FORK_MODE`, `DEPLOYCTL_THREAD_MODE`, `DEPLOYCTL_SUBSHELL_MODE`, and `DEPLOYCTL_RESTORE_MODE`.
7. `main` then calls `deployctl_dispatch`.
8. `deployctl_dispatch` selects the command with a `case` statement.

For `deployctl check`:

1. `deployctl_cmd_check` calls `init_logs`.
2. If dry-run is active, dependency checks are skipped and directory creation is simulated.
3. Otherwise `deployctl_check_dependencies` checks `docker`, `git`, `nginx`, `curl`, and `ss`.
4. Non-root users receive a warning because some paths may not be accessible.
5. `deployctl_ensure_layout` creates `/etc/deployctl`, `/var/lib/deployctl`, `/var/log/deployctl`, and `/var/cache/deployctl` directories.
6. Success and failure are written using `log_info` or `log_error`.

For `deployctl deploy`:

1. `deployctl_dispatch` chooses normal, subshell, or fork execution:
   - normal: `deployctl_cmd_deploy "$@"`
   - subshell: `( deployctl_cmd_deploy "$@" )`
   - fork: `deployctl_cmd_deploy "$@" &` followed by `wait $!`
2. `deployctl_cmd_deploy` initializes logs and calls `deployctl_parse_deploy_argv`.
3. Missing app, repo, domain, or port values are prompted interactively.
4. App name is validated by `validate_app_name`.
5. Domain is validated by `validate_domain`.
6. Port is validated by `validate_port`.
7. Dry-run mode logs that the deploy pipeline is skipped and returns before mutating the system.
8. Real deploy requires root through `require_root`.
9. Port availability is checked through `deployctl_check_port_free`.
10. Dependencies and standard layout are verified.
11. The repository is cloned to `/var/lib/deployctl/apps/pending/<app>` by `deployctl_git_clone_repo`.
12. A `Dockerfile` must exist.
13. Environment variables are collected into `/var/lib/deployctl/env/<app>.env`.
14. Docker image is built with `deployctl_docker_build`.
15. Docker container is started with `deployctl_docker_run_app`.
16. Health is checked with `deployctl_health_check_app`.
17. nginx config is rendered with `deployctl_nginx_render_config`.
18. nginx config is tested and nginx is reloaded by `deployctl_nginx_test_and_reload`.
19. If `--ssl yes` or `--ssl true`, certbot is attempted by `deployctl_run_certbot_optional`.
20. Pending source is promoted to `/var/lib/deployctl/apps/live/<app>`.
21. Project metadata is written by `deployctl_write_project_conf`.
22. State file `/var/lib/deployctl/state/<app>.state` is written.
23. Logs are written to global and project logs.

Error handling in deploy:

- Fatal failures call `exit_with_error`.
- Partial deployment failures call `cleanup_on_error` before exiting.
- `cleanup_on_error` removes a new container, removes pending source, removes broken nginx config, reloads nginx if possible, and marks an existing project config as `STATUS=error`.

## inboxctl execution flow

When the user runs `inboxctl`, the entry point is `inboxctl/inboxctl.sh`.

1. Bash strict mode is enabled with `set -euo pipefail`.
2. The script resolves `SCRIPT_DIR`, `REPO_ROOT`, and `SHARED`.
3. It sources `shared/constants.sh`, `shared/format.sh`, and `shared/validators.sh`.
4. It loops over inbox modules and sources `mod_server.sh`, `mod_ssh.sh`, `mod_cache.sh`, `mod_fetch.sh`, `mod_parse.sh`, `mod_ui.sh`, `mod_watch.sh`, and `mod_cli.sh`.
5. `main "$@"` creates local config and cache directories.
6. `inboxctl_parse_globals` parses `-h` and `-v`.
7. `inboxctl_dispatch` routes the command.

For `inboxctl add-server <name> <user@host>`:

1. `validate_app_name` validates the local server alias.
2. `inboxctl_write_server_conf` writes `~/.config/inboxctl/servers.d/<name>.conf`.
3. The config file is chmodded to `600`.

For `inboxctl fetch <name>`:

1. `inboxctl_fetch_server_data` reads the SSH target with `inboxctl_ssh_target`.
2. It creates local cache directories with `inboxctl_prepare_cache_dirs`.
3. It copies remote files with `scp`:
   - `/etc/deployctl/projects.d/*`
   - `/var/log/deployctl/history.log`
   - `/var/log/deployctl/projects/*`
   - `/var/lib/deployctl/state/*`
4. Missing optional remote files produce warnings, not full failure.
5. The local server config is updated with `LAST_FETCH`.

For `inboxctl show projects <name>`:

1. The cache root is resolved.
2. If `projects.d` is not cached, the command exits with `ERR_MISSING_PARAM`.
3. `inboxctl_ui_print_projects_table` prints a header.
4. `inboxctl_collect_projects_from_cache` reads cached `.conf` files.
5. `inboxctl_parse_project_conf_file` extracts project fields.
6. Output is printed as a terminal table.

# 4. Functions inventory

| Function | File path | Input parameters | Output / return code | Used by | Purpose | Internal logic |
|---|---|---|---|---|---|---|
| `current_timestamp` | `shared/format.sh` | none | Prints timestamp; returns 0 | Logging, metadata | Standard timestamp | Runs `date +"%Y-%m-%d-%H-%M-%S"` |
| `format_log_entry` | `shared/format.sh` | log type, message | Prints formatted log line; returns 0 | `log_info`, `log_error`, tests | Log formatting | Builds `timestamp : user : type : message` |
| `print_table_line` | `shared/format.sh` | arbitrary columns | Prints line; returns 0 | inbox UI | Simple table output | Joins columns with two spaces |
| `read_conf_value` | `shared/format.sh` | file, key | Prints value; 0 if found, 1 if missing | deploy/inbox parsers | Read key/value config | Skips comments/blank lines and matches `KEY=` |
| `write_key_value` | `shared/format.sh` | file, key, value | Updates file; returns 0 | deploy metadata, inbox LAST_FETCH | Modify key/value config | Uses `mktemp`, rewrites matching key, appends if missing |
| `escape_sed_replacement` | `shared/format.sh` | raw string | Prints escaped string; returns 0 | Not found in current codebase | Helper for safe sed replacement | Escapes backslash and `&` |
| `normalize_path` | `shared/format.sh` | path | Prints normalized path; returns 0 | Not found in current codebase | Path helper | Uses `realpath -m` or sed fallback |
| `validate_app_name` | `shared/validators.sh` | name | 0 valid, 1 invalid | deploy, inbox | Validate kebab-case names | Regex `^[a-z0-9][a-z0-9-]*[a-z0-9]$` |
| `validate_domain` | `shared/validators.sh` | domain | 0 valid, 1 invalid | deploy | Validate domain | Checks length and hostname regex |
| `validate_port` | `shared/validators.sh` | port | 0 valid, 1 invalid | deploy | Validate TCP port | Numeric regex and range 1-65535 |
| `validate_status` | `shared/validators.sh` | status | 0 valid, 1 invalid | Not found in current codebase | Validate lifecycle status | `case` over pending/live/archive/error |
| `validate_file_exists` | `shared/validators.sh` | path | 0 if file exists | restore | File existence check | Uses `[[ -f ]]` |
| `validate_dir_exists` | `shared/validators.sh` | path | 0 if directory exists | Not found in current codebase | Directory existence check | Uses `[[ -d ]]` |
| `require_command` | `shared/validators.sh` | label, binary | 0 found, 1 missing | check dependencies | Dependency check | Uses `command -v` |
| `require_root` | `shared/validators.sh` | none | 0 root, 1 non-root | deploy, archive, restore, ssl, install | Privilege check | Checks `EUID` or `id -u` |
| `deployctl_write_project_conf` | `deployctl/deployctl.sh` | app, repo, domain, port, dockerfile, ssl, status | Writes config; returns 0 | deploy | Persist metadata | Writes `/etc/deployctl/projects.d/<app>.conf` |
| `deployctl_parse_deploy_argv` | `deployctl/deployctl.sh` | deploy argv | Sets globals; 0 or exits | deploy | Parse deploy-specific options | Handles app, `--repo`, `--domain`, `--port`, `--ssl` |
| `deployctl_cmd_check` | `deployctl/deployctl.sh` | none | 0 or exits | dispatch | Verify server prerequisites | Init logs, check dependencies, create layout |
| `deployctl_cmd_deploy` | `deployctl/deployctl.sh` | deploy args | 0 or exits | dispatch | Full deployment pipeline | Validate, clone, env, build, run, health, nginx, metadata |
| `deployctl_cmd_status` | `deployctl/deployctl.sh` | app | Prints status; 0 or exits | dispatch | Show app status | Reads project config fields |
| `deployctl_cmd_logs` | `deployctl/deployctl.sh` | app | Tails log; 0 or exits | dispatch | Show project logs | `tail -n 100` project log |
| `deployctl_cmd_list` | `deployctl/deployctl.sh` | pending/live/archive | Lists app dirs; 0 or exits | dispatch/menu | List lifecycle bucket | Chooses directory and iterates entries |
| `deployctl_cmd_ssl` | `deployctl/deployctl.sh` | app | 0 or exits | dispatch | Run certbot for existing app | Requires root, reads domain, calls certbot helper |
| `deployctl_cmd_archive` | `deployctl/deployctl.sh` | app | 0 or exits | dispatch | Archive app | Requires root, validates app, calls archive helper |
| `deployctl_cmd_restore` | `deployctl/deployctl.sh` | app | 0 or exits | dispatch | Restore app | Requires root, validates app, calls restore helper |
| `deployctl_dispatch` | `deployctl/deployctl.sh` | command and args | Runs command; exits on unknown | main | Command router | `case` over deployctl commands and modes |
| `main` | `deployctl/deployctl.sh` | original argv | Program result | script entry | deployctl entry | Parses globals, checks restore mode, dispatches |
| `deployctl_reset_globals` | `deployctl/lib/mod_cli.sh` | none | 0 | Tests or future use | Reset parser state | Restores default global flags |
| `deployctl_parse_global_options` | `deployctl/lib/mod_cli.sh` | argv | Sets `REMAINING_ARGS`; 0 or exits | deployctl main | Parse global options | Handles `-h`, `-v`, `-n`, `-l`, `-f`, `-t`, `-s`, `-r` |
| `deployctl_print_usage` | `deployctl/lib/mod_cli.sh` | none | Prints help; 0 | help/errors | Help message | Static heredoc |
| `deployctl_log_ensure_init` | `deployctl/lib/mod_log.sh` | none | 0 | log functions | Ensure log base exists | Calls `init_logs` if needed |
| `init_logs` | `deployctl/lib/mod_log.sh` | none | 0 | deploy commands | Initialize log directories | Uses override, `/var/log/deployctl`, or user cache fallback |
| `log_info` | `deployctl/lib/mod_log.sh` | message | Writes history; 0 | deployctl modules | Global info log | Formats line, appends history, optionally stderr when verbose |
| `log_error` | `deployctl/lib/mod_log.sh` | message | Writes history/stderr; 0 | errors/modules | Global error log | Formats line, appends history, prints stderr |
| `log_project_info` | `deployctl/lib/mod_log.sh` | app, message | Writes project log; 0 | deploy pipeline | Project info log | Appends to `projects/<app>.log` |
| `log_project_error` | `deployctl/lib/mod_log.sh` | app, message | Writes project log/stderr; 0 | deploy failures | Project error log | Appends project log and prints stderr |
| `exit_with_error` | `deployctl/lib/mod_error.sh` | code, message | Exits with code | deployctl fatal paths | Central fatal error | Logs error, prints message and help hint |
| `show_error_help` | `deployctl/lib/mod_error.sh` | none | Prints code list; 0 | `errors-help` | Error-code reference | Static heredoc |
| `cleanup_on_error` | `deployctl/lib/mod_error.sh` | none; uses globals | Best effort; 0 | deploy/restore failure | Rollback partial deployment | Removes container, pending dir, nginx config, marks status error |
| `deployctl_check_dependencies` | `deployctl/lib/mod_check.sh` | none | 0 if all found, 1 if missing | check/deploy | Dependency validation | Requires docker/git/nginx/curl/ss |
| `deployctl_ensure_layout` | `deployctl/lib/mod_check.sh` | none | 0 or 1 | check/deploy | Create system layout | `mkdir -p` standard dirs, chmod some dirs |
| `deployctl_check_port_free` | `deployctl/lib/mod_check.sh` | port | 0 free, 1 in use | deploy | Port availability | Pipes `ss -ltn` to `grep` |
| `deployctl_collect_env_from_example` | `deployctl/lib/mod_env.sh` | app, repo dir | 0 or 1 | deploy | Create env file from `.env.example` | Reads keys, prompts values, writes chmod 600 env file |
| `deployctl_collect_env_interactive_full` | `deployctl/lib/mod_env.sh` | app | 0 | deploy | Manual env entry | Copies provided env path or reads KEY=value lines |
| `deployctl_git_clone_repo` | `deployctl/lib/mod_git.sh` | repo URL, target dir | 0 or 1 | deploy/restore | Clone source | Removes target, creates parent, runs `git clone --depth 1` |
| `deployctl_docker_ensure_network` | `deployctl/lib/mod_docker.sh` | none | 0 or 1 | docker run | Ensure Docker network | Inspects/creates `deployctl_net` |
| `deployctl_docker_build` | `deployctl/lib/mod_docker.sh` | app, context, dockerfile | 0 or 1 | deploy/restore | Build Docker image | Runs `docker build -t deployctl/<app>:latest` |
| `deployctl_docker_run_app` | `deployctl/lib/mod_docker.sh` | app, host port, container port | 0 or 1 | deploy/restore | Run container | Removes old container, ensures network, runs Docker with env file |
| `deployctl_docker_stop_remove` | `deployctl/lib/mod_docker.sh` | container name | 0 | archive | Stop/remove container | Runs `docker rm -f`, ignores missing container |
| `deployctl_health_check_app` | `deployctl/lib/mod_health.sh` | app, port | 0 or 1 | deploy/restore | Verify app availability | Tries curl `/health`, then `ss` listening check |
| `deployctl_nginx_render_config` | `deployctl/lib/mod_nginx.sh` | app, domain, port | 0 | deploy/restore | Render nginx site | Uses sed template substitution and creates symlink |
| `deployctl_nginx_test_and_reload` | `deployctl/lib/mod_nginx.sh` | app | 0 or 1 | deploy/restore | Validate nginx | Runs `nginx -t`, reloads with systemctl/service/nginx |
| `deployctl_nginx_remove_config` | `deployctl/lib/mod_nginx.sh` | app | 0 | cleanup/archive future use | Remove nginx config | Deletes symlinks/config and reloads nginx if config valid |
| `deployctl_archive_app` | `deployctl/lib/mod_archive.sh` | app | 0 or 1 | archive command | Archive live app | Reads conf, stops container, optionally removes image, moves live to archive, updates status |
| `deployctl_restore_app` | `deployctl/lib/mod_restore.sh` | app | 0 or exits | restore command | Rebuild archived app | Reads metadata/env, clones, builds, runs, health checks, nginx, marks live |
| `deployctl_run_certbot_optional` | `deployctl/lib/mod_restore.sh` | domain, app | 0 success/skipped dry-run, 1 missing/failed certbot | deploy/restore/ssl | Optional TLS | Runs certbot if installed |
| `deployctl_run_menu` | `deployctl/lib/mod_menu.sh` | none | command result or 0 | menu command | Interactive menu | Reads numeric choice and calls check/list/version |
| `require_install_root` | `deployctl/install.sh` | none | 0 or exits 1 | install main | Enforce root install | Checks EUID |
| `main` | `deployctl/install.sh` | argv | 0 or exits | installer | Install deployctl | Copies files, creates dirs, writes `/usr/local/bin/deployctl` wrapper |
| `prompt_yes` | `deployctl/uninstall.sh` | prompt | 0 yes, 1 otherwise | uninstall main | Confirm destructive actions | Reads answer, regex `^[Yy]$` |
| `main` | `deployctl/uninstall.sh` | argv | 0 or exits | uninstaller | Remove deployctl | Requires root, prompts, removes wrapper/libs/config/logs |
| `inboxctl_cmd_add_server` | `inboxctl/inboxctl.sh` | name, user@host | 0 or exits | dispatch | Add local server alias | Validates name, writes server conf |
| `inboxctl_cmd_remove_server` | `inboxctl/inboxctl.sh` | name | 0 | dispatch | Remove local server alias | Removes config and cache |
| `inboxctl_cmd_list_servers` | `inboxctl/inboxctl.sh` | none | server names; 0 | dispatch | List aliases | Calls `inboxctl_list_server_names` |
| `inboxctl_cmd_show_servers` | `inboxctl/inboxctl.sh` | none | config contents; 0 | dispatch | Show server configs | Iterates `servers.d/*.conf` and cats files |
| `inboxctl_cmd_test` | `inboxctl/inboxctl.sh` | name | 0 or exits 113 | dispatch | Test SSH | Calls `inboxctl_ssh_test_connection` |
| `inboxctl_cmd_fetch` | `inboxctl/inboxctl.sh` | name | 0 or module failure | dispatch/watch | Fetch remote data | Calls `inboxctl_fetch_server_data` |
| `inboxctl_cmd_show_projects` | `inboxctl/inboxctl.sh` | name | table; 0 or exits 101 | dispatch | Show cached projects | Checks cache and prints table |
| `inboxctl_cmd_show_bucket` | `inboxctl/inboxctl.sh` | status, name | table; 0 | dispatch | Filter cached projects | Calls UI filter |
| `inboxctl_cmd_logs` | `inboxctl/inboxctl.sh` | server, app | log tail; 0 or exits 101 | dispatch | Show cached app log | Tails cached project log |
| `inboxctl_cmd_errors` | `inboxctl/inboxctl.sh` | server | error lines; 0 or exits 101 | dispatch | Show cached errors | Greps ` : ERROR : ` from history log |
| `inboxctl_cmd_watch` | `inboxctl/inboxctl.sh` | name | loop until interrupted | dispatch | Live-like monitor | Calls `inboxctl_watch_server` |
| `inboxctl_dispatch` | `inboxctl/inboxctl.sh` | command and args | command result or exits | main | Command router | Nested `case` for commands and `show` targets |
| `main` | `inboxctl/inboxctl.sh` | argv | program result | script entry | inboxctl entry | Ensures dirs, parses globals, dispatches |
| `inboxctl_print_usage` | `inboxctl/lib/mod_cli.sh` | none | help text; 0 | help/errors | Print help | Static heredoc |
| `inboxctl_parse_globals` | `inboxctl/lib/mod_cli.sh` | argv | sets `INBOXCTL_ARGS`; 0 or exits | inboxctl main | Parse global options | Handles `-h`, `-v`, unknown options |
| `inboxctl_server_conf_path` | `inboxctl/lib/mod_server.sh` | server name | prints path; 0 | server functions | Build config path | Prints `~/.config/inboxctl/servers.d/<name>.conf` |
| `inboxctl_ensure_config_dirs` | `inboxctl/lib/mod_server.sh` | none | 0 | inboxctl main/server writes | Ensure config dirs | `mkdir -p` servers dir |
| `inboxctl_write_server_conf` | `inboxctl/lib/mod_server.sh` | name, SSH target | 0 | add-server | Write server config | Writes key/value file and chmod 600 |
| `inboxctl_remove_server_conf` | `inboxctl/lib/mod_server.sh` | name | 0 | remove-server | Remove server config | `rm -f` config file |
| `inboxctl_list_server_names` | `inboxctl/lib/mod_server.sh` | none | names; 0 | list servers | List configured servers | Iterates nullglob `*.conf` |
| `inboxctl_ssh_target` | `inboxctl/lib/mod_ssh.sh` | server name | prints `user@host`; 0/1 | SSH/fetch | Resolve SSH target | Reads `SSH_TARGET` from config |
| `inboxctl_ssh_test_connection` | `inboxctl/lib/mod_ssh.sh` | server name | SSH exit code | test | Test SSH key access | Runs `ssh -o BatchMode=yes -o ConnectTimeout=10 target true` |
| `inboxctl_cache_root_for_server` | `inboxctl/lib/mod_cache.sh` | server name | prints path; 0 | fetch/show/logs/watch | Build cache path | Prints `~/.cache/inboxctl/servers/<name>` |
| `inboxctl_prepare_cache_dirs` | `inboxctl/lib/mod_cache.sh` | server name | 0 | fetch | Create cache layout | Creates projects/logs/state dirs |
| `inboxctl_fetch_server_data` | `inboxctl/lib/mod_fetch.sh` | server name | 0 or 1 | fetch/watch | Copy remote metadata/logs | Uses `scp` and `ssh`, updates `LAST_FETCH` |
| `inboxctl_parse_project_conf_file` | `inboxctl/lib/mod_parse.sh` | conf path | sets `PARSE_*`; 0 | UI/tests | Parse project metadata | Reads known keys with `read_conf_value` |
| `inboxctl_collect_projects_from_cache` | `inboxctl/lib/mod_parse.sh` | cache root | TSV rows; 0 | UI | Collect project rows | Iterates cached `.conf` files |
| `inboxctl_ui_print_projects_header` | `inboxctl/lib/mod_ui.sh` | none | header; 0 | UI commands | Print table header | Calls `print_table_line` |
| `inboxctl_ui_print_projects_table` | `inboxctl/lib/mod_ui.sh` | cache root | table; 0 | show projects/watch | Print all projects | Reads TSV rows through process substitution |
| `inboxctl_ui_filter_status` | `inboxctl/lib/mod_ui.sh` | cache root, status | filtered table; 0 | show live/pending/archive | Filter table | Prints only rows with matching status |
| `inboxctl_watch_server` | `inboxctl/lib/mod_watch.sh` | server name, optional interval | infinite loop until interrupted | watch | Periodic refresh | Fetches, clears screen, prints table, sleeps |
| `resolve_install_paths` | `inboxctl/install.sh` | none | sets globals; 0 | install main | Decide install destination | Uses `/usr/local` if root/writable, else `~/.local` |
| `main` | `inboxctl/install.sh` | argv | 0 or exits | installer | Install inboxctl | Copies files, writes wrapper, creates user config/cache dirs |
| `prompt_yes` | `inboxctl/uninstall.sh` | prompt | 0 yes, 1 otherwise | uninstall main | Confirm removal | Reads answer and matches `^[Yy]$` |
| `main` | `inboxctl/uninstall.sh` | argv | 0 | uninstaller | Remove inboxctl | Removes wrappers/libs, optionally config/cache |
| `require_doc` | `scripts/check-docs.sh` | relative path | 0 exists/non-empty, 1 otherwise | docs check main | Verify docs | Checks `-f` and `-s` |
| `main` | `scripts/check-docs.sh` | argv | 0/1 | script entry | Documentation QA | Iterates required docs |
| `chmod_scripts` | `scripts/format.sh` | none | 0 | script entry | Fix executable bits | chmods entrypoints/tests/scripts |
| `lint_all_sh` | `scripts/lint.sh` | none | 0/1 | script entry | Syntax/lint QA | Finds `.sh`, runs `bash -n`, optional ShellCheck |
| `assert_executable` | `scripts/verify-format.sh` | paths | 0/1 | verify main | Check executable files | Verifies each file exists and is executable |
| `main` | `scripts/verify-format.sh` | argv | 0/1 | script entry | Executable-bit QA | Checks expected scripts and tests |

# 5. Options and commands

## deployctl global options

| Option | Syntax | Example | Required parameters | Internal behavior | Related functions | Expected output |
|---|---|---|---|---|---|---|
| Help | `deployctl -h` or `deployctl --help` | `deployctl --help` | none | Prints usage and exits 0 | `deployctl_parse_global_options`, `deployctl_print_usage` | Help text |
| Verbose | `deployctl -v <command>` | `deployctl -v check` | command | Sets `DEPLOYCTL_VERBOSE=1`; info logs also print to stderr | `deployctl_parse_global_options`, `log_info` | Command output plus verbose log lines |
| Dry-run | `deployctl -n <command>` | `deployctl -n deploy demo-app --repo https://example.com/demo.git --domain demo.example.com --port 8080 --ssl no` | command | Simulates many mutating steps | `deployctl_parse_global_options`, most deploy modules | Dry-run log messages |
| Custom log dir | `deployctl -l DIR <command>` | `deployctl -n -l /tmp/deployctl-demo check` | `DIR` | Stores `history.log` under selected dir | `deployctl_parse_global_options`, `init_logs` | Logs in `DIR/history.log` |
| Fork | `deployctl -f deploy ...` | `deployctl -n -f deploy app-one --repo https://example.com/a.git --domain a.example.com --port 3001 --ssl no` | deploy command | Runs deploy function in background child process, then waits | `deployctl_dispatch` | Same deploy output/logs; synchronous because of `wait` |
| Thread flag | `deployctl -t deploy ...` | `deployctl -n -t deploy app-two --repo https://example.com/b.git --domain b.example.com --port 3002 --ssl no` | deploy command | Sets `DEPLOYCTL_THREAD_MODE=1`; no dispatch branch uses it | `deployctl_parse_global_options` | Same as normal dry-run deploy |
| Subshell | `deployctl -s deploy ...` | `deployctl -n -s deploy app-three --repo https://example.com/c.git --domain c.example.com --port 3003 --ssl no` | deploy command | Runs deploy body in `( ... )` subshell | `deployctl_dispatch` | Same deploy output/logs |
| Restore mode | `deployctl -r <command>` | `deployctl -r status demo-app` | command | If command is not `restore` or `check`, requires root before dispatch | `deployctl_parse_global_options`, `main` | Command output or error 112 |

## deployctl commands

| Command | Syntax | Example | Required parameters | What happens internally | Related functions | Expected output |
|---|---|---|---|---|---|---|
| `check` | `deployctl [options] check` | `sudo deployctl check` | none | Initializes logs, checks dependencies, creates layout | `deployctl_cmd_check`, `deployctl_check_dependencies`, `deployctl_ensure_layout` | Usually no stdout; logs success; errors to stderr |
| `deploy` | `deployctl [options] deploy [app] --repo URL --domain D --port P --ssl yes|no` | `sudo deployctl deploy demo-app --repo https://github.com/example/demo-app.git --domain demo.example.com --port 8080 --ssl no` | app/repo/domain/port required, but missing values are prompted interactively | Full clone/env/build/run/health/nginx/metadata pipeline | `deployctl_cmd_deploy` and many module functions | Logs success; project config and state files created |
| `status` | `deployctl status <app>` | `deployctl status demo-app` | app | Reads project config | `deployctl_cmd_status`, `read_conf_value` | `demo-app status=live domain=... port=...` |
| `logs` | `deployctl logs <app>` | `deployctl logs demo-app` | app | Tails project log | `deployctl_cmd_logs` | Last 100 project log lines |
| `archive` | `deployctl archive <app>` | `sudo deployctl archive demo-app` | app | Requires root, stops/removes container, moves live source to archive, updates status | `deployctl_cmd_archive`, `deployctl_archive_app` | Prompt about image removal; logs archive result |
| `restore` | `deployctl restore <app>` | `sudo deployctl restore demo-app` | app | Requires root, reads metadata/env, reclones/rebuilds/reruns app | `deployctl_cmd_restore`, `deployctl_restore_app` | Logs restore success/failure |
| `list` | `deployctl list <live\|pending\|archive>` | `deployctl list live` | bucket | Lists directories in selected lifecycle folder | `deployctl_cmd_list` | App names, one per line |
| `ssl` | `deployctl ssl <app>` | `sudo deployctl ssl demo-app` | app | Requires root, reads domain, runs certbot helper | `deployctl_cmd_ssl`, `deployctl_run_certbot_optional` | Certbot result in logs/errors |
| `menu` | `deployctl menu` | `deployctl menu` | none | Shows interactive menu for check/list/version/exit | `deployctl_run_menu` | Menu and selected command output |
| `version` | `deployctl version` | `deployctl version` | none | Prints shared version | `deployctl_dispatch` | `deployctl 1.0.0` |
| `help` | `deployctl help` or `deployctl --help` | `deployctl help` | none | Prints usage | `deployctl_print_usage` | Help text |
| `errors-help` | `deployctl errors-help` | `deployctl errors-help` | none | Prints error-code table | `show_error_help` | Error-code list |

## deploy deploy-specific options

| Option | Syntax | Example | Required parameters | Internal behavior | Related functions | Expected output |
|---|---|---|---|---|---|---|
| Repository | `--repo URL` | `--repo https://github.com/example/demo-app.git` | URL | Sets `DEPLOY_ARG_REPO`; later cloned | `deployctl_parse_deploy_argv`, `deployctl_git_clone_repo` | Clone/log result |
| Domain | `--domain DOMAIN` | `--domain demo.example.com` | domain | Sets `DEPLOY_ARG_DOMAIN`; validated and used in nginx | `validate_domain`, `deployctl_nginx_render_config` | nginx config uses domain |
| Port | `--port PORT` | `--port 8080` | TCP port | Sets `DEPLOY_ARG_PORT`; validates and maps host/container port | `validate_port`, `deployctl_docker_run_app` | Container exposed on port |
| SSL | `--ssl yes|no` | `--ssl no` | yes/no string | If `yes` or `true`, attempts certbot | `deployctl_run_certbot_optional` | SSL logs or skipped |

## inboxctl global options

| Option | Syntax | Example | Required parameters | Internal behavior | Related functions | Expected output |
|---|---|---|---|---|---|---|
| Help | `inboxctl -h` or `inboxctl --help` | `inboxctl --help` | none | Prints usage and exits 0 | `inboxctl_parse_globals`, `inboxctl_print_usage` | Help text |
| Verbose | `inboxctl -v <command>` | `inboxctl -v test prod1` | command | Adds verbose SSH/SCP diagnostics | `inboxctl_parse_globals`, `inboxctl_ssh_test_connection`, `inboxctl_fetch_server_data` | SSH verbose output |

## inboxctl commands

| Command | Syntax | Example | Required parameters | What happens internally | Related functions | Expected output |
|---|---|---|---|---|---|---|
| `add-server` | `inboxctl add-server <name> <user@host>` | `inboxctl add-server prod1 sernine@192.168.1.78` | name, target | Writes local config | `inboxctl_cmd_add_server`, `inboxctl_write_server_conf` | Confirmation line |
| `remove-server` | `inboxctl remove-server <name>` | `inboxctl remove-server prod1` | name | Removes config and cache | `inboxctl_cmd_remove_server` | Confirmation line |
| `list servers` | `inboxctl list servers` | `inboxctl list servers` | literal `servers` | Lists configured aliases | `inboxctl_cmd_list_servers` | Server names |
| `show servers` | `inboxctl show servers` | `inboxctl show servers` | none | Prints local server config files | `inboxctl_cmd_show_servers` | Config file contents |
| `test` | `inboxctl test <name>` | `inboxctl test prod1` | name | Runs SSH BatchMode test | `inboxctl_cmd_test`, `inboxctl_ssh_test_connection` | `SSH OK` or error |
| `fetch` | `inboxctl fetch <name>` | `inboxctl fetch prod1` | name | Copies remote metadata/logs to cache | `inboxctl_cmd_fetch`, `inboxctl_fetch_server_data` | Fetch complete or warnings |
| `show projects` | `inboxctl show projects <name>` | `inboxctl show projects prod1` | name | Parses cached project metadata and prints table | `inboxctl_cmd_show_projects`, `inboxctl_ui_print_projects_table` | Project table |
| `show live` | `inboxctl show live <name>` | `inboxctl show live prod1` | name | Filters cached table for `live` | `inboxctl_cmd_show_bucket`, `inboxctl_ui_filter_status` | Filtered table |
| `show pending` | `inboxctl show pending <name>` | `inboxctl show pending prod1` | name | Filters cached table for `pending` | `inboxctl_cmd_show_bucket`, `inboxctl_ui_filter_status` | Filtered table |
| `show archive` | `inboxctl show archive <name>` | `inboxctl show archive prod1` | name | Filters cached table for `archive` | `inboxctl_cmd_show_bucket`, `inboxctl_ui_filter_status` | Filtered table |
| `logs` | `inboxctl logs <server> <app>` | `inboxctl logs prod1 demo-app` | server, app | Tails cached project log | `inboxctl_cmd_logs` | Last 80 cached log lines |
| `errors` | `inboxctl errors <name>` | `inboxctl errors prod1` | name | Greps cached history log for `ERROR` | `inboxctl_cmd_errors` | Error lines or `(no ERROR lines)` |
| `watch` | `inboxctl watch <name>` | `inboxctl watch prod1` | name | Repeats fetch/table every 3 seconds | `inboxctl_cmd_watch`, `inboxctl_watch_server` | Updating terminal table |
| `version` | `inboxctl version` | `inboxctl version` | none | Prints shared version | `inboxctl_dispatch` | `inboxctl 1.0.0` |
| `help` | `inboxctl help` | `inboxctl help` | none | Prints usage | `inboxctl_print_usage` | Help text |

# 6. Teacher requirements mapping

| Requirement from cahier de charge | Status | Evidence from code | File/function concerned | What should be added if missing |
|---|---|---|---|---|
| Bash script answers a clear real need | Implemented | README and docs describe single-host Docker deployment and remote inspection | `README.md`, `docs/cahier-de-charge.md` | Nothing essential |
| At least one mandatory parameter | Implemented | Commands require app/server parameters; deploy prompts missing values | `deployctl_cmd_status`, `inboxctl_cmd_add_server`, `deployctl_cmd_deploy` | Nothing essential |
| `-h` help option | Implemented | Both CLIs parse `-h`/`--help` | `deployctl_parse_global_options`, `inboxctl_parse_globals` | Nothing essential |
| `-f` fork/child-process execution | Partially implemented | `deployctl_dispatch` runs deploy in background with `&` then `wait $!` | `deployctl_dispatch` | Add visible message/PID and document that it is synchronous because of `wait` |
| `-t` thread or thread-like parallel execution | Missing | `DEPLOYCTL_THREAD_MODE=1` is parsed but not used in dispatch or modules | `deployctl_parse_global_options`, `deployctl_dispatch` | Implement real parallel/thread-like jobs, for example parallel health/log checks with background jobs and `wait` |
| `-s` subshell execution | Implemented | Deploy body can run inside `( deployctl_cmd_deploy "$@" )` | `deployctl_dispatch` | Add a visible log proving subshell mode if needed for demo |
| `-l` custom log directory | Implemented | `DEPLOYCTL_LOG_DIR_OVERRIDE` controls log base | `deployctl_parse_global_options`, `init_logs` | Nothing essential |
| `-r` restore default settings admin-only | Partially implemented | `-r` is `--restore-mode`, not restore defaults; it enforces root for most commands | `deployctl_parse_global_options`, `main` | Add a true "restore default settings" operation if required by teacher |
| Admin privileges required for sensitive options | Implemented | Deploy/archive/restore/ssl/install require root; restore mode can require root | `require_root`, `deployctl_cmd_deploy`, `deployctl_cmd_archive`, `deployctl_cmd_restore`, `deployctl_cmd_ssl`, `deployctl/install.sh` | Nothing essential |
| Conditions | Implemented | Many `if`, `case`, `[[ ]]` checks | All main scripts/modules | Nothing essential |
| Loops | Implemented | `for` module sourcing, `while` argument parsing, file reading, watch loop | `deployctl.sh`, `mod_cli.sh`, `mod_env.sh`, `mod_watch.sh` | Nothing essential |
| Functions | Implemented | Project is modularized with many Bash functions | All `mod_*.sh`, entrypoints | Nothing essential |
| Environment variables | Implemented | Shared root overrides, install roots, dry-run/log flags, env files | `DEPLOY_SHARED_ROOT`, `INBOX_SHARED_ROOT`, `DEPLOYCTL_INSTALL_ROOT`, `INBOXCTL_INSTALL_ROOT`, `DEPLOYCTL_LOG_DIR_OVERRIDE` | Nothing essential |
| Regular expressions | Implemented | App/domain/port/status validation, yes/no prompts | `validators.sh`, uninstall/archive scripts | Nothing essential |
| File manipulation | Implemented | Creates/removes directories, writes configs/logs/env files, moves app dirs | deploy/inbox modules | Nothing essential |
| Search / archiving / compression | Partially implemented | Search via `grep`; archiving is move-to-archive; compression not implemented in operational code | `deployctl_archive_app`, `inboxctl_cmd_errors` | Add tar/gzip/zip compression for archives if required |
| Access control | Partially implemented | Root checks and chmod `600` for env/server config; SSH keys only | `require_root`, `deployctl_collect_env_*`, `inboxctl_write_server_conf` | Consider stricter permissions on all server dirs/logs |
| Pipes and filters | Implemented | `ss | grep`, process substitution, `find`, `grep` | `mod_check.sh`, `mod_health.sh`, `mod_ui.sh`, `scripts/lint.sh` | Nothing essential |
| stdout and stderr redirected to terminal and log file | Partially implemented | Errors log to file and stderr; info logs file-only unless verbose; command stdout is not generally tee'd to log | `mod_log.sh` | Add `tee` or centralized stdout/stderr capture if strict requirement |
| Log file named `history.log` | Implemented | History file is `history.log` | `DEPLOYCTL_HISTORY_LOG`, `init_logs` | Nothing essential |
| Log path `/var/log/yourprogramname/history.log` | Implemented | Uses `/var/log/deployctl/history.log` by default | `shared/constants.sh`, `init_logs` | Nothing essential |
| Log format `yyyy-mm-dd-hh-mm-ss : username : INFOS/ERROR : message` | Implemented | `format_log_entry` matches this shape | `shared/format.sh` | Nothing essential |
| Error handling with specific error codes | Implemented for deployctl; partial for inboxctl | Codes 100-120 defined; deployctl centralizes fatal errors; inboxctl exits with shared codes but no central helper | `shared/constants.sh`, `exit_with_error`, `inboxctl.sh` | Add inbox-specific centralized error helper and map all returns |
| Help message shown after errors | Partially implemented | deployctl `exit_with_error` prints `Run: deployctl --help`; inboxctl often does not show help after errors | `mod_error.sh`, `inboxctl.sh` | Add help hints for inboxctl errors |
| Linux command syntax: `program [options] [parameter]` | Implemented | Help text uses `deployctl [global-options] <command> [arguments]` and same for inboxctl | `deployctl_print_usage`, `inboxctl_print_usage` | Nothing essential |
| At least 3 test scenarios: light, medium, heavy | Implemented | Three deployctl test scripts exist | `deployctl/tests/test_light.sh`, `test_medium.sh`, `test_heavy.sh` | Add real VM integration test notes if teacher wants live proof |
| Normal execution | Implemented | Default deploy path calls command directly | `deployctl_dispatch` | Nothing essential |
| Subshell execution | Implemented | `-s` branch uses `( ... )` | `deployctl_dispatch` | Nothing essential |
| Fork execution | Partially implemented | `-f` starts a background child then waits | `deployctl_dispatch` | Add PID/log proof for presentation |
| Thread execution | Missing | `-t` flag is reserved only | `DEPLOYCTL_THREAD_MODE` | Implement thread-like parallel jobs |

## Missing or incomplete requirements

- Missing: real `-t` thread or thread-like parallel execution. The flag exists but no code path uses `DEPLOYCTL_THREAD_MODE`.
- Missing: true "restore default settings" behavior for `-r`. Current `-r` means restore mode/root gate, while `restore <app>` redeploys an app from metadata.
- Missing: compression in deploy archives. Current archive logic moves files into `/var/lib/deployctl/apps/archive/<app>` and writes `restore.txt`, but it does not create `.tar.gz` or `.zip` files.
- Partially implemented: stdout/stderr redirection to both terminal and log. Errors are logged and printed; info logs are printed only in verbose mode; command output is not globally captured with `tee`.
- Partially implemented: help after errors. `deployctl` prints a help hint from `exit_with_error`; `inboxctl` does not consistently show help after errors.
- Partially implemented: error-code handling in `inboxctl`. It uses shared codes in several places, but does not have a central `exit_with_error` equivalent.

# 7. Logging system

Default deployctl log locations:

- Global history log: `/var/log/deployctl/history.log`
- Project logs: `/var/log/deployctl/projects/<app>.log`
- Custom test log directory: `deployctl -l DIR ...` writes `DIR/history.log` and `DIR/projects/<app>.log`
- Fallback when `/var/log/deployctl` is not writable: `${HOME}/.cache/deployctl/logs`

Log creation is handled by `init_logs` in `deployctl/lib/mod_log.sh`. It tries to create the selected log base and `projects` subdirectory, then touches `history.log`.

stdout handling:

- Normal command output is printed directly with `printf`, `cat`, or `tail`.
- stdout is not globally redirected to the log file.
- Info logs go to the log file and only appear on stderr when `DEPLOYCTL_VERBOSE=1`.

stderr handling:

- `log_error` writes to `history.log` and always prints the same formatted line to stderr.
- `log_project_error` writes to the project log and always prints to stderr.
- Some external command stderr is suppressed or redirected, for example `nginx -t 2>/tmp/deployctl-nginx-test.log`.

Exact current log format:

```text
yyyy-mm-dd-hh-mm-ss : username : INFOS : message
yyyy-mm-dd-hh-mm-ss : username : ERROR : message
```

The format is produced by `format_log_entry`:

```bash
printf '%s : %s : %s : %s\n' "$ts" "$user_name" "$log_type" "$message"
```

This matches the required timestamp/user/type/message format. The main limitation is not the line format; the limitation is that not all stdout/stderr from every command is captured in `history.log`.

Changes needed if strict teacher interpretation is required:

- Wrap major command execution with `tee -a "$history"` or explicit redirection.
- Add a central runner function for external commands that logs stdout and stderr.
- Add visible mode logs for `-f`, `-s`, and future `-t`.

# 8. Error handling

Error codes are defined in `shared/constants.sh`.

| Code | Meaning | Where triggered | Message shown | Help shown after error |
|---|---|---|---|---|
| 100 | `ERR_UNKNOWN_OPTION` | Unknown deploy global option, unknown deploy command, unexpected deploy arg; inbox unknown option/show target | `unknown global option`, `unknown command`, `unexpected deploy argument`; inbox-specific messages | deployctl yes through `exit_with_error`; inboxctl usually no |
| 101 | `ERR_MISSING_PARAM` | Invalid deploy port, missing deploy project log, inbox no cache/log/history, wrong `list` syntax | `invalid port`, `no log file yet`, inbox-specific missing messages | deployctl yes; inboxctl no |
| 102 | `ERR_INVALID_APP_NAME` | Invalid app/server name | `invalid app name` or `invalid app` | deployctl yes; inboxctl no |
| 103 | `ERR_INVALID_DOMAIN` | Invalid deploy domain | `invalid domain` | deployctl yes |
| 104 | `ERR_PORT_IN_USE` | Deploy port unavailable | `port <port> appears in use` | deployctl yes |
| 105 | `ERR_DOCKERFILE_MISSING` | Deploy/restore missing Dockerfile | `Dockerfile not found in repo` or `Dockerfile not found` | deployctl yes |
| 106 | `ERR_ENV_EXAMPLE_MISSING` | Env creation from example fails | `env creation failed` | deployctl yes |
| 107 | `ERR_DOCKER_BUILD_FAILED` | Docker build fails | `build failed` | deployctl yes |
| 108 | `ERR_CONTAINER_RUN_FAILED` | Docker run fails | `run failed` | deployctl yes |
| 109 | `ERR_HEALTH_CHECK_FAILED` | Health check fails | `health failed` | deployctl yes |
| 110 | `ERR_NGINX_CONFIG_FAILED` | nginx config write/test/reload fails | `nginx write failed`, `nginx test/reload failed`, `nginx render failed`, `nginx test failed` | deployctl yes |
| 111 | `ERR_SSL_FAILED` | `deployctl ssl` certbot helper fails | `certbot failed` | deployctl yes |
| 112 | `ERR_NOT_ROOT` | Deploy/archive/restore/ssl/restore-mode without root | `deploy requires root`, `archive requires root`, `restore requires root`, `ssl command requires root`, `restore-mode requires root` | deployctl yes |
| 113 | `ERR_SSH_FAILED` | inboxctl SSH test failure | `inboxctl: SSH failed for <name>` | inboxctl no |
| 114 | `ERR_CONFIG_PARSE_ERROR` | Unknown app config or missing `REPO_URL` during restore | `unknown app`, `REPO_URL missing` | deployctl yes |
| 115 | `ERR_UNKNOWN_STATUS` | Invalid deployctl list bucket | `list needs pending\|live\|archive` | deployctl yes |
| 116 | `ERR_DEPENDENCY_MISSING` | Missing Docker/Git/nginx/curl/ss | `dependency check failed` or `missing dependency` | deployctl yes |
| 117 | `ERR_GIT_CLONE_FAILED` | Git clone failure | `clone failed` | deployctl yes |
| 118 | `ERR_FILE_PERMISSION_ERROR` | Layout creation failure or missing env file for restore | `layout failed`, `cannot create dirs`, `env file required for restore` | deployctl yes |
| 119 | `ERR_ARCHIVE_FAILED` | Archive helper failure | `archive failed` | deployctl yes |
| 120 | `ERR_RESTORE_FAILED` | Restore helper failure | `restore failed` | deployctl yes |

Other non-shared error exits:

- `deployctl/install.sh` exits `1` if not root.
- `deployctl/uninstall.sh` exits `1` if not root.
- Test scripts exit `1` on assertion failure.
- `deployctl_dispatch` exits `1` when no command is supplied after printing usage.

Missing error handling improvements:

- Add a central `inboxctl_exit_with_error` helper.
- Show inboxctl help after user errors.
- Add specific codes for missing SSH target, fetch failure, and cache parse failure if more precision is required.
- Add a specific error for unsupported/reserved `-t` until thread-like mode is implemented.

# 9. Process execution model

| Mode | Current support | File/function | Command example | Implementation details | Real or simulated | How to demonstrate |
|---|---|---|---|---|---|---|
| Normal execution | Implemented | `deployctl_dispatch` | `deployctl -n deploy demo-app --repo https://example.com/demo.git --domain demo.example.com --port 8080 --ssl no` | Calls `deployctl_cmd_deploy "$@"` directly | Real normal Bash function execution | Show dry-run or real deploy logs |
| Subshell execution | Implemented for deploy | `deployctl_dispatch` | `deployctl -n -s deploy app-three --repo https://example.com/c.git --domain c.example.com --port 3003 --ssl no` | Uses `( deployctl_cmd_deploy "$@" )` | Real Bash subshell | Add `echo $$ $BASHPID` manually for proof, or explain from code |
| Fork/background child process | Partially implemented for deploy | `deployctl_dispatch` | `deployctl -n -f deploy app-one --repo https://example.com/a.git --domain a.example.com --port 3001 --ssl no` | Uses `deployctl_cmd_deploy "$@" &` then `wait $!` | Real child process, but synchronous because parent waits immediately | Run command and cite code; add PID logging for stronger demo |
| Thread-like parallel execution | Missing | `deployctl_parse_global_options` only | `deployctl -n -t deploy app-two --repo https://example.com/b.git --domain b.example.com --port 3002 --ssl no` | Only sets `DEPLOYCTL_THREAD_MODE=1`; no branch uses it | Not implemented; flag is reserved | Demonstrate that output is same as normal mode and cite missing dispatch branch |

# 10. Demo commands

Assumptions:

- Windows workstation runs `inboxctl` through Git Bash or WSL.
- Ubuntu VM simulates the VPS/server and runs `deployctl`.
- SSH user: `sernine`.
- VM IP: `192.168.1.78` unless replaced by actual IP.

## On Ubuntu VM: check IP

```bash
hostname -I
ip addr show
```

## On Windows host: test network and SSH

PowerShell:

```powershell
ping 192.168.1.78
ssh sernine@192.168.1.78
```

Git Bash or WSL:

```bash
ping -c 4 192.168.1.78
ssh sernine@192.168.1.78
```

## On Ubuntu VM: check nginx and ports

```bash
sudo systemctl status nginx
sudo nginx -t
ss -ltnp
curl -I http://127.0.0.1
```

## On Ubuntu VM: install and run deployctl help

From the repository root:

```bash
sudo bash deployctl/install.sh
deployctl --help
deployctl errors-help
```

## On Ubuntu VM: normal mode dry-run

```bash
deployctl -n -l /tmp/deployctl-demo-logs deploy demo-app \
  --repo https://example.com/demo.git \
  --domain demo.example.com \
  --port 8080 \
  --ssl no
```

## On Ubuntu VM: subshell mode

```bash
deployctl -n -s -l /tmp/deployctl-demo-logs deploy app-sub \
  --repo https://example.com/sub.git \
  --domain sub.example.com \
  --port 3003 \
  --ssl no
```

## On Ubuntu VM: fork mode

```bash
deployctl -n -f -l /tmp/deployctl-demo-logs deploy app-fork \
  --repo https://example.com/fork.git \
  --domain fork.example.com \
  --port 3001 \
  --ssl no
```

## On Ubuntu VM: thread flag

This command proves the flag is accepted, but current code does not implement parallel behavior.

```bash
deployctl -n -t -l /tmp/deployctl-demo-logs deploy app-thread \
  --repo https://example.com/thread.git \
  --domain thread.example.com \
  --port 3002 \
  --ssl no
```

## On Ubuntu VM: custom log directory

```bash
deployctl -n -v -l /tmp/deployctl-demo-logs check
cat /tmp/deployctl-demo-logs/history.log
```

## On Ubuntu VM: restore/admin-only behavior as non-root

```bash
deployctl -r status demo-app
```

Expected result when not root: error code `112` with message similar to `restore-mode requires root`.

## On Ubuntu VM: restore/admin-only behavior with sudo

```bash
sudo deployctl -r status demo-app
```

If `demo-app` has no metadata, the expected result is a config error after the root check. For a real restore:

```bash
sudo deployctl restore demo-app
```

## On Ubuntu VM: show history.log

Default production path:

```bash
sudo tail -n 50 /var/log/deployctl/history.log
```

Demo custom path:

```bash
cat /tmp/deployctl-demo-logs/history.log
```

## On Ubuntu VM: real deployment and curl

Use a real Git repository containing a `Dockerfile` and an application listening on the chosen port.

```bash
sudo deployctl deploy demo-app \
  --repo https://github.com/example/demo-app.git \
  --domain demo.example.com \
  --port 8080 \
  --ssl no

curl -I http://127.0.0.1:8080
curl -I http://demo.example.com
```

## On Windows host: run inboxctl if supported

Use Git Bash or WSL from the repository root:

```bash
bash inboxctl/install.sh
inboxctl --help
inboxctl add-server prod1 sernine@192.168.1.78
inboxctl test prod1
inboxctl fetch prod1
inboxctl show servers
inboxctl show projects prod1
inboxctl errors prod1
inboxctl logs prod1 demo-app
```

If Windows PowerShell is used directly, Bash scripts require an environment such as Git Bash, WSL, or another Bash-compatible shell.

# 11. Screenshot checklist

| Screenshot number | Terminal / machine | Command to run | What the screenshot proves | Where to place it in the report |
|---|---|---|---|---|
| 1 | Windows or Ubuntu repo terminal | `tree /F` on Windows or `find . -maxdepth 3 -type f \| sort` on Linux | Project tree and modular structure | Repository structure section |
| 2 | Ubuntu VM | `deployctl --help` | Help option exists and shows syntax | CLI/options section |
| 3 | Windows host | `ssh sernine@192.168.1.78` | SSH connection between workstation and VM | Architecture/demo section |
| 4 | Ubuntu VM | `sudo deployctl deploy demo-app --repo <real-repo> --domain <domain> --port 8080 --ssl no` | Successful deployment pipeline | Main execution flow / demo |
| 5 | Ubuntu VM or browser | `curl -I http://127.0.0.1:8080` and browser to domain/IP | App is reachable after deployment | Results section |
| 6 | Ubuntu VM | `sudo tail -n 20 /var/log/deployctl/history.log` | Required log name and format | Logging section |
| 7 | Ubuntu VM | `deployctl status bad_name` or `deployctl unknown` | Error handling and error code/help hint | Error handling section |
| 8 | Ubuntu VM | `deployctl -n -f -l /tmp/demo-logs deploy app-fork ...` | Fork flag accepted and dry-run deploy works | Process execution section |
| 9 | Ubuntu VM | `deployctl -n -s -l /tmp/demo-logs deploy app-sub ...` | Subshell flag accepted and deploy path executes | Process execution section |
| 10 | Ubuntu VM | `deployctl -n -t -l /tmp/demo-logs deploy app-thread ...` plus code snippet showing no thread branch | `-t` is accepted but incomplete | Missing requirements section |
| 11 | Ubuntu VM non-root | `deployctl -r status demo-app` | Admin-only/root behavior for restore mode | Access control section |
| 12 | Ubuntu VM root | `sudo deployctl -r status demo-app` or `sudo deployctl restore demo-app` | Sudo changes permission behavior | Access control/demo section |
| 13 | Windows Git Bash/WSL | `inboxctl add-server prod1 sernine@192.168.1.78` | inboxctl server registration | inboxctl section |
| 14 | Windows Git Bash/WSL | `inboxctl fetch prod1` then `inboxctl show projects prod1` | inboxctl fetches and displays deployctl state | inboxctl results section |

# 12. Report-ready explanations

## Identification du besoin

Le projet repond au besoin d'une equipe qui souhaite deployer une application Docker monolithique sur un seul VPS sans utiliser une plateforme complexe comme Kubernetes. Il ajoute aussi un outil de consultation locale permettant de verifier l'etat des deploiements et les journaux sans modifier le serveur distant.

## Objectifs du projet

L'objectif principal est de fournir deux scripts Bash complementaires. `deployctl` automatise le deploiement cote serveur: recuperation du code, construction Docker, lancement du conteneur, configuration nginx, verification de sante et journalisation. `inboxctl` permet ensuite de consulter depuis un poste local les fichiers de configuration et les logs generes par `deployctl`.

## Architecture globale

L'architecture est modulaire. Les constantes, formats et validateurs communs sont places dans `shared/`. Le dossier `deployctl/` contient le programme serveur et ses modules specialises. Le dossier `inboxctl/` contient le programme local, ses modules SSH, cache, parsing et affichage. Les deux outils communiquent indirectement par SSH et par les fichiers standards produits sur le serveur.

## Choix technologiques

Le projet utilise Bash pour respecter le cadre du devoir et pour s'integrer naturellement aux commandes Linux. Docker sert a isoler l'application deployee. nginx sert de reverse proxy HTTP. SSH et SCP servent a recuperer les informations depuis le poste local. Les fichiers de configuration sont de simples fichiers `KEY=value`, faciles a lire et a parser.

## Fonctionnement de deployctl

`deployctl` commence par charger les constantes partagees et les modules de deploiement. Selon la commande choisie, il verifie les dependances, clone le depot Git, prepare le fichier d'environnement, construit l'image Docker, lance le conteneur, effectue un controle de sante, ecrit la configuration nginx puis enregistre les metadonnees du projet.

## Fonctionnement de inboxctl

`inboxctl` fonctionne comme un outil de supervision en lecture seule. Il enregistre d'abord des serveurs sous forme de fichiers locaux, puis utilise SSH/SCP pour copier les metadonnees et logs de `deployctl` dans un cache local. Les commandes `show`, `logs`, `errors` et `watch` affichent ensuite ces donnees dans le terminal.

## Gestion des logs

Les logs principaux de `deployctl` sont stockes dans `/var/log/deployctl/history.log`. Chaque application possede aussi un fichier dans `/var/log/deployctl/projects/`. Le format actuel est `yyyy-mm-dd-hh-mm-ss : username : INFOS/ERROR : message`, ce qui correspond au format demande. L'option `-l` permet de choisir un repertoire de log alternatif pour les tests.

## Gestion des erreurs

Les codes d'erreur sont centralises dans `shared/constants.sh` avec des valeurs de 100 a 120. Cote `deployctl`, la fonction `exit_with_error` journalise l'erreur, affiche le code et conseille d'utiliser `deployctl --help`. Cote `inboxctl`, certains codes sont reutilises, mais la gestion n'est pas aussi centralisee.

## Execution normale

En execution normale, `deployctl_dispatch` appelle directement la fonction correspondant a la commande. Par exemple, `deployctl deploy ...` appelle `deployctl_cmd_deploy` dans le meme processus Bash.

## Execution par subshell

L'option `-s` active une execution par sous-shell pour la commande `deploy`. Le code utilise la syntaxe Bash `( deployctl_cmd_deploy "$@" )`, ce qui cree un contexte d'execution separe pour le corps du deploiement.

## Execution par fork

L'option `-f` lance le deploiement en arriere-plan avec `&`, puis le script attend la fin du processus fils avec `wait $!`. Il s'agit donc bien d'un processus enfant, mais l'execution reste synchrone du point de vue de l'utilisateur.

## Execution parallele/thread-like

L'option `-t` est analysee par le parseur CLI et positionne `DEPLOYCTL_THREAD_MODE=1`. Cependant, aucune branche du programme n'utilise cette variable. L'execution parallele ou thread-like est donc manquante dans le code actuel.

## Scenarios de test

Trois scenarios existent pour `deployctl`: un test leger pour `check` en dry-run, un test moyen pour `deploy` avec parametres explicites, et un test lourd qui appelle les options `-f`, `-t` et `-s` en dry-run. Deux tests `inboxctl` verifient le parsing des fichiers de configuration et le format des logs.

## Difficultes rencontrees

Les principales difficultes techniques concernent la gestion des operations sensibles sur le serveur: droits root, ecriture dans `/etc` et `/var`, interaction avec Docker, nginx et certbot, ainsi que la necessite de nettoyer correctement un deploiement partiellement echoue.

## Perspectives d'amelioration

Les ameliorations prioritaires sont l'implementation reelle du mode `-t`, l'ajout d'une restauration des parametres par defaut si elle est exigee, la capture complete de stdout/stderr dans les logs, et l'ajout d'archives compressees pour les applications archivees.

# 13. One-slide presentation content

Title: `deployctl / inboxctl - Bash deployment and inspection toolkit`

Problem: Small teams need a simple way to deploy one Docker application on a VPS and inspect deployment state without a complex platform.

Solution: `deployctl` automates server deployment; `inboxctl` fetches remote metadata/logs read-only over SSH.

Architecture labels:

- Windows workstation: `inboxctl`
- SSH/SCP link: key-based remote access
- Ubuntu VPS: `deployctl`
- Server services: Docker, nginx, optional certbot
- Shared contract: `/etc/deployctl`, `/var/lib/deployctl`, `/var/log/deployctl/history.log`

Implemented options:

- `-h`: help
- `-n`: dry-run
- `-l`: custom log directory
- `-s`: subshell deploy
- `-f`: child-process deploy with wait
- `-r`: root-gated restore mode
- `-t`: parsed but not implemented as real parallel execution

Demo results:

- Help displayed successfully
- Dry-run deploy logs generated
- `history.log` format matches required format
- SSH/inboxctl can fetch and display project metadata if remote permissions allow

Conclusion sentence: The project already demonstrates a modular Bash deployment workflow, but it should add real thread-like execution and stronger logging capture before final submission.

# 14. Final recommendations

## Critical

- Implement real `-t` thread-like parallel execution in `deployctl_dispatch` or a dedicated function. Current status: Missing.
- Clarify or implement `-r` according to the teacher requirement "restore default settings admin-only". Current code uses restore mode/root gating, not default settings restoration.
- Add proof-oriented output/logging for `-f`, `-s`, and future `-t`, for example logging mode name and PID/BASHPID.

## Important

- Capture stdout and stderr more completely into `history.log`, for example through a central command runner or `tee`.
- Add a centralized inboxctl error function similar to `exit_with_error`.
- Show help hints after inboxctl errors.
- Add compression to archive behavior if "archiving/compression" is interpreted strictly.
- Add a real VM integration demo script or documented transcript for deploy/archive/restore.

## Nice to have

- Remove or use currently unused helpers such as `escape_sed_replacement`, `normalize_path`, `validate_status`, and `validate_dir_exists`.
- Add line or mode markers in logs for dry-run/fork/subshell/thread demonstrations.
- Add more robust validation for `--ssl` values.
- Add tests that assert `-t` behavior once implemented.
- Replace placeholder maintainer/repository values before submission or publication.
