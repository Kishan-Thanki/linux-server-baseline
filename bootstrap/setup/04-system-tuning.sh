#!/usr/bin/env bash

set -euo pipefail

SWAPFILE="/swapfile"
SWAPSIZE="2G"

echo "====================================="
echo " System Tuning"
echo "====================================="

echo
echo "==> Setting timezone..."

sudo timedatectl set-timezone UTC

echo "✓ Timezone set to UTC."

echo
echo "==> Configuring systemd-journald..."

sudo mkdir -p /etc/systemd/journald.conf.d

sudo tee /etc/systemd/journald.conf.d/99-journald.conf >/dev/null <<EOF
[Journal]
Storage=persistent
Compress=yes
SystemMaxUse=100M
SystemKeepFree=50M
RuntimeMaxUse=30M
EOF

sudo systemctl daemon-reload
sudo systemctl restart systemd-journald

echo "✓ Journald configured."

echo
echo "==> Configuring kernel parameters..."

sudo tee /etc/sysctl.d/99-system-tuning.conf >/dev/null <<EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
fs.file-max=2097152
EOF

sudo sysctl --system >/dev/null

echo "✓ Kernel parameters applied."

echo
echo "==> Configuring file descriptor limits..."

sudo tee /etc/security/limits.d/99-nofile.conf >/dev/null <<EOF
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOF

echo "✓ File descriptor limits configured."

echo
echo "==> Configuring swap..."

if sudo swapon --show | grep -q "$SWAPFILE"; then
    echo "✓ Swap already enabled."
else
    echo "==> Creating ${SWAPSIZE} swapfile..."

    sudo fallocate -l "$SWAPSIZE" "$SWAPFILE"

    echo "==> Securing swapfile..."

    sudo chmod 600 "$SWAPFILE"

    echo "==> Formatting swap..."

    sudo mkswap "$SWAPFILE"

    echo "==> Enabling swap..."

    sudo swapon "$SWAPFILE"

    echo "✓ Swap enabled."
fi

echo
echo "==> Configuring /etc/fstab..."

if ! grep -q "^$SWAPFILE" /etc/fstab; then
    echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
    echo "✓ Added to /etc/fstab."
else
    echo "✓ Already present in /etc/fstab."
fi

echo
echo "====================================="
echo " Verification"
echo "====================================="

echo
echo "Timezone:"
timedatectl | grep "Time zone"

echo
echo "Kernel parameters:"
sysctl vm.swappiness
sysctl vm.vfs_cache_pressure
sysctl fs.file-max

echo
echo "File descriptor limits (configured):"
cat /etc/security/limits.d/99-nofile.conf
echo
echo "(takes effect on next login)"

echo
echo "Active swap:"
sudo swapon --show

echo
echo "Memory:"
free -h

echo
echo "fstab entry:"
grep "^$SWAPFILE" /etc/fstab

echo
echo "====================================="
echo " System tuning completed"
echo "====================================="
