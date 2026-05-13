<!--
Project: deployctl-inboxctl
SPDX-License-Identifier: MIT
Maintainer: YOUR_NAME <YOUR_EMAIL>
Repository: https://github.com/YOUR_ORG/YOUR_REPO
Copyright: (c) YOUR_NAME_OR_ORG - see LICENSE
-->
# deployctl-inboxctl

Opinionated **Bash** tooling for **single-host Docker monolith** deployments (`deployctl` on the VPS) and a **read-only** workstation inspector (`inboxctl`) that snapshots remote deployctl metadata over **SSH keys** (never passwords).

<!-- Optional status badges (replace YOUR_* after publishing). Uncomment and fix URLs.
[![CI](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
-->

## Project metadata (open source)

**Every** Markdown, shell script, workflow, template, and example file includes the **same** placeholder fields at the top (project name, SPDX `MIT`, maintainer, repository URL). Replace them project-wide before announcing publicly — see [`docs/project-information.md`](docs/project-information.md).

| Topic | Where |
|--------|--------|
| Author / maintainer, repo URLs, checklist | [`docs/project-information.md`](docs/project-information.md) |
| Credits | [`AUTHORS.md`](AUTHORS.md) |
| Security reports | [`SECURITY.md`](SECURITY.md) |
| Community conduct | [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) |
| License | [`LICENSE`](LICENSE) — update copyright name if you fork |

**Version** is defined in `shared/constants.sh` (`DEPLOYCTL_INBOXCTL_VERSION`).

## Documentation

| Document | Description |
|----------|-------------|
| [docs/README.md](docs/README.md) | Index of all documentation |
| [docs/architecture.md](docs/architecture.md) | Diagrams and structure |
| [docs/cahier-de-charge.md](docs/cahier-de-charge.md) | Scope, objectives, contracts |
| [docs/benchmark.md](docs/benchmark.md) | Comparison with other approaches |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Git Bash, WSL, dependencies, SSH |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute, CI, naming |

## Why two tools?

- **deployctl** mutates the server: clones git sources, builds images, runs containers, writes nginx snippets, and optionally drives TLS.
- **inboxctl** never writes remote deployctl data. It **fetches** `/etc/deployctl/projects.d`, logs, and optional state into `~/.cache/inboxctl` for tabular review.

Both share contracts in `shared/` (paths, statuses, validators, log formatting).

## Install deployctl only (server)

As root, from this repository:

```bash
sudo bash deployctl/install.sh
```

This installs libraries under `/usr/local/lib/deployctl`, places `/usr/local/bin/deployctl`, and creates standard directories under `/etc`, `/var/lib`, `/var/log`, and `/var/cache`.

Uninstall:

```bash
sudo bash deployctl/uninstall.sh
```

## Install inboxctl only (workstation)

Without root (defaults to `~/.local/bin` when `/usr/local/bin` is not writable):

```bash
bash inboxctl/install.sh
```

Ensure your `PATH` includes the printed bin directory. Configure **SSH keys** (`ssh-copy-id`) toward each server user you declare.

Uninstall:

```bash
bash inboxctl/uninstall.sh
```

## Quick start

**Server**

```bash
sudo deployctl check
sudo deployctl deploy my-app \
  --repo 'https://github.com/you/my-app.git' \
  --domain 'my-app.example.com' \
  --port '8080' \
  --ssl no
```

Secrets end up **only** in `/var/lib/deployctl/env/my-app.env` (mode `600`). Project metadata is stored separately under `/etc/deployctl/projects.d/my-app.conf`.

**Workstation**

```bash
inboxctl add-server prod1 deploy@your.vps.ip
inboxctl test prod1
inboxctl fetch prod1
inboxctl show projects prod1
```

**Laptop / Git Bash:** use `deployctl -n check` for a safe dry-run; see [docs/troubleshooting.md](docs/troubleshooting.md).

## Commands (summary)

**deployctl:** `check`, `deploy`, `status`, `logs`, `archive`, `restore`, `list`, `ssl`, `menu`, `version`

**inboxctl:** `add-server`, `remove-server`, `list servers`, `show servers`, `test`, `fetch`, `show projects|live|pending|archive`, `logs`, `errors`, `watch`, `version`, `help`

Run `--help` on each CLI for details.

## Architecture

- **Shared contracts:** `shared/constants.sh`, `shared/validators.sh`, `shared/format.sh`
- **Server modules:** `deployctl/lib/mod_*.sh` (docker, nginx, health, archive, restore, …)
- **Local modules:** `inboxctl/lib/mod_*.sh` (ssh, fetch, parse, ui, watch, cache, …)

See [docs/architecture.md](docs/architecture.md) for diagrams.

## Folder structure

```
deployctl-inboxctl/
├── AUTHORS.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── LICENSE
├── README.md
├── SECURITY.md
├── docs/
├── shared/
├── deployctl/
├── inboxctl/
└── scripts/
```

## Security notes

- **No SSH passwords** are stored or prompted by these tools; use key-based auth.
- **Never** put production secrets in tracked `.conf` examples or project metadata files.
- On the server, real secrets live **only** under `/var/lib/deployctl/env/<app>.env`.
- **inboxctl** is designed to be **read-only** with respect to remote deployctl state (fetch via SSH/scp).
- Report security issues per [SECURITY.md](SECURITY.md) (update contact placeholders first).

## Examples

- `deployctl/examples/demo-app.conf` — metadata-only sample for demos.
- `deployctl/examples/demo.env.example` — shape for `.env.example` in a repo (not production secrets).
- `inboxctl/examples/servers.conf.example` — illustrates local server records.

## Tests and QA

```bash
bash scripts/format.sh   # chmod +x entrypoints
bash scripts/lint.sh     # bash -n (+ shellcheck when installed)
bash deployctl/tests/test_light.sh
bash inboxctl/tests/test_parse_conf.sh
```

## Continuous integration

GitHub Actions runs on pushes and pull requests to `main`/`master`: **executable-bit checks** (`scripts/verify-format.sh`), **lint** (`bash -n` and shellcheck), **required docs** (`scripts/check-docs.sh`), and the **test scripts** above. See `.github/workflows/ci.yml`.

## Teacher Demo Plan

1. `deployctl check`
2. `deployctl deploy` a demo app (`--repo`, `--domain`, `--port`, `--ssl no`)
3. `deployctl archive` the demo app
4. `deployctl restore` the demo app
5. `inboxctl add-server` with `user@host`
6. `inboxctl fetch` that server
7. `inboxctl show projects` for that server
8. `inboxctl watch` to refresh the snapshot every few seconds
