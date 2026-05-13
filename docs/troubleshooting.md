<!--
Project: deployctl-inboxctl
SPDX-License-Identifier: MIT
Maintainer: YOUR_NAME <YOUR_EMAIL>
Repository: https://github.com/YOUR_ORG/YOUR_REPO
Copyright: (c) YOUR_NAME_OR_ORG - see LICENSE
-->
# Troubleshooting

Common issues when developing or running **deployctl** and **inboxctl** outside a production Linux VPS.

---

## Git Bash or Windows paths

**Symptom:** Errors writing to `/var/log/deployctl/...` or missing Linux commands.

**Cause:** These tools target **Linux** paths and utilities. Git Bash is not a full Linux environment.

**What to do:**

- Use **`deployctl -n check`** (dry-run) for a quick CLI smoke test without root or Docker.
- For a full **`check`** or **`deploy`**, use **WSL2 Ubuntu**, a **VM**, or a **real VPS**.
- If logging falls back to the user cache, history files may appear under `~/.cache/deployctl/logs/` when `/var/log/deployctl` is not writable.

---

## Missing dependencies (`deployctl check`)

**Symptom:** `missing dependencies: docker`, `nginx`, `iproute2/ss`, etc.

**Cause:** `deployctl check` verifies `docker`, `git`, `nginx`, `curl`, and `ss` (from **iproute2** on Debian/Ubuntu).

**What to do (Debian/Ubuntu/WSL):**

```bash
sudo apt-get update
sudo apt-get install -y docker.io git nginx curl iproute2
sudo systemctl enable --now docker nginx   # if using systemd
```

---

## SSH / inboxctl fetch failures

**Symptom:** `inboxctl fetch` or `test` fails; `scp` permission denied.

**Cause:** Remote paths (`/etc/deployctl`, `/var/log/deployctl`) are often **root-readable only**.

**What to do:**

- Use an SSH user that can read those paths (e.g. **root** or a user with **sudo** + adjusted permissions). This repository does **not** store passwords; use **SSH keys** only.
- Ensure **BatchMode** SSH works (`ssh-agent`, correct key).
- If `scp` cannot read files, use server-side **sudo** + **tar** pipelines (future enhancement) or copy as a privileged user.

---

## Dry-run vs real deploy

| Command | Behavior |
|---------|----------|
| `deployctl -n check` | Skips live dependency checks; safe on laptops. |
| `deployctl -n deploy ...` | Validates inputs then exits before clone/build. |
| `deployctl check` (no `-n`) | Requires real tools and often **root** for layout under `/etc`, `/var`. |

---

## Logs and `USER` showing `unknown`

**Symptom:** Log lines show `unknown` as the username.

**Cause:** `USER` may be unset in some non-interactive environments.

**What to do:** Export `USER` or run from a normal login shell; optional improvement is to default to `id -un` in shared logging (contributions welcome).

---

## Further help

- Architecture: [architecture.md](architecture.md)  
- Requirements detail: [cahier-de-charge.md](cahier-de-charge.md)  
- Project metadata placeholders: [project-information.md](project-information.md)  
