#!/usr/bin/env bash

set -euo pipefail

echo "====================================="
echo " Firewall & Intrusion Protection"
echo "====================================="

# ─────────────────────────────────────
#  UFW
# ─────────────────────────────────────

echo
echo "==> Installing UFW..."

sudo apt install -y ufw

echo "==> Resetting firewall..."

sudo ufw --force reset

echo "==> Setting default policies..."

sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "==> Allowing SSH..."

sudo ufw allow 22/tcp

echo "==> Allowing HTTP..."

sudo ufw allow 80/tcp

echo "==> Allowing HTTPS..."

sudo ufw allow 443/tcp

echo "==> Enabling firewall..."

sudo ufw --force enable

echo "✓ UFW configured."

# ─────────────────────────────────────
#  Fail2Ban
# ─────────────────────────────────────

HOSTNAME="$(hostname)"

echo
echo "==> Installing Fail2Ban..."

sudo apt install -y fail2ban

echo "✓ Fail2Ban installed."

echo
echo "==> Creating local configuration..."

sudo tee /etc/fail2ban/jail.local >/dev/null <<EOF
[DEFAULT]

allowipv6 = auto

backend = systemd

bantime  = 1h
findtime = 10m
maxretry = 5

banaction = ufw

destemail = root@localhost
sender = fail2ban@${HOSTNAME}

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
EOF

echo "✓ jail.local created."

echo
echo "==> Enabling service..."

sudo systemctl enable fail2ban >/dev/null
sudo systemctl restart fail2ban

echo "==> Waiting for Fail2Ban to start..."

sudo systemctl is-active --wait fail2ban >/dev/null 2>&1 || sleep 3

echo "✓ Fail2Ban started."

echo
echo "==> Validating configuration..."

sudo systemctl is-active --quiet fail2ban

echo "✓ Service is active."

# ─────────────────────────────────────
#  Verification
# ─────────────────────────────────────

echo
echo "====================================="
echo " Verification"
echo "====================================="

echo
echo "Firewall status:"
sudo ufw status verbose

echo
echo "Fail2Ban service:"
sudo systemctl --no-pager --full status fail2ban | head -n 8

echo
echo "Configured jails:"
sudo fail2ban-client status

echo
echo "====================================="
echo " Firewall & intrusion protection completed"
echo "====================================="
