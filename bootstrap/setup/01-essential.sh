#!/usr/bin/env bash

# =============================================================================
# 01-essential.sh
#
# Purpose:
# Establish the baseline packages required by the server-ops bootstrap
# process and subsequent infrastructure scripts.
#
# This script intentionally installs only common system utilities.
#
# Application-specific software, web servers, monitoring tools, backup
# utilities, deployment tooling, and database software are configured by
# later scripts.
#
# Run as:
#
# essential
#
# Run as the administrator.
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

export DEBIAN_FRONTEND=noninteractive

ESSENTIAL_PACKAGES=(
    ca-certificates
    curl
    git
    gnupg
    jq
    openssh-client
    python3
    tree
    unzip
    vim
    wget
    zip
)

# =============================================================================
# Header
# =============================================================================

echo "====================================="
echo " Essential Packages"
echo "====================================="

# =============================================================================
# 1. Verify Administrative Access
# =============================================================================

echo
echo "==> Checking administrator privileges..."

if ! sudo -n true; then
    echo "ERROR: Current user does not have working passwordless sudo."
    echo "Run this script as the bootstrap administrator."
    exit 1
fi

echo "✓ Administrator privileges verified."

# =============================================================================
# 2. Update Package Index
# =============================================================================

echo
echo "==> Updating package index..."

sudo apt update

echo "✓ Package index updated."

# =============================================================================
# 3. Upgrade Installed Packages
# =============================================================================

echo
echo "==> Upgrading installed packages..."

sudo apt upgrade -y

echo "✓ Installed packages upgraded."

# =============================================================================
# 4. Install Essential Packages
# =============================================================================

echo
echo "==> Installing essential packages..."

sudo apt install -y "${ESSENTIAL_PACKAGES[@]}"

echo "✓ Essential packages installed."

# =============================================================================
# 5. Verification
# =============================================================================

echo
echo "====================================="
echo " Verification"
echo "====================================="

echo
echo "Required commands:"

for command_name in \
    curl \
    git \
    gpg \
    jq \
    python3 \
    ssh \
    tree \
    unzip \
    vim \
    wget \
    zip; do

    if command -v "$command_name" >/dev/null 2>&1; then
        printf "✓ %-8s %s\n" \
            "$command_name" \
            "$(command -v "$command_name")"
    else
        echo "ERROR: Required command not found: $command_name"
        exit 1
    fi

done

echo
echo "Python version:"
python3 --version

echo
echo "APT status:"
echo "✓ Package index updated"
echo "✓ Installed packages upgraded"
echo "✓ Essential packages installed"

echo
echo "====================================="
echo " Essential packages completed"
echo "====================================="
