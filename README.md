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

Optional layers provide a `deployer` user, proxy artifact deployment, application release deployment, and Caddy configuration management.

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
  playbooks/01-baseline/baseline.yml \
  --check --diff

ansible-playbook playbooks/01-baseline/baseline.yml
```

The baseline is intended to be idempotent. Verify permanent SSH access before removing the initial bootstrap account.

## Inventory and SSH Access

The example inventory contains placeholders:

```ini
[servers]
server-01 ansible_host=YOUR_SERVER_HOSTNAME ansible_user=YOUR_INITIAL_USER
server-02 ansible_host=YOUR_SERVER_HOSTNAME ansible_user=YOUR_INITIAL_USER
```

The initial user must already exist and be able to use `sudo`. After provisioning, recurring Ansible access should normally use `automation`.

The source of truth for SSH access is `inventory/group_vars/servers.yml`:

```yaml
ssh_hardening_allow_users:
  - "{{ ansible_user }}"
  - sysadmin
  - automation
  - deployer
```

The role renders this list into `AllowUsers`. Update it deliberately whenever SSH access changes. The example policy includes `deployer`, although that account is provisioned separately.

The core account roles use control-machine file variables:

```yaml
system_admin_ssh_public_key_file: "/path/to/id_ed25519.pub"
automation_user_ssh_public_key_file: "/path/to/id_ed25519_automation.pub"
```

The deployment user uses:

```yaml
deployer_user_ssh_public_key_file: "/path/to/id_ed25519_deployer.pub"
```

Ansible reads these files on the control machine and installs them in the managed user's `authorized_keys`. The example host variable files intentionally leave these values empty until local paths are supplied.

## Core Baseline

The primary entry point is `playbooks/01-baseline/baseline.yml`. It imports these ordered playbooks:

1. `01-system-update.yml` - update packages and reboot when required.
2. `02-system-admin.yml` - create `sysadmin` and install its key.
3. `03-automation-user.yml` - create `automation` and install its key.
4. `04-ssh-hardening.yml` - apply key-based SSH policy.
5. `05-firewall.yml` - configure the `firewalld` public zone.
6. `06-fail2ban.yml` - configure SSH abuse mitigation.
7. `07-ntp.yml` - install and enable Chrony.
8. `08-journald.yml` - configure persistent journal storage.
9. `09-auditd.yml` - install auditd and deploy custom rules.
10. `10-sysctl.yml` - apply conservative kernel and network settings.
11. `11-auto-updates.yml` - enable unattended security updates.
12. `12-swap.yml` - create and persist `/swapfile` when required.
13. `13-sysstat.yml` - enable local performance accounting.
14. `14-webroot.yml` - create the initial `/var/www/index.html`.
15. `15-apparmor.yml` - install, enable, and verify AppArmor.

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

### Bootstrap User Removal

Removing the initial Ubuntu account is a separate manual step:

```bash
ansible-playbook playbooks/01-baseline/99-remove-default-user.yml
```

The cleanup role targets `ubuntu` and preserves `sysadmin`, `automation`, and `deployer`. Run it only after testing permanent access with `ansible server-01 -m ping` and `ansible server-02 -m ping`. It is deliberately not imported by the core baseline.

## Deployment Layer

Deployment is separate from the core baseline. The aggregate entry point is:

```bash
ansible-playbook playbooks/03-deploy/baseline.yml
```

It imports:

- `01-deployer-user.yml` - provision the non-root `deployer` account and SSH access.
- `02-deployproxy.yml` - install `/usr/local/bin/deployproxy` and dependencies.
- `03-release-engine.yml` - provision `/opt/apps`, install `/usr/local/bin/deploy`, and configure release-engine dependencies and permissions.

### Release Engine

The release engine stores each application under `/opt/apps/<app_name>/`:

```text
/opt/apps/<app_name>/
├── current -> releases/<release_id>/
├── releases/
├── staging/
├── shared/{.env,data/,env.d/,logs/,runtime/}
├── systemd/
└── deploy.json
```

It supports raw HTTP(S) archives and OCI/Docker image references, atomic release switching, post-deploy hooks, service restart or reload actions, health checks, release history, retention, rollback, and status inspection. Health checks can target HTTP, HTTPS, TCP, or an executable command.

The installed command is `/usr/local/bin/deploy`:

```bash
deploy deploy \
  --name my-app \
  --type raw \
  --artifact "https://example.com/releases/app-v1.0.tar.gz" \
  --health "http://127.0.0.1:8080/health" \
  --keep-releases 5

