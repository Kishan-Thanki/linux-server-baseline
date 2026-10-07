# Linux Server Baseline

An Ubuntu-focused Ansible baseline for repeatable server provisioning, security hardening, operations, and optional application deployment.

The repository is intentionally modular. The core baseline is a practical starting point for small Ubuntu servers, while deployment and application services are kept in separate playbooks. Review every default for the workload and network environment before applying it to important infrastructure.

## Scope

The repository currently targets Ubuntu servers with Python 3, an initial SSH account with `sudo` privileges, and a Python 3.11 Ansible control machine. It is cloud-provider agnostic.

The core baseline provides:

- Package updates and reboot handling.
- Permanent `sysadmin` and `automation` accounts.
- Public-key SSH hardening and explicit `AllowUsers` policy.
- `firewalld` configuration and basic SSH abuse mitigation with Fail2ban.
- Chrony time synchronization and persistent journald logging.
- Auditd rules for identity, privilege, SSH, system, and audit files.
- Kernel and network hardening through sysctl.
- Automatic security updates without automatic reboot.
- A persistent swap file, Sysstat performance accounting, and a minimal webroot.
- AppArmor installation, enablement, and verification.

Optional layers provide a `deployer` user, proxy artifact deployment, and Caddy configuration management.

This is an educational and reusable baseline, not a complete compliance framework or a universal production hardening profile.

## Quick Start

Install the pinned Ansible collections from the repository root:

```bash
ansible-galaxy collection install \
  -r requirements.yml \
  -p .ansible/collections
```

Configure `inventory/inventory.ini`, `inventory/group_vars/servers.yml`, and the host variable files. Set the public-key file variables before running account playbooks. They must point to readable `.pub` files on the Ansible control machine; never provide a private key.

Inspect the inventory:

```bash
ansible-inventory -i inventory/inventory.ini --graph
ansible-inventory -i inventory/inventory.ini --host server-01
ansible servers -m ping
```

Review and apply the core baseline:

```bash
ansible-playbook \
  playbooks/baseline.yml \
  --check --diff

ansible-playbook playbooks/baseline.yml
```

The baseline is intended to be idempotent. Verify permanent SSH access before removing the initial bootstrap account.

## Core Baseline

The primary entry point is `playbooks/baseline.yml`. It imports these ordered playbooks:

1. `01-system-admin.yml` - create `sysadmin` and install its key.
2. `02-automation-user.yml` - create `automation` and install its key.
3. `03-swap.yml` - create and persist `/swapfile` when required.
4. `04-system-update.yml` - update packages and reboot when required.
5. `05-ssh-hardening.yml` - apply key-based SSH policy.
6. `06-firewall.yml` - configure the `firewalld` public zone.
7. `07-fail2ban.yml` - configure SSH abuse mitigation.
8. `08-auto-updates.yml` - enable unattended security updates.
9. `09-journald.yml` - configure persistent journal storage.
10. `10-sysctl.yml` - apply conservative kernel and network settings.
11. `11-auditd.yml` - install auditd and deploy custom rules.
12. `12-sysstat.yml` - enable local performance accounting.
13. `13-ntp.yml` - install and enable Chrony.
14. `14-apparmor.yml` - install, enable, and verify AppArmor.

Each numbered playbook can also be run independently when its prerequisites are satisfied.

### Current Defaults

- `PermitRootLogin no`, `PasswordAuthentication no`, `KbdInteractiveAuthentication no`.
- `PubkeyAuthentication yes`, `X11Forwarding no`, and `MaxAuthTries 3`.
- `firewalld` public-zone ports `22/tcp`, `80/tcp`, and `443/tcp`.
- Fail2ban `bantime=1h`, `findtime=10m`, and `maxretry=5`.
- Timezone `Etc/UTC`.
- Persistent journald storage with a 1 GiB system maximum, 500 MiB free-space reservation, 30-day retention, and compression.
- Custom audit rules at `/etc/audit/rules.d/99-custom.rules`.
- Sysctl policy at `/etc/sysctl.d/99-security.conf`.
- Automatic security updates with automatic reboot disabled.
- A 2 GiB `/swapfile` with mode `0600`, persisted in `/etc/fstab`.
- Sysstat retention of 28 days.

The firewall ports are convenience defaults for common web workloads. Reduce them through `firewall_allowed_ports` when a host does not need HTTP or HTTPS. Sysctl settings may require changes for VPNs, multihoming, forwarding, containers, custom routing, or other specialized networking.

## Repository Layout

```text
linux-server-baseline/
├── ansible.cfg
├── requirements.yml
├── requirements-dev.txt
├── inventory/{inventory.ini,group_vars/}
├── playbooks/*.yml
├── roles/
│   ├── apparmor, auditd, auto_updates, automation_user,
│   ├── fail2ban, firewall, journald, ntp,
│   ├── ssh_hardening, swap, sysctl, sysstat, system_admin,
│   └── system_update
├── validate.sh
├── SECURITY.md
└── DISCLAIMER.md
```

The repository's `ansible.cfg` uses `inventory/inventory.ini`, `./roles`, and `./.ansible/collections`, and enables YAML-formatted Ansible output.

## Dependencies

Pinned Ansible collections in `requirements.yml`:

```yaml
collections:
  - name: ansible.posix
    version: "2.2.2"
  - name: community.general
    version: "13.2.0"
```

Development requirements in `requirements-dev.txt`:

```text
ansible==12.3.0
ansible-lint==26.6.0
```

## Validation

Run the repository validation script from the root:

```bash
./validate.sh
```

The script runs `ansible-playbook --syntax-check` for every playbook, validates the inventory graph, and runs `ansible-lint --offline .`. Repository validation does not replace testing the resulting server. Use `--check --diff`, then verify SSH access, firewall state, services, logging, audit rules, AppArmor, and application health on a controlled Ubuntu host.

## Security and Secrets

Never commit private SSH keys, passwords, API tokens, cloud credentials, Vault passwords, or certificates containing private keys. Use Ansible Vault or another secure secret-injection mechanism for sensitive values.

Review `SECURITY.md` for vulnerability reporting guidance and `DISCLAIMER.md` for scope, limitations, and user responsibilities.

## Limitations

This project does not currently provide centralized SIEM or log aggregation, continuous vulnerability management, backup configuration or restore testing, comprehensive file-integrity monitoring, application-specific hardening, central asset inventory, incident-response automation, complete CIS or other compliance-framework implementation, provider-specific network security controls, or application-level observability.

The deployment tools provide proxy configuration primitives, not a complete CI/CD platform, container orchestrator, secret manager, backup system, or observability stack.

## Contributing

Keep changes focused and modular, preserve the Ubuntu-only scope unless it is intentionally expanded, prefer idempotent Ansible tasks, and document behavior or configuration changes. Run `./scripts/validate-ansible.sh` before submitting changes. Remove private credentials and other sensitive data from issue reports and logs.

## License

This project is licensed under the MIT License. See `LICENSE` for the complete terms.
