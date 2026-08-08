#!/usr/bin/env bash

set -euo pipefail

USERNAME="admin"

PUBLIC_KEY="$HOME/.ssh/authorized_keys"
SSH_DIR="/home/$USERNAME/.ssh"

echo "====================================="
echo " Creating administrator user"
echo "====================================="

if [[ ! -f "$PUBLIC_KEY" ]]; then
    echo "ERROR: Public key not found:"
    echo "  $PUBLIC_KEY"
    exit 1
fi

echo
echo "==> Checking user..."

if id "$USERNAME" >/dev/null 2>&1; then
    echo "✓ User '$USERNAME' already exists."
else
    echo "==> Creating user..."

    sudo useradd \
        -m \
        -g users \
        -s /bin/bash \
        "$USERNAME"

    echo "✓ User created."
fi

echo
echo "==> Locking password (key-only auth)..."

sudo passwd -l "$USERNAME"

echo "✓ Password locked."

echo
echo "==> Ensuring sudo privileges..."

sudo usermod -aG sudo "$USERNAME"

echo "✓ User added to sudo group."

echo
echo "==> Configuring passwordless sudo..."

sudo tee /etc/sudoers.d/$USERNAME >/dev/null <<EOF
$USERNAME ALL=(ALL) NOPASSWD: ALL
EOF

sudo chmod 0440 /etc/sudoers.d/$USERNAME

sudo visudo -cf /etc/sudoers.d/$USERNAME

echo "✓ Passwordless sudo configured."

echo
echo "==> Configuring SSH..."

sudo mkdir -p "$SSH_DIR"

if [[ ! -f "$SSH_DIR/authorized_keys" ]]; then
    sudo cp "$PUBLIC_KEY" "$SSH_DIR/authorized_keys"
    echo "✓ Public key installed."
else
    echo "✓ authorized_keys already exists. Skipping."
fi

echo
echo "==> Fixing ownership..."

sudo chown -R "$USERNAME:users" "$SSH_DIR"

echo "==> Fixing permissions..."

sudo chmod 700 "$SSH_DIR"
sudo chmod 600 "$SSH_DIR/authorized_keys"

echo
echo "====================================="
echo " Verification"
echo "====================================="

id "$USERNAME"
groups "$USERNAME"

sudo visudo -cf /etc/sudoers.d/$USERNAME

echo
echo "✓ Verification passed."

echo
echo "====================================="
echo " Completed Successfully"
echo "====================================="

echo
echo "Username : $USERNAME"
echo "Auth     : SSH key only (password locked)"

echo
echo "Next:"
echo "  ssh $USERNAME@<server-public-ip>"