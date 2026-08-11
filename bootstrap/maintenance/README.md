# Server Maintenance

Persistent administrative utilities for routine operating-system maintenance on servers configured with the `server-ops` bootstrap architecture.

These scripts are separate from server provisioning, application deployment, release management, and backup management.

> **Important:** These are privileged, persistent maintenance utilities. Review the scripts and verify their suitability for your server before use. They may modify installed packages, system journals, temporary files, and other system state. Retention periods and cleanup behavior should be reviewed against your operational, backup, logging, and compliance requirements.
>
> These scripts are provided as open-source reference tooling and may require customization for your environment. Use appropriate backups and recovery procedures before performing destructive maintenance operations. See the repository [Terms](../../TERMS.md), [Policy](../../POLICY.md), [Conditions](../../CONDITIONS.md), and [License](../../LICENSE) for the applicable repository-wide terms and policies.

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

Performs a manual APT package refresh.

It:

* Updates the APT package index
* Upgrades installed packages
* Removes packages that are no longer required
* Cleans the APT package cache
* Checks for remaining upgradable packages
* Checks the `dpkg` package state
* Displays root filesystem usage

Run directly from this directory:

```bash
./refresh.sh
```

If installed system-wide:

```bash
refresh
```

### `cleanup.sh`

Performs manual system and temporary-file cleanup.

It:

* Removes systemd journal entries older than **30 days**
* Removes files older than **7 days** from `/tmp`
* Removes empty directories older than **7 days** from `/tmp`
* Removes files older than **7 days** from `/var/tmp`
* Removes empty directories older than **7 days** from `/var/tmp`
* Removes packages that are no longer required
* Cleans the APT package cache
* Displays journal, temporary-directory, APT-cache, and filesystem usage

Run directly from this directory:

```bash
./cleanup.sh
```

If installed system-wide:

```bash
cleanup
```

## Safety Boundaries

These utilities are intended for operating-system maintenance.

They do **not** intentionally target or remove:

```text
/opt/platform/releases
/opt/platform/shared
/opt/platform/logs
/opt/backups
```

Application release pruning, deployment cleanup, backup retention, and application-specific cleanup are outside the scope of these scripts.

`cleanup.sh` limits temporary-file cleanup to `/tmp` and `/var/tmp` and uses filesystem-boundary protection when traversing those paths.

Before modifying cleanup paths or retention periods, review the affected files and expected operational impact.

## Required Access

The scripts require non-interactive administrative access through `sudo`.

Verify access before running them:

```bash
sudo -n true
```

A successful command exits with status `0` and produces no output.

Do not grant broader administrative privileges solely to make these utilities run.

## Installation

The scripts can be executed directly from the repository:

```bash
chmod +x refresh.sh cleanup.sh
```

```bash
./refresh.sh
```

or:

```bash
./cleanup.sh
```

For convenient system-wide access, install them into `/usr/local/bin/`:

```bash
sudo install -m 0755 refresh.sh /usr/local/bin/refresh
sudo install -m 0755 cleanup.sh /usr/local/bin/cleanup
```

They can then be run as:

```bash
refresh
```

or:

```bash
cleanup
```

The repository remains the source of truth. Review updated scripts before replacing installed copies.

## Failure Behavior

Both scripts use:

```bash
set -euo pipefail
```

A failed command causes the script to stop rather than silently continuing with potentially incomplete maintenance.

A successful execution returns exit status `0`.

Check the exit status when needed:

```bash
echo $?
```

A failed operation is not automatically rolled back. Review the command output before treating the maintenance operation as complete.

## Maintenance Separation

The utilities intentionally have separate responsibilities:

```text
refresh.sh
    └── Package maintenance

cleanup.sh
    ├── Journal cleanup
    ├── Temporary-file cleanup
    └── APT cleanup
```

Run them independently according to the maintenance task required.

They do not replace the deployment engine:

```text
/opt/platform/deploy.sh
```

Application deployment, rollback, release pruning, health validation, and deployment logging remain part of the deployment architecture.

## Customization

The scripts are reference utilities and may need adjustment for the target environment.

Before changing them, consider:

* Operating-system and distribution differences
* Retention requirements
* Application behavior
* Logging requirements
* Package-management policies
* Compliance requirements
* Filesystem layout

Test customized versions before using them on production systems.

## Security Reporting

For bugs and general issues, use the repository's issue-reporting channels.

For security vulnerabilities, follow the repository's [Security Policy](../../.github/SECURITY.md).

Do not publicly disclose:

* Passwords
* Private keys
* API tokens
* Access tokens
* Cloud credentials
* Production secrets
* Sensitive vulnerability details

## Related Documentation

| Document                                     | Purpose                                       |
| -------------------------------------------- | --------------------------------------------- |
| [Root README](../../README.md)               | Repository architecture and overall usage     |
| [Bootstrap README](../README.md)             | Bootstrap architecture and boundaries         |
| [Setup README](../setup/README.md)           | Initial server provisioning                   |
| [Terms](../../TERMS.md)                      | Repository-wide terms                         |
| [Policy](../../POLICY.md)                    | Security, privacy, and responsible-use policy |
| [Conditions](../../CONDITIONS.md)            | Operational conditions and responsibilities   |
| [License](../../LICENSE)                     | MIT License                                   |
| [Security Policy](../../.github/SECURITY.md) | Security vulnerability reporting              |
