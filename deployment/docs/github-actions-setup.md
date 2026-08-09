# GitHub Actions Server Access Setup

## Purpose

This document describes the one-time setup required to establish secure SSH-based communication between GitHub Actions and a Linux deployment server.

The objective is to allow GitHub Actions to:

1. Authenticate to the deployment server.
2. Upload a pre-built release artifact.
3. Pass the release version and checksum to the standardized server deployment engine.
4. Invoke `/opt/platform/deploy.sh`.

GitHub Actions does **not** contain the server-side deployment logic.

The actual deployment is performed by the platform-owned:

```text
/opt/platform/deploy.sh
```

This is a **one-time server/bootstrap configuration** for the consuming application repository.

> **Important:** SSH credentials, deployment-server details, deployment-user information, and server-side deployment configuration must be provided by the DevOps/platform team. Application teams should not create or modify these independently unless explicitly instructed to do so.

# Architecture

```text
        Developer
            │
            ▼
      Git Push / PR
            │
            ▼
          GitHub
            │
            ▼
     Artifact Release
            │
            ▼
      GitHub Actions
            │
            │ SSH
            ▼
  Production Linux Server
            │
            ▼
       deploy user
            │
            ▼
 /opt/platform/deploy.sh
            │
            ├── Verify checksum
            ├── Acquire deployment lock
            ├── Extract release
            ├── Activate release
            ├── Restart systemd
            ├── Health check
            ├── Rollback on failure
            ├── Prune old releases
            └── Log deployment
```

GitHub Actions behaves like a normal SSH client.

The server trusts the GitHub Actions deployment identity because the corresponding public key is installed for the dedicated deployment user.

**Do not reuse personal SSH keys.**

Each automation system should use a dedicated deployment key.

The deployment key, deployment user, and target server information must be provided by the **DevOps/platform team**.

# 1. Configure GitHub Actions Secrets

Open:

```text
     Repository
         ↓
      Settings
         ↓
Secrets and variables
         ↓
      Actions
```

Create the following repository secrets.

## `SSH_PRIVATE_KEY`

Store the **private SSH key generated specifically for GitHub Actions**.

This key should be provided by the **DevOps/platform team**.

Usually, this will be a dedicated non-sudo deployment user and its corresponding SSH private key.

Example:

```text
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

The private key must correspond to the public key authorized for the deployment user on the production server.

Never commit this key to the repository.

Never place it in a workflow file.

Never put it into application `.env` files.

Never generate or replace the production deployment key without coordinating with the DevOps/platform team.

## `SSH_HOST`

Store the hostname or IP address of the target deployment server.

This value should be provided by the **DevOps/platform team**.

Example:

```text
xxx.xxx.xxx.xxx
```

or:

```text
production.example.com
```

The workflow consumes it as:

```yaml
${{ secrets.SSH_HOST }}
```

Therefore, `SSH_HOST` should be configured as a **GitHub Actions secret** for this boilerplate unless the platform team explicitly standardizes it as a repository variable.

# 2. Application Repository Configuration

The shared CD workflow contains placeholders for application-specific configuration.

Each consuming repository must update these values according to the application's production deployment configuration.

Example:

```yaml
env:
  SERVICE_NAME: "api"
  SYSTEMD_SERVICE: "api.service"
  HEALTH_URL: "http://localhost:8080/health"

  ARTIFACT_NAME: "api-artifact.tar.gz"
  CHECKSUM_NAME: "api-artifact.tar.gz.sha256"
