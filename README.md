# Server Ops

Ansible-based Ubuntu server provisioning and hardening.

This repository provides a reusable starting point for establishing a consistent server baseline covering administration, SSH security, firewalling, intrusion prevention, logging, auditing, kernel hardening, automatic security updates, swap, and basic operational tooling.

The project is intentionally modular. Individual components can be applied independently, while `playbooks/01-setup/baseline.yml` provides the primary entry point for the complete server baseline.

The repository is designed to be **Ubuntu-only and cloud-provider agnostic**. It does not embed OCI-, AWS-, Azure-, GCP-, or other provider-specific implementation details.

## Repository Structure

```text
linux-server-baseline/
├── LICENSE
├── README.md
├── ansible.cfg
├── inventory/
│   ├── host_vars/
│   │   ├── server-01.yml
│   │   └── server-02.yml
│   └── inventory.ini
├── playbooks/
│   ├── 01-setup/
│   │   ├── 01-system-update.yml
│   │   ├── 02-system-admin.yml
│   │   ├── 03-automation-user.yml
│   │   ├── 04-ssh-hardening.yml
│   │   ├── 05-firewall.yml
│   │   ├── 06-fail2ban.yml
│   │   ├── 07-ntp.yml
│   │   ├── 08-journald.yml
│   │   ├── 09-auditd.yml
│   │   ├── 10-sysctl.yml
│   │   ├── 11-auto-updates.yml
│   │   ├── 12-swap.yml
│   │   ├── 13-sysstat.yml
│   │   ├── 99-remove-default-user.yml
│   │   └── baseline.yml
│   └── 02-deployment/
│       ├── 01-deploy-user.yml
│       ├── 02-deployment-layout.yml
│       └── 03-deployment-engine.yml
|
├── requirements.yml
└── roles/
    └── [role_name]/

```

## Requirements

### Target Server

* Ubuntu
* Python 3
* SSH access with an initial account capable of using `sudo`
* Network connectivity to the configured Ubuntu package repositories

The reusable roles in this repository currently target Ubuntu only.

### Control Machine

* Python 3
* Ansible
* Ansible Lint
* OpenSSH client
* Access to the target servers using the configured SSH key

## Ansible Dependencies

External Ansible collections are pinned in `requirements.yml`:

```yaml
---
collections:
  - name: ansible.posix
    version: "2.2.2"
  - name: community.general
    version: "13.2.0"
```

Install the pinned collections into the repository-local collection directory:

```bash
ansible-galaxy collection install -r requirements.yml -p collection
```

The repository's `ansible.cfg` configures Ansible to search that local collection path.

## Configure the Inventory

The repository includes an example inventory at `inventory/inventory.ini`.

Because this is a public repository, it contains placeholder values rather than production endpoints or credentials.

```ini
[servers]
server-01 ansible_host=YOUR_SERVER_HOSTNAME ansible_user=YOUR_INITIAL_USER
server-02 ansible_host=YOUR_SERVER_HOSTNAME ansible_user=YOUR_INITIAL_USER
```

The initial connection user must exist on a newly provisioned server and have sufficient privileges to perform the bootstrap.

After the permanent `automation` account has been established, recurring Ansible management should use:

```ini
ansible_user=automation
```

### Verify the Inventory

From the repository root:

```bash
ansible-inventory -i inventory/inventory.ini --graph
```

Test connectivity:

```bash
ansible servers -m ping
```

Inspect a specific host:

```bash
ansible-inventory -i inventory/inventory.ini --host server-01
```

## Applying the Baseline

Always review the proposed changes before applying the baseline to production infrastructure:

```bash
ansible-playbook playbooks/01-setup/baseline.yml --check --diff
```

Apply the complete baseline:

```bash
ansible-playbook playbooks/01-setup/baseline.yml
```

The baseline is designed to be idempotent. After a server has converged, a subsequent check should normally report no changes unless packages or other declared state have changed externally.

## Baseline Architecture

The baseline is organized into ordered setup playbooks:

### Phase 1: System Update and Access Provisioning

```text
01-system-update.yml
02-system-admin.yml
```

This phase:

* Updates Ubuntu packages.
* Reboots when the system requires it.
* Creates the permanent `sysadmin` account.
* Creates the permanent `automation` account.

### Phase 2: Security and Hardening

