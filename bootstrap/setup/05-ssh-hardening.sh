#!/usr/bin/env bash

# =============================================================================
# 05-ssh-hardening.sh
#
# Purpose:
#   Harden the OpenSSH server configuration while preserving key-based
#   administrator access.
#
# Security policy:
#
#   Root SSH login             -> disabled
#   Password authentication    -> disabled
#   Public-key authentication -> enabled
#   Empty passwords            -> disabled
#   Keyboard-interactive auth  -> disabled
#   PAM                        -> enabled
#   Maximum auth attempts      -> 3
#   Login grace period         -> 30 seconds
#
# IMPORTANT:
#
#   This script changes SSH authentication policy.
#
#   BEFORE running this script:
#
#   1. Confirm the administrator SSH key works.
#   2. Keep the current SSH session open.
#   3. After the reload, open a NEW terminal.
#   4. Verify that the admin account can still log in.
#   5. Only then close the original session.
#
#   DO NOT run this script if you have not verified key-based admin access.
#
# Files:
#
#   /etc/ssh/sshd_config
#   /etc/ssh/sshd_config.d/99-hardening.conf
#   /etc/ssh/sshd_config.original
#
# Run as:
#
#   ssh-hardening
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_DROPIN_DIR="/etc/ssh/sshd_config.d"

HARDENING_CONF="$SSHD_DROPIN_DIR/99-hardening.conf"
ORIGINAL_BACKUP="${SSHD_CONFIG}.original"

SSH_SERVICE="ssh"

# =============================================================================
# Header
# =============================================================================

echo "====================================="
echo " SSH Hardening"
echo "====================================="

# =============================================================================
# 1. Verify Administrative Access
# =============================================================================

echo
echo "==> Checking administrator privileges..."

if ! sudo -n true; then
    echo "ERROR: Current user does not have working passwordless sudo."
    echo "Run this script as the administrator configured by 02-setup-admin.sh."
    exit 1
fi

echo "✓ Administrative privileges verified."

# =============================================================================
# 2. Verify SSH Configuration Files
# =============================================================================

echo
echo "==> Checking SSH configuration..."

if [[ ! -f "$SSHD_CONFIG" ]]; then
    echo "ERROR: SSH configuration file not found:"
    echo "  $SSHD_CONFIG"
    exit 1
fi

echo "✓ SSH configuration file found."

# =============================================================================
# 3. Verify Current SSH Configuration Before Changes
# =============================================================================

echo
echo "==> Validating current SSH configuration..."

sudo sshd -t

echo "✓ Current SSH configuration is valid."

# =============================================================================
# 4. Create Original Configuration Backup
# =============================================================================

echo
echo "==> Backing up sshd_config..."

if [[ ! -f "$ORIGINAL_BACKUP" ]]; then

    sudo cp "$SSHD_CONFIG" "$ORIGINAL_BACKUP"
    sudo chmod 0600 "$ORIGINAL_BACKUP"

    echo "✓ Original SSH configuration backup created."

else

    echo "✓ Original SSH configuration backup already exists."
    echo "  Existing backup will not be overwritten."

fi

# =============================================================================
# 5. Ensure SSH Drop-in Directory Exists
# =============================================================================

echo
echo "==> Ensuring SSH drop-in directory exists..."

sudo install -d -m 0755 "$SSHD_DROPIN_DIR"

echo "✓ SSH drop-in directory ready."

# =============================================================================
# 6. Verify Drop-in Include Support
# =============================================================================

echo
echo "==> Checking SSH drop-in support..."

if sudo grep -Eq \
    '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf[[:space:]]*$' \
    "$SSHD_CONFIG"; then

    echo "✓ SSH drop-in Include directive already exists."

else

    echo "==> Adding SSH drop-in Include directive..."

    printf '%s\n' \
        'Include /etc/ssh/sshd_config.d/*.conf' |
        sudo tee -a "$SSHD_CONFIG" >/dev/null

    echo "✓ SSH drop-in Include directive added."

fi

# =============================================================================
# 7. Write SSH Hardening Policy
# =============================================================================

echo
echo "==> Writing SSH hardening configuration..."

sudo tee "$HARDENING_CONF" >/dev/null <<'EOF'
# =============================================================================
# SSH Hardening
#
# Managed by:
#   05-ssh-hardening.sh
#
# Do not edit this file manually unless the bootstrap configuration is being
# intentionally changed.
# =============================================================================

PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
KbdInteractiveAuthentication no
UsePAM yes

MaxAuthTries 3
LoginGraceTime 30
EOF

sudo chmod 0644 "$HARDENING_CONF"

echo "✓ SSH hardening configuration written:"
echo "  $HARDENING_CONF"

# =============================================================================
# 8. Validate SSH Configuration Before Reload
# =============================================================================

echo
echo "==> Validating SSH configuration..."

if ! sudo sshd -t; then
    echo
    echo "ERROR: SSH configuration validation failed."
    echo
    echo "The SSH service has NOT been reloaded."
    echo
    echo "Hardening configuration:"
    sudo cat "$HARDENING_CONF"
    exit 1
fi

echo "✓ SSH configuration syntax is valid."

# =============================================================================
# 9. Validate Effective SSH Configuration
# =============================================================================

echo
echo "==> Validating effective SSH configuration..."

EFFECTIVE_CONFIG="$(sudo sshd -T)"

declare -A REQUIRED_SETTINGS=(
    ["permitrootlogin"]="no"
    ["passwordauthentication"]="no"
    ["pubkeyauthentication"]="yes"
    ["permitemptypasswords"]="no"
    ["kbdinteractiveauthentication"]="no"
    ["usepam"]="yes"
    ["maxauthtries"]="3"
    ["logingracetime"]="30"
)

for setting in "${!REQUIRED_SETTINGS[@]}"; do

    expected="${REQUIRED_SETTINGS[$setting]}"

    actual="$(
        awk -v key="$setting" '
            $1 == key {
                print $2
                exit
            }
        ' <<<"$EFFECTIVE_CONFIG"
    )"

    if [[ "$actual" != "$expected" ]]; then

        echo "ERROR: SSH setting verification failed."
        echo
        echo "Setting : $setting"
        echo "Expected: $expected"
        echo "Actual  : ${actual:-<missing>}"

        echo
        echo "The SSH service has NOT been reloaded."

        exit 1
    fi

done

echo "✓ Effective SSH configuration verified."

# =============================================================================
# 10. Show Final Configuration Before Reload
# =============================================================================

echo
echo "==> SSH policy that will become active..."

sudo sshd -T |
    grep -E \
        '^(permitrootlogin|passwordauthentication|pubkeyauthentication|permitemptypasswords|kbdinteractiveauthentication|usepam|maxauthtries|logingracetime) ' |
    sort

# =============================================================================
# 11. Reload SSH
# =============================================================================

echo
echo "==> Reloading SSH service..."

sudo systemctl reload "$SSH_SERVICE"

echo "✓ SSH configuration reloaded."

# =============================================================================
# 12. Verify SSH Service
# =============================================================================

echo
echo "==> Verifying SSH service..."

if ! sudo systemctl is-active --quiet "$SSH_SERVICE"; then

    echo "ERROR: SSH service is not active after reload."

    sudo systemctl --no-pager --full status "$SSH_SERVICE" || true

    exit 1
fi

echo "✓ SSH service is active."

# =============================================================================
# Verification
# =============================================================================

echo
echo "====================================="
echo " Verification"
echo "====================================="

echo
echo "Effective SSH configuration:"

sudo sshd -T |
    grep -E \
        '^(permitrootlogin|passwordauthentication|pubkeyauthentication|permitemptypasswords|kbdinteractiveauthentication|usepam|maxauthtries|logingracetime) ' |
    sort

echo
echo "SSH service:"

sudo systemctl --no-pager --full status "$SSH_SERVICE" |
    head -n 8

echo
echo "Hardening configuration:"

sudo cat "$HARDENING_CONF"

echo
echo "====================================="
echo " SSH hardening completed"
echo "====================================="

echo
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  STOP — VERIFY SSH ACCESS BEFORE CONTINUING                ║"
echo "║                                                            ║"
echo "║  Keep this terminal/session open.                          ║"
echo "║                                                            ║"
echo "║  Open a NEW terminal and test the administrator account:   ║"
echo "║                                                            ║"
echo "║      ssh admin@YOUR_SERVER_IP                              ║"
echo "║                                                            ║"
echo "║  Confirm that the new SSH connection succeeds.             ║"
echo "║                                                            ║"
echo "║  DO NOT close the current session until that test passes.  ║"
echo "╚════════════════════════════════════════════════════════════╝"
