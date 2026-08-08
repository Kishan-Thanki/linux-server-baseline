#!/usr/bin/env bash

set -euo pipefail

echo "====================================="
echo " System Cleanup"
echo "====================================="

echo
echo "==> Cleaning systemd journal..."

sudo journalctl --vacuum-time=30d

echo "✓ Journal cleaned."

echo
echo "==> Cleaning /tmp..."

sudo find /tmp -type f -mtime +7 -delete
sudo find /tmp -type d -empty -mtime +7 -not -path /tmp -delete 2>/dev/null || true

echo "✓ /tmp cleaned."

echo
echo "==> Cleaning /var/tmp..."

sudo find /var/tmp -type f -mtime +7 -delete
sudo find /var/tmp -type d -empty -mtime +7 -not -path /var/tmp -delete 2>/dev/null || true

echo "✓ /var/tmp cleaned."

echo
echo "==> Removing unnecessary packages..."

sudo apt autoremove -y

echo "✓ Orphaned packages removed."

echo
echo "==> Cleaning package cache..."

sudo apt clean

echo "✓ Package cache cleaned."

echo
echo "====================================="
echo " Disk Usage"
echo "====================================="

echo
df -h /

echo
echo "====================================="
echo " Cleanup completed"
echo "====================================="
