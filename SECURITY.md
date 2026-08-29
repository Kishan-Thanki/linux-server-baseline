# Security Policy

## Reporting a Security Issue

If you discover a security vulnerability in this project, please do not open a public GitHub issue with the vulnerability details.

Instead, report the issue privately through the repository's available GitHub security reporting mechanism.

When reporting a vulnerability, please include:

* A clear description of the issue.
* The affected playbook, role, task, or configuration.
* The steps required to reproduce the issue.
* The potential security impact.
* Any relevant Ansible output or configuration.
* A suggested mitigation, if known.

Please remove private keys, credentials, tokens, server addresses, and other sensitive information from any report.

## Scope

This project provides an Ubuntu-focused Ansible server baseline for security, administration, and operational configuration.

Security issues may include, but are not limited to:

* SSH hardening weaknesses.
* Firewall configuration problems.
* Privilege escalation caused by the project's Ansible code.
* Incorrect file ownership or permissions that expose sensitive information.
* Tasks that unintentionally weaken server security.
* Vulnerabilities introduced by the project's custom scripts, services, or configuration templates.

Third-party software installed or configured by this project may have vulnerabilities outside the control of this repository. Please report vulnerabilities in those upstream projects to their respective maintainers when appropriate.

## Supported Versions

The project is actively developed on the `main` branch.

Security fixes are generally applied to the current maintained version of the repository. Older commits or versions may not receive security fixes.

## Responsible Disclosure

Please allow reasonable time for the issue to be investigated and, where appropriate, fixed before publicly disclosing technical details.

Security reports will be reviewed as time and resources permit.

## Security Considerations

This project is intended as a practical, educational, and reusable server baseline.

Applying Ansible automation can modify authentication, firewall, networking, logging, package, and system configuration. Always review changes and test them in a disposable or controlled environment before applying them to production systems.

The project does not guarantee that a server configured with this baseline is secure, vulnerability-free, or compliant with any particular security standard.
