<!--
Project: deployctl-inboxctl
SPDX-License-Identifier: MIT
Maintainer: YOUR_NAME <YOUR_EMAIL>
Repository: https://github.com/YOUR_ORG/YOUR_REPO
Copyright: (c) YOUR_NAME_OR_ORG - see LICENSE
-->
# Cahier des charges — deployctl / inboxctl

## Context

Small teams need a **predictable** way to deploy Docker monoliths on a single VPS without adopting a full PaaS. Operators also need a **safe local lens** into what the server believes is deployed, without granting interactive shell access to every stakeholder.

## Objectives

- Provide **deployctl**, a root-capable server tool that clones, builds, runs, proxies, and optionally TLS-wraps one app per container.
- Provide **inboxctl**, a **read-only** workstation tool that SSH-es into servers and copies deployctl metadata/logs into a local cache for inspection.
- Share **one repository** with strict contracts in `shared/` so paths, statuses, and exit codes never diverge silently.

## Scope

**In scope:** Bash-only CLIs, nginx reverse proxy, Docker CLI, optional certbot, SSH key auth, local cache under `~/.cache/inboxctl`.

**Out of scope:** Kubernetes, multi-host orchestration, secret storage in `.conf` files, storing SSH passwords.

## deployctl (server)

- Layout under `/etc/deployctl`, `/var/lib/deployctl`, `/var/log/deployctl`, `/var/cache/deployctl`.
- Deployment pipeline: clone → env → build → run → health → nginx → optional SSL → promote pending → live.
- Rollback on failure: remove new container, pending tree, broken nginx snippet; mark `STATUS=error` when a project conf exists.

## inboxctl (local)

- Configuration under `~/.config/inboxctl/servers.d/*.conf`.
- Fetch copies **read-only** snapshots: project confs, history log, project logs, optional state files.
- Parsing and tables never mutate remote paths.

## Sync contract

- **Metadata** in `/etc/deployctl/projects.d/<app>.conf`.
- **Secrets** only in `/var/lib/deployctl/env/<app>.env` on the server (chmod `600`).
- **Statuses:** `pending`, `live`, `archive`, `error`.

## CLI options

See `deployctl --help` and `inboxctl --help` for global flags and subcommands. Global deployctl flags include `--dry-run`, `--verbose`, and execution hints (`--fork`, `--thread`, `--subshell`).

## Error handling

- Fatal paths use numeric codes `100–120` defined in `shared/constants.sh`.
- Operators can map failures via `deployctl errors-help` (hidden helper) or documentation.

## Logging

- Global history: `/var/log/deployctl/history.log`.
- Per app: `/var/log/deployctl/projects/<app>.log`.
- Fixed format with `INFOS` / `ERROR` levels.

## Testing scenarios

- Dry-run `check` and `deploy` without Docker socket access (developer laptops).
- Parse sample conf/logs for regressions.
- Manual VPS validation for full deploy/archive/restore.

## Team split

- **Platform / SRE:** deployctl modules (`mod_docker`, `mod_nginx`, `mod_health`, packaging).
- **Developer experience:** inboxctl fetch/cache/UI and documentation.
- **Shared:** validators, constants, formatting utilities.
