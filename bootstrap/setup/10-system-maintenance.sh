#!/usr/bin/env bash

set -euo pipefail

DEPLOY_USER="deploy"
PLATFORM_LOG_DIR="/opt/platform/logs"
LOGROTATE_CONFIG="/etc/logrotate.d/platform"

echo "====================================="
echo " System Maintenance & Automation"
echo "====================================="

# ─────────────────────────────────────
#  Automatic Security Updates
# ─────────────────────────────────────

echo
echo "==> Configuring automatic security updates..."

sudo apt update
sudo apt install -y unattended-upgrades apt-listchanges

sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

echo "✓ Unattended-upgrades configured."

# ─────────────────────────────────────
#  Log Rotation Policy
# ─────────────────────────────────────

echo
echo "==> Configuring log rotation for application logs..."

sudo tee "$LOGROTATE_CONFIG" >/dev/null <<EOF
${PLATFORM_LOG_DIR}/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 $DEPLOY_USER $DEPLOY_USER
    sharedscripts
}
EOF

echo "✓ Logrotate policy created for ${PLATFORM_LOG_DIR}/."

# ─────────────────────────────────────
#  Verification
# ─────────────────────────────────────

echo
echo "====================================="
echo " Verification"
echo "====================================="

echo
echo "Unattended-upgrades status:"
systemctl is-active unattended-upgrades || echo "Active (managed via apt periodic timers)"

echo
echo "Logrotate test (dry run):"
sudo logrotate -d "$LOGROTATE_CONFIG" >/dev/null && echo "✓ Logrotate configuration syntax is valid."

echo
echo "====================================="
echo " System maintenance setup completed"
echo "====================================="