```text
04-ssh-hardening.yml
05-firewall.yml
06-fail2ban.yml
07-ntp.yml
08-journald.yml
09-auditd.yml
10-sysctl.yml
```

This phase establishes:

* SSH hardening.
* firewalld host protection.
* SSH protection with Fail2ban.
* Chrony time synchronization.
* Persistent journald logging.
* Linux audit rules.
* Kernel and network hardening.

### Phase 3: Operations and Maintenance

```text
11-auto-updates.yml
12-swap.yml
13-sysstat.yml
```

This phase configures:

* Automatic security updates.
* Persistent swap.
* Local system performance accounting.

### Bootstrap Finalization

```text
99-remove-default-user.yml
```

This step removes the Ubuntu bootstrap account when it is present.

It is executed after the permanent management identities have been provisioned and SSH has been hardened.

## Individual Execution

Every setup component can be applied independently.

For example:

```bash
ansible-playbook playbooks/01-setup/04-ssh-hardening.yml
```

Other setup components follow the same directory structure:

```text
playbooks/01-setup/
```

Deployment-specific configuration is kept separate:

```bash
ansible-playbook playbooks/02-deployment/01-deploy-user.yml
ansible-playbook playbooks/02-deployment/02-deployment-layout.yml
```

## Bootstrap User Lifecycle

A newly provisioned Ubuntu server normally starts with a provider/bootstrap account.

A typical lifecycle is:

```text
New Ubuntu server
        ↓
Initial bootstrap account
        ↓
Run baseline
        ↓
sysadmin + automation created
        ↓
SSH hardening applied
        ↓
bootstrap account removed when present
        ↓
recurring management uses automation
```

The default bootstrap username used by the cleanup role is:

```text
ubuntu
```

The cleanup role protects:

```text
sysadmin
automation
```

and refuses to remove a protected account.

### Important

Before removing a bootstrap account, verify that the permanent management account works.

At minimum:

```bash
ansible server-01 -m ping
ansible server-02 -m ping
```

using the intended permanent Ansible account.

The cleanup playbook can be run directly when required:

```bash
ansible-playbook playbooks/01-setup/99-remove-default-user.yml
```

## Core Security Controls

### Least Privilege

Administrative, automation, and deployment responsibilities use separate accounts.

The `deployer` account is intentionally non-privileged.

### Key-Based SSH Administration

The baseline disables password-based SSH authentication and direct root SSH access.

