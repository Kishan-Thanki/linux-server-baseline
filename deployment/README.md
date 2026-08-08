# Deployment

## Purpose

The `deployment` directory defines the application deployment pipeline and release execution engine for the platform.

Bootstrap builds the operating system baseline.

Deployment manages application releases, version promotion, health validation, and zero-downtime rollbacks.

## Directory Structure

```text
deployment/
├── README.md               Overview of deployment architecture and standards
├── deploy.sh               Server-side atomic deployment and rollback engine
├── docs/                   Operational documentation
│   └── github-actions-setup.md Guide for configuring GitHub Actions SSH trust
└── templates/              CI/CD pipeline templates
    └── deploy.yml          Standardized GitHub Actions workflow template

```

## Workflow Architecture

```text
       Developer Push / Release Published
                     │
                     ▼
         GitHub Actions Workflow
     (Validates Tag & Downloads Asset)
                     │
                     ▼
        Secure SCP to Target Server
                     │
                     ▼
      Execution of /opt/platform/deploy.sh
      (Atomic Symlink, Restart, & Health Check)
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
   [ SUCCESS ]             [ FAILURE ]
   Prune Old Releases      Automatic Rollback

```

## Core Components

### 1. The Deployment Engine (`deploy.sh`)

A robust, production-grade Bash script resident on the server at `/opt/platform/deploy.sh`. It handles:

* Strict name and version validation (`$SAFE_NAME_RE`) to block path traversal attacks.
* Secure temporary file downloads via `mktemp`.
* Cryptographic integrity verification via `--sha256`.
* Atomic directory locking (`/var/lock/platform/`) to prevent race conditions from concurrent deployments.
* Release extraction into isolated timestamp/version directories under `/opt/platform/releases/{service}/{version}`.
* Atomic symlink switching (`current`).
* Systemd service integration and automatic HTTP health validation (`--health`).
* Automatic rollback to the previous working release upon failure.
* Retention cleanup (`prune_old_releases`) keeping the last `KEEP_RELEASES` versions.
* Centralized structured logging to `/var/log/platform/deployments.log`.

### 2. CI/CD Integration Template (`templates/deploy.yml`)

A standardized GitHub Actions workflow that:

* Listens to published GitHub releases or manual dispatch inputs.
* Enforces strict production safety guardrails against development/staging tags (`-dev`, `-test`, `-stag`, `-rc`).
* Automatically fetches immutable release assets and sha256 checksum files using the GitHub CLI (`gh`).
* Authenticates securely via SSH using dedicated repository secrets (`SSH_PRIVATE_KEY` and `SSH_HOST`).
* Invokes the server-side deployment engine with explicit parameters.

### 3. Documentation (`docs/github-actions-setup.md`)

Provides a complete guide for establishing secure, key-based SSH access between GitHub Actions runners and the target server's dedicated `deploy` user.