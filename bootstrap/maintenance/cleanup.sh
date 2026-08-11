#!/usr/bin/env bash

# cleanup.sh
#
# Purpose:
#   Perform safe manual cleanup of temporary files, system journals,
#   and unnecessary APT data.
#
# Operations:
#   - Remove journal entries older than 30 days
#   - Remove files older than 7 days from /tmp
#   - Remove empty directories older than 7 days from /tmp
#   - Remove files older than 7 days from /var/tmp
#   - Remove empty directories older than 7 days from /var/tmp
#   - Remove packages that are no longer required
#   - Clean the local APT package cache
#   - Display resulting disk usage
#
# Usage:
#   ./cleanup.sh
#
# Requirements:
#   - Bash
#   - sudo with non-interactive administrative access
#   - systemd
#   - APT-based Linux distribution

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

JOURNAL_RETENTION="30d"
TEMP_FILE_AGE_DAYS="7"

echo "==> Checking administrator privileges..."

if ! sudo -n true; then
    echo "ERROR: Current user does not have working passwordless sudo." >&2
    echo "Run this script as the administrator." >&2
    exit 1
fi

echo "✓ Administrator privileges verified."

echo
echo "==> Cleaning systemd journal..."
sudo journalctl --vacuum-time="$JOURNAL_RETENTION"
echo "✓ Journal entries older than $JOURNAL_RETENTION processed."

echo
echo "==> Cleaning /tmp..."

sudo find /tmp \
    -xdev \
    -type f \
    -mtime +"$TEMP_FILE_AGE_DAYS" \
    -delete

sudo find /tmp \
    -xdev \
    -depth \
    -type d \
    -empty \
    -mtime +"$TEMP_FILE_AGE_DAYS" \
    -not -path /tmp \
    -delete

echo "✓ Old /tmp files and empty directories cleaned."

echo
echo "==> Cleaning /var/tmp..."

sudo find /var/tmp \
    -xdev \
    -type f \
    -mtime +"$TEMP_FILE_AGE_DAYS" \
    -delete

sudo find /var/tmp \
    -xdev \
    -depth \
    -type d \
    -empty \
    -mtime +"$TEMP_FILE_AGE_DAYS" \
    -not -path /var/tmp \
    -delete

echo "✓ Old /var/tmp files and empty directories cleaned."

echo
echo "==> Removing unnecessary packages..."
sudo apt-get autoremove -y
echo "✓ Unnecessary packages removed."

echo
echo "==> Cleaning APT package cache..."
sudo apt-get clean
echo "✓ APT package cache cleaned."

echo
echo "==> Journal disk usage..."
sudo journalctl --disk-usage

echo
echo "==> Temporary directory usage..."
sudo du -sh /tmp /var/tmp

echo
echo "==> APT cache usage..."
sudo du -sh /var/cache/apt

echo
echo "==> Root filesystem usage..."
df -h /

echo
echo "✓ System cleanup completed successfully."