Current SSH hardening includes:

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
X11Forwarding no
MaxAuthTries 3
```

The configured SSH `AllowUsers` list includes the identities required by the environment, including:

```text
sysadmin
automation
deployer
```

### Firewall

The host firewall uses `firewalld`.

The current public-zone baseline allows:

```text
22/tcp
80/tcp
443/tcp
```

Unnecessary services such as:

```text
dhcpv6-client
cockpit
```

are disabled.

Legacy persistent iptables configuration is removed when present so that firewalld remains the host firewall authority.

### Fail2ban

Fail2ban protects SSH using the systemd journal and firewalld rich rules.

Current SSH policy:

```text
bantime  = 1h
findtime = 10m
maxretry = 5
```

### Time Synchronization

Chrony is installed, enabled, and running.

The default timezone is:

```text
Etc/UTC
```

NTP role: Configure the server timezone and ensure Ubuntu's Chrony service is installed, enabled, and running. Do not manage Chrony's upstream configuration or NTP sources; those remain distribution/environment controlled.

### Journald

Persistent systemd journal logging is configured with:

```text
Storage=persistent
SystemMaxUse=1G
SystemKeepFree=500M
MaxRetentionSec=30day
Compress=yes
```

### Auditd

Custom audit rules monitor changes to important identity, privilege, SSH, system, and audit configuration files.

Custom rules are stored under:

```text
/etc/audit/rules.d/99-custom.rules
```

The role uses Ubuntu's `augenrules` mechanism.

### Sysctl Hardening

Kernel and network hardening is managed through:

```text
/etc/sysctl.d/99-security.conf
```

The policy includes protections for:

* TCP SYN floods.
* Reverse-path filtering.
* ICMP redirects.
* Source routing.
* Martian packets.
* Broadcast ICMP.
* Bogus ICMP errors.

The role intentionally does not force IPv4 or IPv6 forwarding settings because those are workload-dependent.

### Automatic Security Updates

Ubuntu's `unattended-upgrades` is enabled for security updates.

Automatic reboot is disabled:

```text
Unattended-Upgrade::Automatic-Reboot "false";
```

Automatic unused-package cleanup is also disabled so that package cleanup remains a deliberate administrative operation.

### Swap

The default managed swap file is:

```text
/swapfile
```

with:

```text
2 GiB
```

The swap file is protected with mode `0600` and persisted through `/etc/fstab`.

### Sysstat

The `sysstat` package is enabled for local performance accounting with a target retention of:

```text
28 days
```

Useful commands include:

```bash
sar -u
sar -r
sar -d
sar -n DEV
```

## Deployment Configuration

Application deployment is intentionally separated from the reusable host baseline.

### Deployment User

```bash
ansible-playbook playbooks/02-deployment/01-deploy-user.yml
```

This provisions:

```text
deployer
```

The account:

* Has its own home directory.
* Uses the configured shell.
* Uses a dedicated SSH public key.
* Has its password locked.
* Does not receive `sudo`.
* Does not receive a sudoers rule.

### Deployment Layout

```bash
ansible-playbook playbooks/02-deployment/02-deployment-layout.yml
```

The deployment boundary is:

```text
/opt/app
```

owned by:

```text
deployer:deployer
```

The role intentionally owns only the deployment root and does not recursively manage application contents.

### Deployment Engine

The deployment engine is maintained separately from the generic baseline:

```text
playbooks/02-deployment/03-deployment-engine.yml
```

Application-specific deployment behavior belongs in this layer rather than in the host baseline.

## Configuration Management Principles

### Distribution-Owned Configuration

Where practical, Ubuntu's package-managed primary configuration files are preserved.

The project prefers supported drop-in locations such as:

```text
/etc/ssh/sshd_config.d/
/etc/systemd/journald.conf.d/
/etc/audit/rules.d/
/etc/sysctl.d/
```

### Cloud-Provider Neutrality

Reusable roles do not contain provider-specific implementation details.

Inventory and environment-specific variables should provide connection information and environment-specific values.

### Idempotency

Roles should converge toward the desired state without unnecessary repeated changes.

Recommended validation sequence:

```bash
ansible-lint roles
ansible-lint playbooks

ansible-playbook playbooks/01-setup/baseline.yml --syntax-check
ansible-playbook playbooks/01-setup/baseline.yml --check --diff

ansible-playbook playbooks/01-setup/baseline.yml

ansible-playbook playbooks/01-setup/baseline.yml --check --diff
```

which performs recursive playbook syntax checks, inventory validation, and Ansible Lint.

## CI Validation

GitHub Actions validates the repository on pushes and pull requests.

The CI workflow:

1. Installs Ansible and Ansible Lint.
2. Installs the pinned collections from `requirements.yml`.
3. Runs the repository validation script.

This keeps local and CI validation aligned.

## Security and Secrets

This repository is public.

Do not commit:

* Private SSH keys.
* Production credentials.
* Cloud credentials.
* Passwords.
* Vault passwords.
* API tokens.
* Certificates containing private keys.
* Provider-specific secrets.

Use secure secret injection or Ansible Vault for sensitive values.

The public repository intentionally contains placeholder inventory values.

## Current Limitations

This project focuses on host-level Ubuntu server configuration.

It does not currently provide:

* Centralized SIEM or log aggregation.
* Continuous vulnerability management.
* Backup configuration and restore testing.
* Comprehensive file-integrity monitoring.
* Application-specific hardening.
* Central asset inventory.
* Incident-response automation.
* Complete CIS or other compliance-framework implementation.
* Provider-specific network-security configuration.
* Application-level observability.

These are separate capabilities that can be added as the infrastructure evolves.

## Validation Philosophy

The baseline is intended to be a **reproducible server foundation**, not a claim of complete security compliance.

The project favors:

* Explicit platform scope.
* Cloud-provider neutrality.
* Least privilege.
* Key-based administration.
* Configuration isolation.
* Idempotent automation.
* Separation of host baseline and application deployment.
* Source-controlled desired state.

Changes should be implemented in the appropriate role or playbook whenever practical so that another Ubuntu server can be provisioned consistently from the repository.
