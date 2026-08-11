#!/usr/bin/env bash

# =============================================================================
# cleanup.sh
#
# Purpose:
# Perform safe manual cleanup of temporary files, system journals, and
# unnecessary APT data.
#
# This script:
#
# - Removes journal entries older than 30 days
# - Removes files older than 7 days from /tmp
# - Removes empty directories older than 7 days from /tmp
# - Removes files older than 7 days from /var/tmp
# - Removes empty directories older than 7 days from /var/tmp
# - Removes packages that are no longer required
# - Cleans the local APT package cache
#
# IMPORTANT:
#
# This is a manual maintenance operation.
#
#
# Run as the administrator:
#
#   cleanup
#
# =============================================================================

set -euo pipefail

JOURNAL_RETENTION="30d"
TEMP_FILE_AGE_DAYS="7"

echo "====================================="
echo " System Cleanup"
echo "====================================="

# =============================================================================
# 1. Verify Administrative Access
# =============================================================================

echo
echo "==> Checking administrator privileges..."

if ! sudo -n true; then
    echo "ERROR: Current user does not have working passwordless sudo."
    echo "Run this script as the administrator."
    exit 1
fi

echo "✓ Administrator privileges verified."

# =============================================================================
# 2. Clean systemd Journal
# =============================================================================

echo
echo "==> Cleaning systemd journal..."

sudo journalctl --vacuum-time="$JOURNAL_RETENTION"

echo "✓ Journal entries older than $JOURNAL_RETENTION processed."

# =============================================================================
# 3. Clean /tmp
# =============================================================================

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

# =============================================================================
# 4. Clean /var/tmp
# =============================================================================

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

# =============================================================================
# 5. Remove Unnecessary Packages
# =============================================================================

echo
echo "==> Removing unnecessary packages..."

sudo DEBIAN_FRONTEND=noninteractive \
    apt-get autoremove -y

echo "✓ Unnecessary packages removed."

# =============================================================================
# 6. Clean APT Cache
# =============================================================================

echo
echo "==> Cleaning package cache..."

sudo apt-get clean

echo "✓ Package cache cleaned."

# =============================================================================
# 7. Verification
# =============================================================================

echo
echo "====================================="
echo " Verification"
echo "====================================="

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
echo "====================================="
echo " Disk Usage"
echo "====================================="

echo
df -h /

echo
echo "====================================="
echo " Cleanup completed"
echo "====================================="
