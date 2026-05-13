<!--
Project: deployctl-inboxctl
SPDX-License-Identifier: MIT
Maintainer: YOUR_NAME <YOUR_EMAIL>
Repository: https://github.com/YOUR_ORG/YOUR_REPO
Copyright: (c) YOUR_NAME_OR_ORG - see LICENSE
-->
# Project information (template)

Use this file as the **single place to fill in** organization-wide metadata before publishing or releasing. Replace every `YOUR_*` placeholder; remove sections you do not need.

## Standard metadata in every file

Tracked sources share the **same placeholder fields** near the top:

| Format | Where it appears |
|--------|-------------------|
| Markdown (`*.md`) | HTML `<!-- ... -->` block: Project, SPDX, Maintainer, Repository, Copyright pointer |
| Bash (`*.sh`) | `#` block immediately after the shebang |
| `LICENSE` | Short HTML comment before the MIT text |
| GitHub Actions (`*.yml`) | `#` block before workflow keys |
| Templates / examples (`*.tpl`, `*.conf`, `*.example`) | Leading `#` comment lines |

Replace **`YOUR_NAME`**, **`YOUR_EMAIL`**, **`YOUR_ORG`**, **`YOUR_REPO`** (and copyright in `LICENSE`) in **one sweep** when you publish (search-and-replace across the repo).

To re-apply Markdown/Bash/`LICENSE` headers after adding new files on Windows, run from the repo root:

`powershell -ExecutionPolicy Bypass -File scripts/embed-project-headers.ps1`

---

## Identity

| Field | Placeholder | Your value |
|--------|-------------|------------|
| **Project display name** | `deployctl-inboxctl` | _keep or rename_ |
| **Short description** | _One line:_ Bash CLIs for Docker monolith deploy (`deployctl`) and read-only remote inspection (`inboxctl`). | |
| **License** | MIT — see `LICENSE` | |
| **SPDX identifier** | `MIT` | |

---

## People

| Role | Placeholder | Notes |
|------|-------------|--------|
| **Author / creator** | `YOUR_NAME` | Original author credit in README and `AUTHORS.md`. |
| **Lead maintainer** | `YOUR_NAME` | Day-to-day decisions; listed in `AUTHORS.md`. |
| **Maintainer email** | `YOUR_EMAIL` | Public contact; also used in `SECURITY.md` until GitHub private reporting is enabled. |
| **Organization** (optional) | `YOUR_ORG` | Company or community name for packaging and docs. |

---

## Repository and links

Replace placeholders with your real URLs.

| Link type | Placeholder |
|-----------|-------------|
| **Source repository** | `https://github.com/YOUR_ORG_OR_USER/deployctl-inboxctl` |
| **Issue tracker** | `https://github.com/YOUR_ORG_OR_USER/deployctl-inboxctl/issues` |
| **Discussions / forum** (optional) | `https://github.com/YOUR_ORG_OR_USER/deployctl-inboxctl/discussions` |
| **Documentation site** (optional) | `https://YOUR_ORG_OR_USER.github.io/deployctl-inboxctl` or _none_ |
| **Chat** (optional) | Matrix / Slack / IRC — `YOUR_CHAT_INVITE_URL` |

---

## Release and versioning

| Item | Placeholder |
|------|-------------|
| **Current major version line** | `1.x` (see `shared/constants.sh` → `DEPLOYCTL_INBOXCTL_VERSION`) |
| **Tag format** | `v1.0.0` (recommended SemVer) |
| **Changelog file** | Add `CHANGELOG.md` when you cut releases (optional). |

---

## Package / distribution (optional)

| Item | Placeholder |
|------|-------------|
| **Operating systems targeted** | Linux (glibc), VPS / WSL for development |
| **Install methods documented** | `deployctl/install.sh`, `inboxctl/install.sh` |

---

## Branding (optional)

| Item | Placeholder |
|------|-------------|
| **Logo** | Add under `docs/diagrams/` or `.github/` when available |
| **Badge snippet for README** | See README section “Status badges (optional)” |

---

## Checklist before going public

- [ ] Replace all `YOUR_*` placeholders in `AUTHORS.md`, `SECURITY.md`, and this file.
- [ ] Confirm `LICENSE` copyright line matches `YOUR_NAME` or `YOUR_ORG`.
- [ ] Enable GitHub **Security → Private vulnerability reporting** (recommended); then trim email-only wording in `SECURITY.md` if you prefer.
- [ ] Add real badges to `README.md` if desired.
