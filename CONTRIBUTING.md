<!--
Project: deployctl-inboxctl
SPDX-License-Identifier: MIT
Maintainer: YOUR_NAME <YOUR_EMAIL>
Repository: https://github.com/YOUR_ORG/YOUR_REPO
Copyright: (c) YOUR_NAME_OR_ORG - see LICENSE
-->
# Contributing

Before publishing the project, replace placeholders in **`docs/project-information.md`**, [`AUTHORS.md`](AUTHORS.md), [`SECURITY.md`](SECURITY.md), and [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md). Keep [`LICENSE`](LICENSE) copyright in sync with your organization or yourself.

## Naming rules

- **Application names** use **kebab-case** (for example `mantouji`, `demo-app`).
- **Shell functions** use **snake_case** (for example `deployctl_cmd_deploy`, `read_conf_value`).
- **CLI commands** stay lowercase with hyphens where shown (`deployctl`, `inboxctl`, `add-server`).

## Schema and contracts

- Do **not** change `.conf` field names or semantics without team agreement and a documented migration path.
- Do **not** change the deployctl log line format (`yyyy-mm-dd-hh-mm-ss : user : LEVEL : message`).
- Shared paths and error codes live in `shared/constants.sh`; treat edits there as a breaking-change review.

## Quality bar

- Run `scripts/format.sh` so CLI and test scripts stay executable, then run `scripts/verify-format.sh` locally if you want to match CI.
- Run `scripts/lint.sh` (and fix issues) before opening a merge request.
- Run deployctl and inboxctl tests under Bash on Linux when touching runtime logic.
- CI (`.github/workflows/ci.yml`) runs format verification, lint, documentation presence checks, and tests on every push and pull request.
- Prefer small, reviewable changes over mixed refactors.

## Module ownership

- **`shared/`** — cross-tool contracts (paths, validation, formatting).
- **`deployctl/lib/`** — server-side deployment pipeline only.
- **`inboxctl/lib/`** — local SSH fetch/parse/UI only; must remain read-only toward remote deployctl data.

When in doubt, open a short design note in `docs/architecture.md` or the cahier des charges before expanding scope.
