#!/usr/bin/env bash

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# NOTE: This file is selective and subjective. 
# You can use any alternative reverse proxy or web server 
# (e.g., Nginx, Traefik, HAProxy) instead of Caddy.
# ─────────────────────────────────────────────────────────────

echo "====================================="
echo " Caddy Reverse Proxy"
echo "====================================="

echo
echo "==> Installing prerequisites..."

sudo apt update
sudo apt install -y \
    curl \
    gnupg \
    debian-keyring \
    debian-archive-keyring \
    apt-transport-https

echo "✓ Prerequisites installed."

echo
echo "==> Creating keyring directory..."

sudo install -m 0755 -d /etc/apt/keyrings

echo "==> Installing Caddy GPG key..."

curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
| sudo gpg --dearmor --yes -o /etc/apt/keyrings/caddy-stable.gpg

sudo chmod a+r /etc/apt/keyrings/caddy-stable.gpg

echo "==> Adding repository..."

echo \
"deb [signed-by=/etc/apt/keyrings/caddy-stable.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
| sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null

echo
echo "==> Updating package index..."

sudo apt update

echo "==> Installing Caddy..."

sudo apt install -y caddy

echo "==> Enabling service..."

sudo systemctl enable caddy
sudo systemctl start caddy

echo "✓ Caddy installed and running."
echo
echo "==> Configuring modular Caddy structure..."

sudo mkdir -p /etc/caddy/conf.d

echo "import /etc/caddy/conf.d/*.caddy" | sudo tee /etc/caddy/Caddyfile >/dev/null

sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy

echo "✓ Modular Caddy configuration applied successfully."

echo
echo "====================================="
echo " Verification"
echo "====================================="

echo
echo "Installed version:"
caddy version

echo
echo "Service:"
sudo systemctl --no-pager --full status caddy

echo
echo "Listening sockets:"
sudo ss -tulpn | grep caddy || true

echo
echo "Binary:"
which caddy

echo
echo "====================================="
echo " Caddy installation completed"
echo "====================================="