```

These values are repository-specific.

The application team is responsible for configuring these values correctly.

## `SERVICE_NAME`

Must exactly match the service identifier expected by:

```text
/opt/platform/deploy.sh
```

Example:

```yaml
SERVICE_NAME: "api"
```

The service name must be compatible with the naming rules enforced by the server-side deployment engine.

## `SYSTEMD_SERVICE`

Must exactly match the systemd service installed on the production server.

Example:

```yaml
SYSTEMD_SERVICE: "api.service"
```

The systemd service itself must already exist on the production server.

## `HEALTH_URL`

Must point to the service health endpoint available from the deployment server.

Example:

```yaml
HEALTH_URL: "http://localhost:8080/health"
```

The platform deployment engine uses this endpoint after restarting the service and during rollback validation.

The endpoint should return HTTP `200` when the service is healthy.

## `ARTIFACT_NAME`

Must exactly match the artifact published by the application's artifact workflow.

Example:

```yaml
ARTIFACT_NAME: "api-artifact.tar.gz"
```

## `CHECKSUM_NAME`

Must exactly match the checksum file published alongside the artifact.

Example:

```yaml
CHECKSUM_NAME: "api-artifact.tar.gz.sha256"
```

Both files must exist in the GitHub Release.

# 3. Release and Tag Requirements

Production deployment is release/tag driven.

A normal pull request does **not** deploy to production.

A normal merge to `main` does **not** deploy to production.

The application must first produce a production release containing:

```text
application-artifact.tar.gz
application-artifact.tar.gz.sha256
```

The release must use the application's service-specific production tag.

Examples:

```text
api-v1.0.0
```

```text
gRPC-v1.0.0
```

The consuming repository should enforce its exact tag format.

For example, an API repository should not allow:

```text
gRPC-v1.0.0
```

to trigger an API deployment.

Likewise, an analysis repository should not accept:

```text
api-v1.0.0
```

as its production deployment tag.

The generic boilerplate provides basic non-production guardrails, but **service-specific tag validation belongs to the consuming repository**.

# 4. Artifact Requirements

The deployment workflow does **not** build application code.

Application code must already have been built by the application's artifact workflow.

The GitHub Release must contain:

```text
<artifact>
<artifact>.sha256
```

For example:

```text
api-artifact.tar.gz
api-artifact.tar.gz.sha256
```

A missing artifact causes deployment to fail.

A missing checksum causes deployment to fail.

An invalid checksum causes deployment to fail.

A checksum mismatch causes deployment to fail.

The deployment workflow consumes the exact release assets and does not rebuild or modify the application artifact.

# 5. Checksum Verification

Checksum verification occurs in two places.

## GitHub Actions Runner

The workflow performs:

```bash
sha256sum -c artifact.tar.gz.sha256
```

before uploading the artifact to the server.

This ensures the downloaded artifact matches the checksum published with the GitHub Release.

## Production Server

The workflow passes the expected checksum to:

```text
/opt/platform/deploy.sh
```

using:

```bash
--sha256 CHECKSUM_HASH
```

The server-side deployment engine independently calculates and validates the SHA256 checksum.

This provides a second verification boundary.

# 6. Deployment Execution

Once the artifact has been verified, GitHub Actions uploads it to:

```text
/home/deploy/artifact.tar.gz
```

on the production server.

It then invokes:

```bash
/opt/platform/deploy.sh \
  --service SERVICE_NAME \
  --version VERSION_TAG \
  --artifact /home/deploy/artifact.tar.gz \
  --sha256 CHECKSUM_HASH \
  --systemd SERVICE_NAME.service \
  --health HEALTH_ENDPOINT_URL
```

The GitHub Actions workflow is responsible for:

* obtaining the exact release artifact
* validating the checksum
* authenticating through SSH
* uploading the artifact
* invoking the deployment engine
* cleaning up the runner/staging artifact

The platform deployment engine is responsible for the actual deployment behavior.

# 7. Server-Side Deployment Responsibilities

The application repository must **not** copy `deploy.sh` into its own repository.

The standardized server deployment engine is:

```text
/opt/platform/deploy.sh
```

The platform deployment engine is responsible for:

```text
Release management
Deployment locking
Checksum verification
Artifact extraction
Release activation
Systemd restart
Health validation
Rollback
Release pruning
Deployment logging
```

Application repositories consume this deployment engine.

They should not independently modify or replace it.

If the deployment mechanism itself needs to change, the change should be made through the **DevOps/platform team and the standardized deployment process**.

# 8. SSH Host Verification

The workflow establishes SSH host trust before connecting to the deployment server.

The current boilerplate uses:

```bash
ssh-keyscan
```

to populate the runner's `known_hosts`.

For higher-security production environments, the platform team may provide a managed/pinned `known_hosts` configuration instead.

Do not disable SSH host verification with options such as:

```text
StrictHostKeyChecking=no
```

or:

```text
UserKnownHostsFile=/dev/null
```

Any change to the production SSH trust model should be coordinated with the DevOps/platform team.

# 9. Security Requirements

Use a dedicated deployment identity.

The deployment identity should be provided and managed by the **DevOps/platform team**.

Never:

* reuse personal SSH keys
* reuse administrator keys
* commit private keys
* hard-code private keys
* hard-code passwords
* hard-code production credentials
* disable SSH host verification
* give unrelated repositories unnecessary deployment credentials
* modify the server deployment user without DevOps approval

Protect GitHub Actions secrets.

Always use the credentials and server access details provided by the **DevOps/platform team**.

The deployment user should have only the permissions required for the standardized deployment process.

# 10. Common Problems

## `Permission denied (publickey)`

Possible causes:

* incorrect private key in `SSH_PRIVATE_KEY`
* incorrect public key on the server
* wrong deployment user
* incorrect SSH permissions
* SSH key not authorized for the deployment user
* server-side SSH configuration problem

Verify that:

```text
     GitHub private key
             │
             ▼
          matches
             │
             ▼
