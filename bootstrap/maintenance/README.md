# Server Maintenance

This directory contains manual maintenance utilities for servers provisioned by the `server-ops` bootstrap system.

These scripts are intended to be run by the permanent `admin` account.

## Directory

```text
server-ops/
└── bootstrap/
    └── maintenance/
        ├── README.md
        ├── refresh.sh
        └── cleanup.sh
```

## Scripts

### `refresh.sh`

Performs a manual operating-system package refresh.

It:

* Updates the APT package index
* Upgrades installed packages
* Removes packages no longer required
* Cleans the local APT package cache
* Checks for remaining upgradable packages
* Checks the `dpkg` package state
* Displays root filesystem usage

Run:

```bash
refresh
```

This script does not:

* Deploy applications
* Restart application services
* Modify SSH configuration
* Modify firewall configuration
* Modify Caddy configuration
* Configure backups
* Delete application releases
* Delete deployment logs

### `cleanup.sh`

Performs a manual system cleanup.

It:

* Removes systemd journal entries older than 30 days
* Removes files older than 7 days from `/tmp`
* Removes empty old directories from `/tmp`
* Removes files older than 7 days from `/var/tmp`
* Removes empty old directories from `/var/tmp`
* Removes unnecessary APT packages
* Cleans the local APT package cache
* Displays journal, temporary-directory, APT-cache, and filesystem usage

Run:

```bash
cleanup
```

This script does not:

* Deploy applications
* Modify SSH configuration
* Modify firewall configuration
* Modify Caddy configuration
* Delete application releases
* Delete deployment logs
* Delete backups
* Modify `/opt/backups`
* Modify the deployment environment

## Recommended Usage

The scripts have intentionally separate responsibilities.

For an operating-system package refresh:

```bash
refresh
```

For filesystem and journal cleanup:

```bash
cleanup
```

If both operations are required, run them separately rather than combining their responsibilities into another script.

## Safety Boundaries

The maintenance scripts intentionally avoid application and deployment data.

In particular, they do not automatically remove:

```text
/opt/platform/releases
/opt/platform/shared
/opt/platform/logs
/opt/backups
```

Application release pruning, deployment cleanup, backup retention, and application-specific cleanup must be handled by their respective deployment or backup mechanisms.

Do not add broad recursive deletion commands to these scripts without explicitly defining the target path and retention policy.

## Required Access

The scripts expect the permanent administrator account to have working passwordless sudo access.

Before running either script, verify:

```bash
sudo -n true
```

A successful command produces no output and exits with status `0`.

## Execution

Make sure the scripts are executable:

```bash
chmod +x /path/to/refresh /path/to/cleanup
```

Then run the required operation:

```bash
refresh
```

or:

```bash
cleanup
```

## Recommended Command Installation

For servers using these maintenance utilities regularly, it is recommended to install the scripts into `/usr/local/bin/`.

This allows them to be executed directly as:

```bash
refresh
```

and:

```bash
cleanup
```

For example:

```bash
sudo install -m 0755 refresh.sh /usr/local/bin/refresh
sudo install -m 0755 cleanup.sh /usr/local/bin/cleanup
```

The repository remains the source of truth for the scripts, while `/usr/local/bin/` provides convenient system-wide command access.

This is a recommendation, not a requirement. You may instead keep the scripts in another location and execute them according to your server's preferred directory structure and operational practices.

## Failure Behavior

Both scripts use:

```bash
set -euo pipefail
```

A failed command causes the script to stop rather than silently continuing with potentially incomplete maintenance.

Review the command output before treating a maintenance operation as successful.

## Scope

These scripts are intentionally generic server-maintenance utilities.