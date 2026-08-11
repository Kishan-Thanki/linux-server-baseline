#!/usr/bin/env bash

# =============================================================================
# 03-firewall.sh
#
# Purpose:
#   Configure the server firewall and SSH brute-force protection.
#
# Firewall:
#   UFW
#
# Intrusion protection:
#   Fail2Ban
#
# Allowed inbound services:
#   22/tcp  - SSH
#   80/tcp  - HTTP
#   443/tcp - HTTPS
#
# Default policy:
#   Incoming  -> DENY
#   Outgoing  -> ALLOW
#
# IMPORTANT:
#   SSH access is explicitly allowed BEFORE UFW is enabled.
#
#
# Run as:
#   firewall
#
# Run as the administrator configured by 02-setup-admin.sh.
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SSH_PORT="22"
HTTP_PORT="80"
HTTPS_PORT="443"

FAIL2BAN_CONFIG="/etc/fail2ban/jail.local"
FAIL2BAN_START_TIMEOUT=30

HOSTNAME="$(hostname)"

# =============================================================================
# Header
# =============================================================================

echo "====================================="
echo " Firewall & Intrusion Protection"
echo "====================================="

# =============================================================================
# 1. Verify Administrative Access
# =============================================================================

echo
echo "==> Checking administrator privileges..."

if ! sudo -n true; then
    echo "ERROR: Current user does not have working passwordless sudo."
    echo "Run this script as the administrator configured by 02-setup-admin.sh."
    exit 1
fi

echo "✓ Administrative privileges verified."

# =============================================================================
# 2. Install UFW
# =============================================================================

echo
echo "==> Installing UFW..."

sudo apt install -y ufw

echo "✓ UFW installed."

# =============================================================================
# 3. Configure Default Firewall Policies
# =============================================================================

echo
echo "==> Configuring default firewall policies..."

sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "✓ Default firewall policies configured."

# =============================================================================
# 4. Allow Required Inbound Services
# =============================================================================

echo
echo "==> Configuring allowed inbound services..."

echo "Allowing SSH on port ${SSH_PORT}..."
sudo ufw allow "${SSH_PORT}/tcp" comment 'SSH'

echo "Allowing HTTP on port ${HTTP_PORT}..."
sudo ufw allow "${HTTP_PORT}/tcp" comment 'HTTP'

echo "Allowing HTTPS on port ${HTTPS_PORT}..."
sudo ufw allow "${HTTPS_PORT}/tcp" comment 'HTTPS'

echo "✓ Required inbound services allowed."

# =============================================================================
# 5. Verify SSH Rule Before Enabling Firewall
# =============================================================================

echo
echo "==> Verifying SSH firewall rule..."

if ! sudo ufw status | grep -Eq "^${SSH_PORT}/tcp[[:space:]]+ALLOW"; then
    echo "ERROR: SSH firewall rule was not configured correctly."
    echo "Firewall will NOT be enabled."
    exit 1
fi

echo "✓ SSH access is explicitly allowed."

# =============================================================================
# 6. Enable Firewall
# =============================================================================

echo
echo "==> Enabling firewall..."

sudo ufw --force enable

echo "✓ UFW enabled."

# =============================================================================
# 7. Verify Firewall
# =============================================================================

echo
echo "==> Verifying firewall..."

if ! sudo ufw status | grep -q "Status: active"; then
    echo "ERROR: UFW is not active."
    exit 1
fi

echo "✓ UFW is active."

# =============================================================================
# 8. Install Fail2Ban
# =============================================================================

echo
echo "==> Installing Fail2Ban..."

sudo apt install -y fail2ban

echo "✓ Fail2Ban installed."

# =============================================================================
# 9. Configure Fail2Ban
# =============================================================================

echo
echo "==> Configuring Fail2Ban..."

sudo tee "$FAIL2BAN_CONFIG" >/dev/null <<EOF
[DEFAULT]

allowipv6 = auto

backend = systemd

bantime  = 1h
findtime = 10m
maxretry = 5

banaction = ufw

destemail = root@localhost
sender = fail2ban@${HOSTNAME}

[sshd]
enabled = true
port = ssh
backend = systemd
bantime = -1
maxretry = 5
EOF

echo "✓ Fail2Ban configuration written."

# =============================================================================
# 10. Validate Fail2Ban Configuration
# =============================================================================

echo
echo "==> Validating Fail2Ban configuration..."

if ! sudo fail2ban-client -t; then
    echo "ERROR: Fail2Ban configuration validation failed."
    exit 1
fi

echo "✓ Fail2Ban configuration is valid."

# =============================================================================
# 11. Enable and Start Fail2Ban
# =============================================================================

echo
echo "==> Enabling Fail2Ban service..."

sudo systemctl enable fail2ban >/dev/null
sudo systemctl restart fail2ban

echo "✓ Fail2Ban service restart requested."

# =============================================================================
# 12. Verify Fail2Ban Service
# =============================================================================

echo
echo "==> Waiting for Fail2Ban service..."

if ! sudo systemctl is-active --quiet fail2ban; then
    echo "ERROR: Fail2Ban failed to become active."
    sudo systemctl --no-pager --full status fail2ban || true
    exit 1
fi

echo "✓ Fail2Ban service is active."

# =============================================================================
# 13. Wait for Fail2Ban Daemon
# =============================================================================

echo
echo "==> Waiting for Fail2Ban daemon..."

FAIL2BAN_READY=0

for ((attempt = 1; attempt <= FAIL2BAN_START_TIMEOUT; attempt++)); do
    if sudo fail2ban-client ping >/dev/null 2>&1; then
        FAIL2BAN_READY=1
        break
    fi
    sleep 1
done

if [[ "$FAIL2BAN_READY" -ne 1 ]]; then
    echo "ERROR: Fail2Ban daemon did not become ready within ${FAIL2BAN_START_TIMEOUT} seconds."

    echo
    echo "Fail2Ban service status:"
    sudo systemctl --no-pager --full status fail2ban || true

    echo
    echo "Recent Fail2Ban journal:"
    sudo journalctl -u fail2ban --no-pager -n 50 || true

    exit 1
fi

echo "✓ Fail2Ban daemon responded successfully."

# =============================================================================
# 14. Verify SSH Jail
# =============================================================================

echo
echo "==> Validating SSH protection..."

if ! sudo fail2ban-client status sshd >/dev/null 2>&1; then
    echo "ERROR: Fail2Ban SSH jail is not active."

    echo
    sudo fail2ban-client status || true

    exit 1
fi

echo "✓ SSH Fail2Ban jail is active."

# =============================================================================
# Verification
# =============================================================================

echo
echo "====================================="
echo " Verification"
echo "====================================="

echo
echo "Firewall status:"
sudo ufw status verbose

echo
echo "Firewall rules:"
sudo ufw status numbered

echo
echo "Fail2Ban service:"
sudo systemctl --no-pager --full status fail2ban | head -n 8

echo
echo "Configured Fail2Ban jails:"
sudo fail2ban-client status

echo
echo "SSH jail:"
sudo fail2ban-client status sshd

echo
echo "====================================="
echo " Firewall & intrusion protection"
echo " completed"
echo "====================================="

echo
echo "Inbound policy : DENY by default"
echo "SSH            : Allowed (${SSH_PORT}/tcp)"
echo "HTTP           : Allowed (${HTTP_PORT}/tcp)"
echo "HTTPS          : Allowed (${HTTPS_PORT}/tcp)"
echo "Outgoing       : ALLOW by default"
echo "Fail2Ban       : Active"
echo "SSH protection : Active"
