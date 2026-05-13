<!--
Project: deployctl-inboxctl
SPDX-License-Identifier: MIT
Maintainer: YOUR_NAME <YOUR_EMAIL>
Repository: https://github.com/YOUR_ORG/YOUR_REPO
Copyright: (c) YOUR_NAME_OR_ORG - see LICENSE
-->
# Architecture

## Global architecture

```mermaid
flowchart LR
  subgraph Workstation
    IC[inboxctl]
    CACHE[~/.cache/inboxctl]
    IC --> CACHE
  end
  subgraph VPS
    DC[deployctl]
    NG[nginx]
    DK[Docker]
    DC --> DK
    DC --> NG
  end
  IC -->|SSH read-only fetch| DC
```

## Deploy lifecycle

```mermaid
sequenceDiagram
  participant Op as Operator
  participant D as deployctl
  participant G as git
  participant K as Docker
  participant N as nginx
  Op->>D: deploy app
  D->>G: clone to pending
  D->>K: build / run
  D->>N: render config / reload
  D->>D: move pending to live
```

## inboxctl fetch flow

```mermaid
flowchart TD
  A[inboxctl fetch server] --> B[SSH / scp read-only]
  B --> C[/etc/deployctl/projects.d]
  B --> D[/var/log/deployctl/history.log]
  B --> E[/var/log/deployctl/projects/*.log]
  B --> F[/var/lib/deployctl/state optional]
  C --> G[~/.cache/inboxctl/servers/name]
  D --> G
  E --> G
  F --> G
```

## Repository folder structure

```mermaid
flowchart TB
  R[deployctl-inboxctl]
  R --> S[shared]
  R --> D[deployctl]
  R --> I[inboxctl]
  R --> X[scripts]
  R --> DOC[docs]
  S --> C1[constants.sh]
  D --> L[lib modules]
  I --> M[lib modules]
```

Secrets never live in repository-tracked `.conf` samples — only on-server `/var/lib/deployctl/env/*.env`.
