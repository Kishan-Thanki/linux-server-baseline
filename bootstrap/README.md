# Bootstrap

## Purpose

The `bootstrap` directory defines the **operating system baseline** for every server managed by this platform.

Bootstrap configures the operating system.

Once bootstrap has completed successfully, every server should have the same secure, predictable baseline regardless of when or where it was created.

Bootstrap represents **platform configuration**, not application configuration.

## Directory Structure

```text
bootstrap/
├── setup/             One-time scripts. Run in order. Delete after.
│   ├── 01-essential.sh
│   ├── 02-create-user.sh
│   ├── 03-firewall.sh
│   ├── 04-system-tuning.sh
│   ├── 05-ssh-hardening.sh      ⚠️ STOP POINT
│   ├── 06-remove-default.sh
│   ├── 07-caddy.sh
│   ├── 08-deploy-setup.sh
│   ├── 09-ops-tooling.sh
│   └── 10-system-maintenance.sh
│
├── maintain/          Persistent scripts. Stay on server.
│   ├── refresh.sh
│   └── cleanup.sh
│
└── BOOTSTRAP.md

```

## Workflow

```text
    Spin up a new server
             │
             ▼
Copy setup/ + maintain/ to server 
     (Currently Manually)
             │
             ▼
Run setup scripts 01 → 10 in order
     (Currently Manually) 
             │
             ▼
Delete setup/ scripts from server
     (Currently Manually)
             │
             ▼
    Server is platform-ready
             │
             ▼
Run maintain/ scripts periodically
     (Currently Manually)

```

# Scope

Bootstrap is responsible for configuring the operating system and installing platform software required by every server.

This includes:

* Operating system updates
* Security hardening
* Base utilities
* User configuration
* SSH configuration
* Firewall configuration
* System tuning
* Swap configuration
* Monitoring agents
* Backup prerequisites
* Platform services
* Reverse proxy installation
* Base filesystem layout
* Automated security updates & log rotation

Bootstrap intentionally remains application-agnostic.

# Bootstrap Ownership

Bootstrap owns everything below the operating system but above deployed applications.

```text
  Infrastructure
        │
  ──────────────
 Operating System
        │
    Bootstrap
        │
Configured Server
  ──────────────
        │
    Deployment
        │
   Applications

```

Bootstrap never owns application code.

# Setup Scripts

## 01 — Essential Packages

* Update package index
* Upgrade installed packages
* Install common utilities: git, curl, wget, zip, unzip, tree, jq, htop, ca-certificates, software-properties-common

## 02 — Platform User

Create the platform administration account.

Configure:

* SSH keys (copied from current user)
* sudo access
* shell
* permissions

## 03 — Firewall & Intrusion Protection

Configure UFW and Fail2Ban together.

UFW rules:

* SSH (22/tcp)
* HTTP (80/tcp)
* HTTPS (443/tcp)

Fail2Ban:

* sshd jail enabled
* Ban action via UFW
* 1h ban, 10m findtime, 5 max retries

## 04 — System Tuning

Configure operating system defaults and swap.

* Timezone (UTC)
* systemd-journald (persistent, compressed, size-limited)
* Kernel parameters (swappiness, vfs_cache_pressure, file-max)
* File descriptor limits (65535)
* Swap (2G swapfile + fstab entry)

## 05 — SSH Hardening ⚠️ STOP POINT

Configure OpenSSH security settings.

Settings applied:

* Disable root login
* Disable password authentication
* Public-key authentication only
* Max 3 auth tries
* 30 second login grace time

**After running this script, open a NEW terminal and verify SSH access before continuing.**

**DO NOT close the current session until you verify the new SSH login works.**

## 06 — Remove Default User

Remove cloud image users that are no longer required.

* Removes the `ubuntu` user
* Must be logged in as admin (not ubuntu)
* Kills remaining processes and removes home directory

## 07 — Caddy

Install Caddy reverse proxy from the official repository.

Bootstrap owns:

* Installing Caddy
* Enabling the systemd service
* Starting Caddy
* Maintaining package updates

Bootstrap does **not** own:

* Application domains
* Reverse proxy routes
* TLS certificates for applications
* Application-specific Caddyfiles

Those belong to Deployment.

## 08 — Deployment Setup

Prepare the platform for application deployments.

* Create `/opt/platform/{releases,shared,tmp,logs}`
* Create `deploy` user
* Configure restricted sudoers (mkdir, tar, ln only)
* Set ownership of `/opt/platform` to deploy user

## 09 — Operational Tooling

Install monitoring and backup prerequisites.

Monitoring:

* btop, iotop, ncdu, vnstat, sysstat
* Enable vnstat and sysstat services

Backup:

* rsync, tar, gzip
* Create `/opt/backups/{system,database,apps,archive}`

## 10 — System Maintenance & Automation

Configure long-term background system health and security automation.

* Install and configure `unattended-upgrades` for automated daily security patches
* Configure custom `logrotate` policy for application logs in `/opt/platform/logs/*.log` (daily rotation, 14-day retention, gzip compression)

# Maintain Scripts

## refresh.sh

Periodic system maintenance.

* Update package index
* Upgrade packages
* Clean apt cache

Run before setup on stale servers, or periodically on live servers.

## cleanup.sh

Periodic cleanup.

* Vacuum systemd journal (30 days)
* Clean /tmp and /var/tmp (files older than 7 days)
* Clean apt package cache

# Validation

Bootstrap is considered successful when:

* Required packages are installed
* Required services are enabled
* Required services are running
* SSH remains accessible
* Firewall rules are correct
* System configuration matches platform standards

For example:

```text
✓ caddy installed
✓ caddy running
✓ caddy enabled

✓ ufw enabled

✓ fail2ban running

✓ platform user exists

✓ ssh hardened

✓ unattended-upgrades configured
✓ logrotate configured

```

# Design Principles

Every bootstrap script must be:

* Idempotent
* Repeatable
* Non-interactive
* Safe to rerun
* Platform-wide
* Version controlled
* Deterministic

Running bootstrap multiple times should never damage an existing server.

# Bootstrap Does NOT Own

Bootstrap must never:

* Clone repositories
* Deploy applications
* Install project dependencies
* Configure application secrets
* Configure application domains
* Configure project reverse proxies
* Run database migrations
* Restart application services
* Provision infrastructure

Those responsibilities belong elsewhere.

# Relationship with Other Platform Components

```text
  Creates infrastructure
            │
      ──────────────
        Bootstrap
            │
 Creates platform baseline
            │
      ──────────────
        Deployment
            │
     Deploys services
            │
      ──────────────
       Applications

```

Each layer has a single responsibility.

# Future Improvements

Bootstrap may later include:

* Cloud-init support
* Server role profiles
* Platform validation tooling
* Bootstrap logging
* Bootstrap reporting
* Bootstrap rollback support
* Single orchestration script to run all setup scripts in sequence

These improvements should remain platform-focused.

# Goal

Bootstrap exists so that every newly provisioned server reaches a known, reproducible platform baseline.

After Terraform provisions infrastructure and Bootstrap completes successfully, the server should be considered **platform-ready**.

Only then should the Deployment layer install application services.

# Future Scope

Thinking to use ansible to automate as much as it could.

