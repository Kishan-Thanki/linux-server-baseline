#!/usr/bin/env bash

# =============================================================================
# refresh.sh
#
# Purpose:
# Perform a manual system package refresh.
#
# This script:
#
# - Updates the APT package index
# - Upgrades installed packages
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
#   refresh
#
# =============================================================================

set -euo pipefail

echo "====================================="
echo " System Refresh"
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
# 2. Update Package Index
# =============================================================================

echo
echo "==> Updating package index..."

sudo DEBIAN_FRONTEND=noninteractive apt-get update

echo "✓ Package index updated."

# =============================================================================
# 3. Upgrade Installed Packages
# =============================================================================

echo
echo "==> Upgrading installed packages..."

sudo DEBIAN_FRONTEND=noninteractive \
    apt-get upgrade -y

echo "✓ Packages upgraded."

# =============================================================================
# 4. Remove Unnecessary Packages
# =============================================================================

echo
echo "==> Removing unnecessary packages..."

sudo DEBIAN_FRONTEND=noninteractive \
    apt-get autoremove -y

echo "✓ Unnecessary packages removed."

# =============================================================================
# 5. Clean Package Cache
# =============================================================================

echo
echo "==> Cleaning package cache..."

sudo apt-get clean

echo "✓ Package cache cleaned."

# =============================================================================
# 6. Verification
# =============================================================================

echo
echo "====================================="
echo " Verification"
echo "====================================="

echo
echo "==> Checking for remaining upgradable packages..."

UPGRADABLE_PACKAGES="$(
    apt list --upgradable 2>/dev/null |
    tail -n +2 |
    sed '/^[[:space:]]*$/d'
)"

if [[ -n "$UPGRADABLE_PACKAGES" ]]; then
    echo "WARNING: Some packages remain upgradable:"
    echo
    echo "$UPGRADABLE_PACKAGES"
else
    echo "✓ No remaining upgradable packages."
fi

echo
echo "==> Checking APT package state..."

if ! sudo dpkg --audit; then
    echo "ERROR: dpkg reported package configuration problems."
    exit 1
fi

echo "✓ dpkg package state is clean."

echo
echo "==> Checking available disk space..."

df -h /

echo
echo "====================================="
echo " System refresh completed"
echo "====================================="