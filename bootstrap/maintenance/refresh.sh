#!/usr/bin/env bash

# refresh.sh
#
# Purpose:
#   Perform a manual system package refresh.
#
# Operations:
#   - Update the APT package index
#   - Upgrade installed packages
#   - Remove packages that are no longer required
#   - Clean the local APT package cache
#   - Verify the resulting package state
#
# Usage:
#   ./refresh.sh
#
# Requirements:
#   - Bash
#   - sudo with non-interactive administrative access
#   - APT-based Linux distribution

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> Checking administrator privileges..."

if ! sudo -n true; then
    echo "ERROR: Current user does not have working passwordless sudo." >&2
    echo "Run this script as the administrator." >&2
    exit 1
fi

echo "✓ Administrator privileges verified."

echo
echo "==> Updating package index..."
sudo apt-get update
echo "✓ Package index updated."

echo
echo "==> Upgrading installed packages..."
sudo apt-get upgrade -y
echo "✓ Packages upgraded."

echo
echo "==> Removing unnecessary packages..."
sudo apt-get autoremove -y
echo "✓ Unnecessary packages removed."

echo
echo "==> Cleaning package cache..."
sudo apt-get clean
echo "✓ Package cache cleaned."

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
    echo "ERROR: dpkg reported package configuration problems." >&2
    exit 1
fi

echo "✓ dpkg package state is clean."

echo
echo "==> Checking available disk space..."
df -h /

echo
echo "✓ System refresh completed successfully."