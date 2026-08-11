#!/usr/bin/env bash

# =============================================================================
# 02-setup-admin.sh
#
# Purpose:
#   Create and configure the dedicated server administrator account.
#
# Administrator:
#   admin
#
# The admin account:
#   - Uses the SSH key provisioned during initial server creation.
#   - Has its Unix password locked.
#   - Belongs to the sudo group.
#   - Has passwordless sudo for administrative operations.
#
# IMPORTANT:
#   This is the administrative account for server management.
#
#
# Run as:
#   setup-admin
#
# Run this script as the initial/provisioned server user whose SSH
# authorized_keys contains the administrator key.
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

USERNAME="admin"

SOURCE_AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"

SSH_DIR="/home/$USERNAME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

SUDOERS_FILE="/etc/sudoers.d/$USERNAME"

# =============================================================================
# Header
# =============================================================================

echo "====================================="
echo " Creating administrator user"
echo "====================================="

# =============================================================================
# 1. Verify Administrative Access
# =============================================================================

echo
echo "==> Checking administrator privileges..."

if ! sudo -n true; then
    echo "ERROR: Current user does not have working passwordless sudo."
    echo "Run this script as the initial/provisioned server administrator."
    exit 1
fi

echo "✓ Administrative privileges verified."

# =============================================================================
# 2. Locate Provisioned SSH Key
# =============================================================================

echo
echo "==> Detecting provisioned SSH authorized_keys..."

if [[ ! -f "$SOURCE_AUTHORIZED_KEYS" ]]; then
    echo "ERROR: Initial user's authorized_keys not found:"
    echo "  $SOURCE_AUTHORIZED_KEYS"
    exit 1
fi

if [[ ! -s "$SOURCE_AUTHORIZED_KEYS" ]]; then
    echo "ERROR: Initial user's authorized_keys is empty:"
    echo "  $SOURCE_AUTHORIZED_KEYS"
    exit 1
fi

echo "✓ Provisioned SSH authorized_keys found."

# =============================================================================
# 3. Create Administrator User
# =============================================================================

echo
echo "==> Ensuring administrator user exists..."

if id "$USERNAME" >/dev/null 2>&1; then

    echo "✓ User '$USERNAME' already exists."

else

    sudo useradd \
        --create-home \
        --shell /bin/bash \
        "$USERNAME"

    echo "✓ User '$USERNAME' created."

fi

# =============================================================================
# 4. Configure Administrator Group Membership
# =============================================================================

echo
echo "==> Ensuring '$USERNAME' belongs to sudo group..."

sudo usermod -aG sudo "$USERNAME"

echo "✓ '$USERNAME' is configured as a sudo administrator."

# =============================================================================
# 5. Lock Administrator Password
# =============================================================================

echo
echo "==> Locking '$USERNAME' password..."

sudo passwd -l "$USERNAME" >/dev/null

echo "✓ Password locked."

# =============================================================================
# 6. Configure Passwordless Sudo
# =============================================================================

echo
echo "==> Configuring passwordless sudo..."

sudo tee "$SUDOERS_FILE" >/dev/null <<EOF
$USERNAME ALL=(ALL) NOPASSWD: ALL
EOF

sudo chmod 0440 "$SUDOERS_FILE"

sudo visudo -cf "$SUDOERS_FILE"

echo "✓ Passwordless sudo configured."

# =============================================================================
# 7. Configure SSH Directory
# =============================================================================

echo
echo "==> Configuring administrator SSH directory..."

sudo install \
    -d \
    -m 0700 \
    -o "$USERNAME" \
    -g "$USERNAME" \
    "$SSH_DIR"

echo "✓ SSH directory configured."

# =============================================================================
# 8. Configure Administrator Authorized Keys
# =============================================================================

echo
echo "==> Configuring administrator authorized_keys..."

if [[ ! -f "$AUTHORIZED_KEYS" ]]; then

    sudo install \
        -m 0600 \
        -o "$USERNAME" \
        -g "$USERNAME" \
        "$SOURCE_AUTHORIZED_KEYS" \
        "$AUTHORIZED_KEYS"

    echo "✓ Provisioned SSH keys copied to '$USERNAME'."

else

    echo "✓ '$USERNAME' authorized_keys already exists."

    # Preserve existing administrator keys while ensuring every key
    # provisioned on the initial account is also available to $USERNAME.

    while IFS= read -r key; do

        [[ -z "$key" ]] && continue

        if ! sudo grep -Fxq "$key" "$AUTHORIZED_KEYS"; then

            printf '%s\n' "$key" |
                sudo tee -a "$AUTHORIZED_KEYS" >/dev/null

            echo "✓ Missing provisioned SSH key added to '$USERNAME'."

        fi

    done <"$SOURCE_AUTHORIZED_KEYS"

fi

sudo chown "$USERNAME:$USERNAME" "$AUTHORIZED_KEYS"
sudo chmod 0600 "$AUTHORIZED_KEYS"

echo "✓ Administrator SSH authorization configured."

# =============================================================================
# 9. Verification
# =============================================================================

echo
echo "====================================="
echo " Verification"
echo "====================================="

echo
echo "==> Administrator account..."

id "$USERNAME"

echo
echo "==> Administrator groups..."

groups "$USERNAME"

echo
echo "==> Password status..."

PASSWORD_STATUS="$(sudo passwd -S "$USERNAME" | awk '{print $2}')"

if [[ "$PASSWORD_STATUS" != "L" ]]; then
    echo "ERROR: Administrator password is not locked."
    exit 1
fi

echo "✓ Administrator password is locked."

echo
echo "==> SSH directory..."

sudo ls -ld "$SSH_DIR"

echo
echo "==> Authorized keys..."

sudo ls -l "$AUTHORIZED_KEYS"

if [[ ! -s "$AUTHORIZED_KEYS" ]]; then
    echo "ERROR: Administrator authorized_keys is empty."
    exit 1
fi

echo "✓ Administrator authorized_keys contains SSH keys."

echo
echo "==> Sudoers validation..."

sudo visudo -cf "$SUDOERS_FILE"

echo "✓ Sudoers configuration is valid."

echo
echo "==> Testing passwordless sudo..."

if sudo -u "$USERNAME" sudo -n true; then
    echo "✓ Passwordless sudo verified for '$USERNAME'."
else
    echo "ERROR: Passwordless sudo verification failed for '$USERNAME'."
    exit 1
fi

# =============================================================================
# Completion
# =============================================================================

echo
echo "====================================="
echo " Administrator setup completed"
echo "====================================="

echo
echo "Username : $USERNAME"
echo "SSH      : Provisioned SSH key"
echo "Password : Locked"
echo "Sudo     : Passwordless"
echo
echo "The '$USERNAME' account is now the server administrator."
