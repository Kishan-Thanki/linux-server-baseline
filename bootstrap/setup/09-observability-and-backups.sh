#!/usr/bin/env bash

set -euo pipefail

echo "====================================="
echo " Operational Tooling"
echo "====================================="

# ─────────────────────────────────────
#  Monitoring
# ─────────────────────────────────────

echo
echo "==> Installing monitoring utilities..."

sudo apt install -y \
    btop \
    iotop \
    ncdu \
    vnstat \
    sysstat

echo "✓ Monitoring utilities installed."

echo
echo "==> Enabling monitoring services..."

sudo systemctl enable vnstat >/dev/null
sudo systemctl start vnstat

sudo systemctl enable sysstat >/dev/null
sudo systemctl start sysstat

echo "✓ Monitoring services enabled."

# ─────────────────────────────────────
#  Backup
# ─────────────────────────────────────

echo
echo "==> Installing backup utilities..."

sudo apt install -y rsync

echo "✓ Backup utilities installed."

echo
echo "==> Creating backup directories..."

sudo mkdir -p \
    /opt/backups/system \
    /opt/backups/database \
    /opt/backups/apps \
    /opt/backups/archive

sudo chown -R root:root /opt/backups

echo "✓ Backup directory structure created."

# ─────────────────────────────────────
#  Verification
# ─────────────────────────────────────

echo
echo "====================================="
echo " Verification"
echo "====================================="

echo
echo "vnStat:"
sudo systemctl --no-pager --full status vnstat | head -n 8

echo
echo "Sysstat:"
sudo systemctl --no-pager --full status sysstat | head -n 8

echo
echo "Backup directories:"
tree /opt/backups

echo
echo "====================================="
echo " Operational tooling completed"
echo "====================================="