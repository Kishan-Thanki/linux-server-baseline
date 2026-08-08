#!/usr/bin/env bash

set -euo pipefail

SSHD_CONFIG="/etc/ssh/sshd_config"
HARDENING_CONF="/etc/ssh/sshd_config.d/99-hardening.conf"

echo "====================================="
echo " SSH Hardening"
echo "====================================="

echo
echo "==> Backing up sshd_config..."

if [[ ! -f "${SSHD_CONFIG}.original" ]]; then
    sudo cp "$SSHD_CONFIG" "${SSHD_CONFIG}.original"
    echo "✓ Original backup created."
else
    echo "✓ Original backup already exists. Skipping."
fi

echo
echo "==> Writing SSH hardening configuration..."

sudo mkdir -p /etc/ssh/sshd_config.d

sudo tee "$HARDENING_CONF" >/dev/null <<EOF
# Bootstrap SSH Hardening
# Applied by 05-ssh-hardening.sh

PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
KbdInteractiveAuthentication no
UsePAM yes
MaxAuthTries 3
LoginGraceTime 30
EOF

echo "✓ Hardening configuration written to $HARDENING_CONF"

echo
echo "==> Ensuring sshd_config includes drop-in directory..."

if ! grep -q "^Include /etc/ssh/sshd_config.d/" "$SSHD_CONFIG"; then
    echo "Include /etc/ssh/sshd_config.d/*.conf" | sudo tee -a "$SSHD_CONFIG" >/dev/null
    echo "✓ Include directive added."
else
    echo "✓ Include directive already present."
fi

echo
echo "==> Validating configuration..."

sudo sshd -t

echo "✓ Configuration valid."

echo
echo "==> Restarting SSH..."

sudo systemctl restart ssh

echo "✓ SSH restarted."

echo
echo "====================================="
echo " Verification"
echo "====================================="

echo

sudo sshd -T | grep permitrootlogin

sudo sshd -T | grep passwordauthentication

sudo sshd -T | grep pubkeyauthentication

sudo sshd -T | grep maxauthtries

sudo sshd -T | grep logingracetime

echo
echo "====================================="
echo " SSH hardening completed"
echo "====================================="

echo
echo "╔═══════════════════════════════════════════╗"
echo "║  ⚠️  STOP — DO NOT CONTINUE YET            ║"
echo "║                                           ║"
echo "║  Open a NEW terminal and verify:          ║"
echo "║    ssh admin@<server-public-ip>            ║"
echo "║                                           ║"
echo "║  DO NOT close this session until           ║"
echo "║  you verify the new SSH login works.       ║"
echo "╚═══════════════════════════════════════════╝"