server authorized public key
```

If the key was provided by DevOps, contact the DevOps/platform team rather than generating or replacing the production key independently.

## `Host key verification failed`

Possible causes:

* server host key changed
* incorrect `known_hosts`
* incorrect server hostname
* stale host-key configuration

Verify the server identity and the configured SSH host.

If a production server's host key has changed unexpectedly, confirm the change with the DevOps/platform team before updating trust configuration.

## `SSH_HOST secret is not configured`

Verify that the consuming repository has:

```text
SSH_HOST
```

configured under:

```text
Settings
→ Secrets and variables
→ Actions
```

The value should be provided by the DevOps/platform team.

## Artifact not found

Verify that the GitHub Release contains the exact configured:

```text
ARTIFACT_NAME
```

For example:

```text
api-artifact.tar.gz
```

Also verify that the artifact name configured in the deployment workflow matches the artifact produced by the application's artifact workflow.

## Checksum file not found

Verify that the GitHub Release contains the exact configured:

```text
CHECKSUM_NAME
```

For example:

```text
api-artifact.tar.gz.sha256
```

The deployment workflow intentionally fails when the checksum is missing.

## SHA256 checksum mismatch

Possible causes:

* artifact was replaced after checksum generation
* wrong checksum file was published
* artifact was corrupted
* artifact and checksum belong to different releases

The deployment must not continue until the artifact and checksum match.

## Deployment fails during systemd restart

Check the corresponding systemd service on the production server.

Example:

```bash
sudo systemctl status api.service
```

Then inspect:

```bash
sudo journalctl -u api.service
```

The exact service name depends on the consuming repository's:

```text
SYSTEMD_SERVICE
```

configuration.

If the deployment user does not have permission to inspect or restart the service, contact the DevOps/platform team.

## Health check fails

Verify:

```text
HEALTH_URL
```

is:

* correct
* reachable from the production server
* available after service startup
* returning HTTP `200`

The deployment engine may automatically attempt rollback when post-deployment validation fails.

# 11. Consuming Repository Checklist

Before enabling this workflow in an application repository, verify:

```text
[ ] SERVICE_NAME configured
[ ] SYSTEMD_SERVICE configured
[ ] HEALTH_URL configured
[ ] ARTIFACT_NAME configured
[ ] CHECKSUM_NAME configured
[ ] Exact service-specific production tag validation configured
[ ] SSH_PRIVATE_KEY GitHub Secret configured
[ ] SSH_HOST GitHub Secret configured
[ ] SSH credentials provided/approved by DevOps
[ ] Production artifact workflow publishes the artifact
[ ] Production artifact workflow publishes the checksum
[ ] GitHub Release contains both files
[ ] Production server has the dedicated deployment user
[ ] Deployment public key is installed on the server
[ ] /opt/platform/deploy.sh exists on the server
[ ] Systemd service exists
[ ] Health endpoint works
```

# 12. Ownership and Responsibilities

The standardized deployment architecture separates application responsibilities from platform responsibilities.

## Application Repository Owns

```text
Application code
CI
Production build
Artifact creation
Checksum creation
Release/tag
Application-specific deployment configuration
Service-specific tag validation
```

## DevOps/Platform Owns

```text
SSH deployment infrastructure
Deployment user
Deployment SSH key
Server permissions
Production server access
/opt/platform/deploy.sh
Release activation
Systemd restart configuration
Health validation infrastructure
Rollback mechanism
Release pruning
Deployment logging
```

## GitHub Actions Acts as the Bridge

```text
       GitHub Release
             │
             ▼
   Download exact artifact
             │
             ▼
       Verify SHA256
             │     
             ▼
      SSH to production
             │
             ▼
       Upload artifact
             │
             ▼
Invoke /opt/platform/deploy.sh
             │
             ▼
   Server-side deployment
```

# Summary

The standardized deployment architecture separates application responsibilities from platform responsibilities.

The application repository should provide and maintain its **application-specific configuration**, including:

```text
SERVICE_NAME
SYSTEMD_SERVICE
HEALTH_URL
ARTIFACT_NAME
CHECKSUM_NAME
Production tag validation
```

The DevOps/platform team should provide and manage the **production deployment infrastructure**, including:

```text
SSH deployment user
SSH deployment key
SSH_HOST
Server permissions
/opt/platform/deploy.sh
Systemd configuration
Production deployment infrastructure
```

GitHub Actions acts only as the deployment bridge

The application repository should therefore **consume the standardized deployment mechanism rather than reimplement it**.

Any change to the core deployment mechanism, server-side deployment engine, deployment user, SSH trust model, or production deployment infrastructure should go through the **DevOps/platform team**.
