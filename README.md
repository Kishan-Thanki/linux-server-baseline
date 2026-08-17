# Server Ops

Ansible-based Linux server provisioning and hardening.

This repository is designed as a reusable starting point for setting up Linux servers with a consistent baseline for administration, SSH security, firewalling, logging, auditing, system hardening, automatic updates, and basic operational tooling.

The project is intentionally modular so individual components can be applied independently, while `baseline.yml` provides the main entry point for a complete server setup.

## Repository Structure

```text
server-ops/
└── ansible/
    ├── README.md
    ├── ansible.cfg
    ├── requirements.yml
    ├── inventory/
    │   └── inventory.ini
    ├── playbooks/
    │   ├── baseline.yml
    │   └── NN-*.yml (Ordered modular playbooks)
    └── roles/
        └── [role_name]/ (Modular component roles)
```

## Requirements

### Target Server

* Linux (Debian/Ubuntu or Red Hat/Rocky Linux family)
* Python 3
* SSH access with a user capable of performing initial setup and `sudo` privileges

### Control Machine

* Ansible installed
* SSH client configured with access to target servers


## Configure the Inventory

The repository includes an example inventory file at `ansible/inventory/inventory.ini`. Because this is a public repository, it contains placeholder values. Update it before running playbooks.

```ini
[servers]
server-01 ansible_host=YOUR_SERVER_HOSTNAME ansible_user=YOUR_ANSIBLE_USER
server-02 ansible_host=YOUR_SERVER_HOSTNAME ansible_user=YOUR_ANSIBLE_USER

[web]
server-01

[database]
server-02
```

### Verify the Inventory

Navigate into the `ansible/` directory and test connectivity:

```bash
cd ansible
ansible-inventory -i inventory/inventory.ini --graph
ansible servers -m ping
```

## Applying the Baseline

Always run a dry-run check before applying changes to production infrastructure:

```bash
cd ansible
ansible-playbook playbooks/baseline.yml --check
ansible-playbook playbooks/baseline.yml --diff
```

To apply the complete server baseline in the proper sequence:

```bash
ansible-playbook playbooks/baseline.yml
```

## Baseline Architecture & Execution Flow

The baseline executes an ordered sequence of numerical playbooks organized into logical operational phases:

* **Phase 1: System Update & Access Provisioning**
Updates system packages, checks for required reboots, and provisions secure administrative and automation accounts.
* **Phase 2: Security & Hardening**
Applies SSH hardening, firewall rules (`firewalld`), fail2ban intrusion prevention, time synchronization (`chrony`), persistent journal logging, auditd rules, and kernel sysctl hardening.
* **Phase 3: Operations & Maintenance**
Configures automated security patching, persistent swap space, and performance accounting (`sysstat`).

## Individual Execution

Each playbook can also be run independently for testing or focused maintenance:

```bash
ansible-playbook playbooks/04-ssh-hardening.yml
```

## Bootstrap User Lifecycle (`99-remove-default-user.yml`)

Cloud-provisioned servers typically come with a default provider account (e.g., `ubuntu` or `rocky`) required for initial SSH connection.

> **Important:** Never remove the bootstrap account until you have verified your new `sysadmin` and `automation` SSH keys work reliably.

### Recommended Lifecycle:

1. Provision a new server.
2. Run the main baseline (`baseline.yml`) to create your secure management users.
3. Open a separate terminal and verify you can SSH into the server using your `sysadmin` key.
4. Update your inventory file with the new user credentials.
5. Execute the clean-up playbook manually:
```bash
ansible-playbook playbooks/99-remove-default-user.yml
```

## Core Security Controls

* **Least Privilege:** Accounts are strictly partitioned with minimal required access rights.
* **Key-Based Authentication:** Password-based SSH logins and direct root access are completely disabled (`PermitRootLogin no`, `PasswordAuthentication no`).
* **Defense in Depth:** Combines SSH hardening, firewalling, fail2ban, auditd, sysctl kernel hardening, and persistent logs.
* **Drop-in Configuration:** Vendor-managed files remain untouched; all configurations utilize modular drop-in directories (`/etc/ssh/sshd_config.d/`, `/etc/sysctl.d/`, etc.).
* **Idempotency:** Playbooks ensure servers converge to their declared desired state safely across multiple runs.

## Security & Secrets Management

This repository is public and **must not** contain real production credentials, private SSH keys, or secrets. Utilize external tools like **Ansible Vault** or secure environment secret injection for sensitive variables.


## Current Limitations

This project focuses specifically on host-level Linux baseline configuration. It does **not** include:

* Centralized SIEM or log aggregation pipelines
* Automated backup and disaster recovery validation
* SELinux or AppArmor profile management
* Application-specific hardening or runtime orchestration
