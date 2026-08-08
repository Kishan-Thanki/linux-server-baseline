#!/usr/bin/env bash

set -euo pipefail

echo "====================================="
echo " System Refresh"
echo "====================================="

echo
echo "==> Updating package index..."

sudo apt update

echo "✓ Package index updated."

echo
echo "==> Upgrading installed packages..."

sudo apt upgrade -y

echo "✓ Packages upgraded."

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
echo " System refresh completed"
echo "====================================="
