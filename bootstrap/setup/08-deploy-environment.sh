#!/usr/bin/env bash

set -euo pipefail

DEPLOY_USER="deploy"

echo "====================================="
echo " Deployment Setup"
echo "====================================="

# ─────────────────────────────────────
#  Platform Layout
# ─────────────────────────────────────

echo
echo "==> Creating platform directory structure..."

sudo install -d -m 0755 /opt/platform
sudo install -d -m 0755 /opt/platform/releases
sudo install -d -m 0755 /opt/platform/shared
sudo install -d -m 0755 /opt/platform/tmp
sudo install -d -m 0755 /opt/platform/logs

echo "✓ Platform directories created."

# ─────────────────────────────────────
#  Deploy User
# ─────────────────────────────────────

echo
echo "==> Ensuring $DEPLOY_USER user exists..."

if id "$DEPLOY_USER" >/dev/null 2>&1; then
    echo "✓ User '$DEPLOY_USER' already exists."
else
    sudo useradd \
        --create-home \
        --home-dir "/home/$DEPLOY_USER" \
        --shell /bin/bash \
        "$DEPLOY_USER"

    echo "✓ User '$DEPLOY_USER' created."
fi

# ─────────────────────────────────────
#  Restricted Sudo Policy
# ─────────────────────────────────────

echo
echo "==> Configuring restricted sudo policy..."

sudo tee "/etc/sudoers.d/$DEPLOY_USER" >/dev/null <<EOF
$DEPLOY_USER ALL=(root) NOPASSWD: \
    /usr/bin/mkdir, \
    /usr/bin/tar, \
    /usr/bin/ln, \
    /usr/bin/chown, \
    /usr/bin/chmod, \
    /usr/bin/systemctl restart caddy, \
    /usr/bin/systemctl reload caddy
EOF

sudo chmod 0440 "/etc/sudoers.d/$DEPLOY_USER"

sudo visudo -cf "/etc/sudoers.d/$DEPLOY_USER"

echo "✓ Sudoers policy configured."

# ─────────────────────────────────────
#  Ownership
# ─────────────────────────────────────

echo
echo "==> Setting ownership of /opt/platform..."

sudo chown -R "$DEPLOY_USER:$DEPLOY_USER" /opt/platform

echo "✓ Ownership assigned to $DEPLOY_USER user."

# ─────────────────────────────────────
#  Verification
# ─────────────────────────────────────

echo
echo "====================================="
echo " Verification"
echo "====================================="

echo
echo "Platform layout:"
tree /opt/platform

echo
echo "$DEPLOY_USER user:"
id "$DEPLOY_USER"

echo
echo "Sudoers:"
sudo visudo -cf "/etc/sudoers.d/$DEPLOY_USER"

echo
echo "Ownership:"
ls -la /opt/platform

echo
echo "====================================="
echo " Deployment setup completed"
echo "====================================="