deploy deploy \
  --name web-frontend \
  --type image \
  --artifact "ghcr.io/org/frontend:v1.2.0" \
  --health "http://127.0.0.1:3000/"

deploy rollback --name my-app
deploy status --name my-app
deploy releases --name my-app
```

Additional options include `--auth-header`, `--auth-user`, `--registry-auth`, `--post-deploy`, `--restart-service`, `--health-service`, repeatable `--health`, `--keep-releases`, and `--force`. Run `deploy --help` on a managed host for the installed interface.

The role default is `release_engine_default_keep_releases: 3`. The current generated CLI initializes its command-line fallback to one retained old release, so set `--keep-releases` explicitly when retention matters.

### Proxy Artifact Deployment

The installed command `/usr/local/bin/deployproxy` deploys a raw proxy configuration artifact after optional validation:

```bash
deployproxy \
  --name webapp \
  --type raw \
  --artifact "https://example.com/releases/proxy.tar.gz" \
  --proxy-ext caddyfile \
  --validator-check "command -v caddy" \
  --validator-command "caddy validate --config %s --adapter caddyfile"
```

The validator command uses `%s` as the downloaded temporary file. Nginx-style validation is also supported with `--proxy-ext conf`, an appropriate presence check, and a command such as `nginx -t -c %s`.

## Caddy Service

The optional Caddy service is managed independently:

```bash
ansible-playbook playbooks/02-services/caddy.yml
```

The role installs Caddy and `inotify-tools`, and manages `/etc/caddy/Caddyfile` and `/etc/caddy/Caddyfile.d/`. It enables the `caddy`, `caddy-reload`, and `caddy-watch` systemd services. Drop-in changes are watched, validated, and reloaded with a five-second debounce by default.

## Repository Layout

```text
linux-server-baseline/
├── ansible.cfg
├── requirements.yml
├── requirements-dev.txt
├── inventory/{inventory.ini,group_vars/,host_vars/}
├── playbooks/{01-baseline/,02-services/,03-deploy/}
├── roles/{apparmor,auditd,auto_updates,automation_user,caddy,
│         deployer_user,deployproxy,fail2ban,firewall,journald,ntp,
│         release_engine,remove_default_user,ssh_hardening,swap,sysctl,
│         sysstat,system_admin,system_update,webroot}/
├── scripts/validate-ansible.sh
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
./scripts/validate-ansible.sh
```

The script runs `ansible-playbook --syntax-check` for every playbook, validates the inventory graph, and runs `ansible-lint --offline .`. Repository validation does not replace testing the resulting server. Use `--check --diff`, then verify SSH access, firewall state, services, logging, audit rules, AppArmor, and application health on a controlled Ubuntu host.

## Security and Secrets

Never commit private SSH keys, passwords, API tokens, cloud credentials, Vault passwords, or certificates containing private keys. Use Ansible Vault or another secure secret-injection mechanism for sensitive values.

Review `SECURITY.md` for vulnerability reporting guidance and `DISCLAIMER.md` for scope, limitations, and user responsibilities.

## Limitations

This project does not currently provide centralized SIEM or log aggregation, continuous vulnerability management, backup configuration or restore testing, comprehensive file-integrity monitoring, application-specific hardening, central asset inventory, incident-response automation, complete CIS or other compliance-framework implementation, provider-specific network security controls, or application-level observability.

The deployment and release-engine tools provide application delivery primitives, not a complete CI/CD platform, container orchestrator, secret manager, backup system, or observability stack.

## Contributing

Keep changes focused and modular, preserve the Ubuntu-only scope unless it is intentionally expanded, prefer idempotent Ansible tasks, and document behavior or configuration changes. Run `./scripts/validate-ansible.sh` before submitting changes. Remove private credentials and other sensitive data from issue reports and logs.

## License

This project is licensed under the MIT License. See `LICENSE` for the complete terms.
