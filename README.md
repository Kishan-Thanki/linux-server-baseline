# Server Operations & Platform Automation

## Overview

This repository defines the infrastructure bootstrap baseline, system maintenance utilities, and deployment pipelines for managing production Linux servers.

The platform is split into distinct, single-responsibility layers:
1. **Bootstrap** — Establishes a secure, predictable, and hardened operating system baseline from scratch.
2. **Deployment** — Manages application delivery, atomic releases, zero-downtime symlink promotion, health checks, and automatic rollbacks.

## Repository Structure

```text
.
├── README.md               Root platform overview and architecture reference
├── bootstrap/              Operating system baseline configuration
│   ├── README.md           Bootstrap documentation and guidelines
│   ├── maintenance/        Persistent maintenance and cleanup scripts
│   └── setup/              One-time idempotent provisioning scripts (01 → 10)
└── deployment/             Application delivery and execution engine
    ├── README.md           Deployment pipeline documentation
    ├── deploy.sh           Server-side atomic deployment & auto-rollback engine
    ├── docs/               Operational guides (e.g., GitHub Actions setup)
    └── templates/          CI/CD workflow templates (GitHub Actions)

```

## Core Architecture Layers

```text
             Terraform (Infrastructure Provisioning)
                               │
                               ▼
               Bootstrap (OS Baseline & Hardening)
                               │
                               ▼
             Deployment (Atomic Release & Lifecycle)
                               │
                               ▼
                 Applications (Running Services)

```

### 1. Bootstrap (`bootstrap/`)

Transforms a bare cloud instance into a secure, self-maintaining platform server.

* **Setup Scripts (`bootstrap/setup/`)**: Run sequentially (01 through 10) to configure essential packages, platform users, UFW/Fail2Ban firewalls, system tuning, SSH hardening, Caddy web server, deployment layout, observability tooling, and automated system maintenance (`unattended-upgrades` & `logrotate`).
* **Maintenance Scripts (`bootstrap/maintenance/`)**: Persistent utilities (`refresh.sh`, `cleanup.sh`) for ongoing log vacuuming and package management.

### 2. Deployment (`deployment/`)

Handles code delivery safely from external CI/CD pipelines (like GitHub Actions) to the server.

* **`deploy.sh`**: Robust server-side engine running at `/opt/platform/deploy.sh`. Handles atomic locking, sha256 checksum verification, extraction, symlink switching, systemd restarts, HTTP validation, automated rollbacks, and old release pruning.
* **CI/CD Templates (`deployment/templates/deploy.yml`)**: Standardized workflows enforcing safety guardrails and secure asset downloads.