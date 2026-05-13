<!--
Project: deployctl-inboxctl
SPDX-License-Identifier: MIT
Maintainer: YOUR_NAME <YOUR_EMAIL>
Repository: https://github.com/YOUR_ORG/YOUR_REPO
Copyright: (c) YOUR_NAME_OR_ORG - see LICENSE
-->
# Security policy

## Supported versions

Security fixes are applied to the **latest minor release** on the active development branch (typically `main` / `master`). Replace the table below with your actual version policy when you ship releases.

| Version line | Supported |
|--------------|-----------|
| 1.x (current) | Yes |
| Before 1.0 | Best-effort |

---

## Reporting a vulnerability

**Please do not** file a public GitHub issue for undisclosed security vulnerabilities.

**Preferred:** Enable [GitHub private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) for this repository and use that flow.

**Email fallback (placeholder — replace before publishing):**  
Contact **YOUR_EMAIL** with subject line `[SECURITY] deployctl-inboxctl`.

Include:

- Short description of the issue and impact  
- Steps to reproduce (or proof-of-concept) if safe to share  
- Affected version / commit if known  

**Expected response time (placeholder):** Best-effort acknowledgement within **YOUR_BUSINESS_DAYS** business days.

---

## Scope (high level)

Items generally **in scope**:

- **deployctl** running as **root** on a server: unintended privilege escalation, unsafe handling of untrusted input leading to code execution, or broken isolation that exposes host secrets.
- **inboxctl** / SSH path: anything that turns read-only inspection into remote **write** or arbitrary command execution **without** the user’s intent.

Items generally **out of scope**:

- Compromise of the user’s SSH keys or VPS outside these scripts  
- Misconfiguration of Docker, nginx, or firewall by the operator  
- Denial-of-service against services unless caused solely by a bug in this repository’s scripts  

---

## Coordination

Project maintainers may coordinate disclosure after a fix is available. Credit in release notes is given when reporters wish to be named.
