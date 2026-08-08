#!/usr/bin/env bash

set -euo pipefail

echo "====================================="
echo " Essential Packages"
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
echo "==> Installing essential packages..."

sudo apt install -y \
    git \
    curl \
    wget \
    zip \
    unzip \
    tree \
    jq \
    htop \
    vim \
    gnupg \
    ca-certificates \
    software-properties-common

echo "✓ Essential packages installed."

echo
echo "====================================="
echo " Essential packages completed"
echo "====================================="
