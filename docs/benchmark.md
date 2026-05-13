<!--
Project: deployctl-inboxctl
SPDX-License-Identifier: MIT
Maintainer: YOUR_NAME <YOUR_EMAIL>
Repository: https://github.com/YOUR_ORG/YOUR_REPO
Copyright: (c) YOUR_NAME_OR_ORG - see LICENSE
-->
# Benchmark-style comparison (qualitative)

This section compares common deployment approaches **conceptually** — not a formal performance benchmark.

| Approach | Strengths | Trade-offs |
|----------|-----------|------------|
| **Docker** | Portable units; ubiquitous tooling | Alone it does not define rollout, proxy, or secrets discipline |
| **Docker Compose** | Multi-service graphs on one host | Heavier mental model for simple monoliths; still needs glue for TLS/prod conventions |
| **Ansible** | Idempotent infra automation | Requires inventory and playbook maintenance; steeper for tiny teams |
| **Kubernetes** | Powerful scaling/scheduling | Operational overhead exceeds single-VPS monolith needs |
| **PM2** | Simple Node-centric process manager | Not Docker-native; different lifecycle than container images |
| **deployctl + inboxctl** | Opinionated single-host Docker flow + read-only remote observability | Single-host scope; not a cluster orchestrator |

**When deployctl/inboxctl fits:** one (or few) VPS deployments of **monolith containers**, nginx at the edge, git-based sources, and operators who want **SSH-key-only** inspection via inboxctl.
