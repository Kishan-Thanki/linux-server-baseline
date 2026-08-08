
# GitHub Actions Server Access Setup

## Purpose

This document describes how to establish secure SSH-based communication between GitHub Actions and a Linux server.

The objective is to allow GitHub Actions to execute deployment commands on the server without enabling password authentication.

This is a **one-time server bootstrap task**.

# Overview

```text
    Developer
        │
        ▼
     Git Push
        │
        ▼
GitHub Actions Runner
        │
        ▼
       SSH
        │
        ▼
  OpenSSH Server
        │
        ▼
   deploy User
        │
        ▼
    deploy.sh
````

GitHub Actions behaves exactly like any other SSH client.

The server trusts GitHub because it possesses the matching private key for a trusted public key installed on the server.

**Do not reuse personal SSH keys.**

Each automation system should have its own dedicated deployment key.

# Configure GitHub Secrets

Open:

```text
     Repository
         ↓
      Settings
         ↓
Secrets and Variables
         ↓
      Actions
```

Create the following secret to match your deployment workflow:

```text
SSH_PRIVATE_KEY
```

Paste the **private key**.

Example:

```text
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

Never store private keys in the repository.

Never commit deployment keys.

# Configure Repository Variables / Host Settings

To connect to your target environment securely, ensure your workflow references:

```text
SSH_HOST
```

Example:

```text
SSH_HOST=xxx.xxx.xxx.xxx
```

# Deployment Execution

Once authenticated, GitHub Actions uploads the release asset and executes the deployment engine using explicit local file and cryptographic integrity flags.

Example:

```bash
/opt/platform/deploy.sh \
  --service SERVICE_NAME \
  --version VERSION_TAG \
  --artifact /home/deploy/artifact.tar.gz \
  --sha256 CHECKSUM_HASH \
  --systemd SERVICE_NAME.service \
  --health HEALTH_ENDPOINT_URL
```

GitHub Actions does **not** perform deployment logic.

It simply uploads the asset, passes verification parameters, and invokes the server-side deployment engine.

# Security Recommendations

Use a dedicated deployment key.

Never:

* reuse personal keys
* reuse administrator keys
* share deployment keys across unrelated systems

Rotate deployment keys periodically.

Protect GitHub repository secrets.

# Common Problems

## Permission denied (publickey)

Possible causes:

* Incorrect public key
* Incorrect private key
* Wrong deployment user
* Incorrect file permissions

## Host key verification failed

Possible causes:

* Unknown server host key
* Host key changed
* Incorrect `known_hosts` configuration

## GitHub cannot connect

Verify:

* Server reachable
* SSH port open
* Firewall rules
* Security group / NSG rules
* Correct hostname or IP

# Summary

GitHub Actions communicates with the server exactly like any standard SSH client.

The deployment process relies on:

1. A dedicated deployment user.
2. A dedicated SSH key pair.
3. Public key installed on the server.
4. Private key stored securely in GitHub Secrets.
5. GitHub Actions uploading the asset and invoking the deployment engine over SSH with checksum validation.

This configuration establishes the secure trust relationship required for automated deployments.