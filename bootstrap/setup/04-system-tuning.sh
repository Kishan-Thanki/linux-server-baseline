#!/usr/bin/env bash

# =============================================================================
# 04-system-tuning.sh
#
# Purpose:
#   Apply baseline operating-system tuning for the server.
#
# Configures:
#
#   - UTC timezone
#   - Persistent systemd journal
#   - Journal size limits
#   - Kernel parameters
#   - File descriptor limits
#   - 2G swapfile
#   - Persistent swap configuration
#
# IMPORTANT:
#
#   This script provides generic server-level tuning.
#
#
# File locations:
#
#   /etc/systemd/journald.conf.d/99-journald.conf
#   /etc/sysctl.d/99-system-tuning.conf
#   /etc/security/limits.d/99-nofile.conf
#   /swapfile
#
# Run as:
#
#   system-tuning
#
# Run as the administrator configured by 02-setup-admin.sh.
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

TIMEZONE="UTC"

SWAPFILE="/swapfile"
SWAPSIZE="2G"

JOURNALD_CONFIG="/etc/systemd/journald.conf.d/99-journald.conf"
SYSCTL_CONFIG="/etc/sysctl.d/99-system-tuning.conf"
LIMITS_CONFIG="/etc/security/limits.d/99-nofile.conf"

# =============================================================================
# Header
# =============================================================================

echo "====================================="
echo " System Tuning"
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
# 2. Configure Timezone
# =============================================================================

echo
echo "==> Setting timezone..."

sudo timedatectl set-timezone "$TIMEZONE"

echo "✓ Timezone set to $TIMEZONE."

# =============================================================================
# 3. Configure systemd-journald
# =============================================================================

echo
echo "==> Configuring systemd-journald..."

sudo install -d -m 0755 /etc/systemd/journald.conf.d

sudo tee "$JOURNALD_CONFIG" >/dev/null <<EOF
[Journal]
Storage=persistent
Compress=yes
SystemMaxUse=100M
SystemKeepFree=50M
RuntimeMaxUse=30M
EOF

echo "✓ Journald configuration written."

echo
echo "==> Restarting systemd-journald..."

sudo systemctl restart systemd-journald

if ! sudo systemctl is-active --quiet systemd-journald; then
    echo "ERROR: systemd-journald failed to start."
    sudo systemctl --no-pager --full status systemd-journald || true
    exit 1
fi

echo "✓ systemd-journald is active."

# =============================================================================
# 4. Configure Kernel Parameters
# =============================================================================

echo
echo "==> Configuring kernel parameters..."

sudo tee "$SYSCTL_CONFIG" >/dev/null <<EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
fs.file-max=2097152
EOF

echo "✓ Kernel parameter configuration written."

echo
echo "==> Applying kernel parameters..."

sudo sysctl --system >/dev/null

echo "✓ Kernel parameters applied."

# =============================================================================
# 5. Verify Kernel Parameters
# =============================================================================

echo
echo "==> Verifying kernel parameters..."

SWAPPINESS="$(sysctl -n vm.swappiness)"
CACHE_PRESSURE="$(sysctl -n vm.vfs_cache_pressure)"
FILE_MAX="$(sysctl -n fs.file-max)"

if [[ "$SWAPPINESS" != "10" ]]; then
    echo "ERROR: vm.swappiness is $SWAPPINESS; expected 10."
    exit 1
fi

if [[ "$CACHE_PRESSURE" != "50" ]]; then
    echo "ERROR: vm.vfs_cache_pressure is $CACHE_PRESSURE; expected 50."
    exit 1
fi

if [[ "$FILE_MAX" != "2097152" ]]; then
    echo "ERROR: fs.file-max is $FILE_MAX; expected 2097152."
    exit 1
fi

echo "✓ Kernel parameters verified."

# =============================================================================
# 6. Configure File Descriptor Limits
# =============================================================================

echo
echo "==> Configuring file descriptor limits..."

sudo tee "$LIMITS_CONFIG" >/dev/null <<'EOF'
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOF

sudo chmod 0644 "$LIMITS_CONFIG"

echo "✓ File descriptor limits configured."

# =============================================================================
# 7. Verify File Descriptor Limits Configuration
# =============================================================================

echo
echo "==> Verifying file descriptor limits configuration..."

for expected_line in \
    "* soft nofile 65535" \
    "* hard nofile 65535" \
    "root soft nofile 65535" \
    "root hard nofile 65535"; do

    if ! sudo grep -Fqx "$expected_line" "$LIMITS_CONFIG"; then
        echo "ERROR: Missing limits configuration:"
        echo "  $expected_line"
        exit 1
    fi

done

echo "✓ File descriptor limits configuration verified."
echo "NOTE: These limits apply to new login sessions."

# =============================================================================
# 8. Configure Swap
# =============================================================================

echo
echo "==> Configuring swap..."

if sudo swapon --show=NAME --noheadings |
    awk '{$1=$1; print}' |
    grep -Fxq "$SWAPFILE"; then

    echo "✓ $SWAPFILE is already active."

elif [[ -e "$SWAPFILE" ]]; then

    echo "==> Existing $SWAPFILE found."

    if [[ ! -f "$SWAPFILE" ]]; then
        echo "ERROR: $SWAPFILE exists but is not a regular file."
        exit 1
    fi

    echo "==> Verifying swapfile permissions..."

    PERMISSIONS="$(sudo stat -c '%a' "$SWAPFILE")"

    if [[ "$PERMISSIONS" != "600" ]]; then
        echo "==> Securing existing swapfile..."
        sudo chmod 0600 "$SWAPFILE"
    fi

    echo "==> Verifying swap signature..."

    if ! sudo file "$SWAPFILE" | grep -qi "swap file"; then
        echo "ERROR: Existing $SWAPFILE does not appear to contain a valid"
        echo "swap signature."
        echo "Refusing to overwrite the existing file."
        exit 1
    fi

    echo "✓ Existing swapfile appears valid."

    echo "==> Enabling existing swapfile..."

    sudo swapon "$SWAPFILE"

    echo "✓ Existing swapfile enabled."

else

    echo "==> Creating ${SWAPSIZE} swapfile..."

    if ! sudo fallocate -l "$SWAPSIZE" "$SWAPFILE"; then
        echo "WARNING: fallocate failed; attempting dd fallback..."

        sudo dd \
            if=/dev/zero \
            of="$SWAPFILE" \
            bs=1M \
            count=2048 \
            status=progress
    fi

    echo "==> Securing swapfile..."

    sudo chmod 0600 "$SWAPFILE"

    echo "==> Formatting swapfile..."

    sudo mkswap "$SWAPFILE" >/dev/null

    echo "==> Enabling swapfile..."

    sudo swapon "$SWAPFILE"

    echo "✓ Swapfile created and enabled."

fi

# =============================================================================
# 9. Verify Active Swap
# =============================================================================

echo
echo "==> Verifying active swap..."

if ! sudo swapon --show=NAME --noheadings |
    awk '{$1=$1; print}' |
    grep -Fxq "$SWAPFILE"; then

    echo "ERROR: $SWAPFILE is not active."
    exit 1
fi

echo "✓ $SWAPFILE is active."

# =============================================================================
# 10. Configure Persistent Swap
# =============================================================================

echo
echo "==> Configuring /etc/fstab..."

if sudo grep -qE "^[[:space:]]*${SWAPFILE//\//\\/}[[:space:]]+none[[:space:]]+swap[[:space:]]" /etc/fstab; then

    echo "✓ Swapfile already present in /etc/fstab."

else

    echo "$SWAPFILE none swap sw 0 0" |
        sudo tee -a /etc/fstab >/dev/null

    echo "✓ Swapfile added to /etc/fstab."

fi

# =============================================================================
# 11. Verify /etc/fstab
# =============================================================================

echo
echo "==> Verifying persistent swap configuration..."

if ! sudo grep -qE "^[[:space:]]*${SWAPFILE//\//\\/}[[:space:]]+none[[:space:]]+swap[[:space:]]" /etc/fstab; then
    echo "ERROR: Swapfile entry was not found in /etc/fstab."
    exit 1
fi

echo "✓ Persistent swap configuration verified."

# =============================================================================
# Verification
# =============================================================================

echo
echo "====================================="
echo " Verification"
echo "====================================="

echo
echo "Timezone:"
timedatectl show \
    --property=Timezone \
    --value

echo
echo "Journald:"
sudo systemctl is-active systemd-journald

echo
echo "Journald configuration:"
sudo cat "$JOURNALD_CONFIG"

echo
echo "Kernel parameters:"
printf "vm.swappiness         = %s\n" "$(sysctl -n vm.swappiness)"
printf "vm.vfs_cache_pressure = %s\n" "$(sysctl -n vm.vfs_cache_pressure)"
printf "fs.file-max            = %s\n" "$(sysctl -n fs.file-max)"

echo
echo "File descriptor limits:"
sudo cat "$LIMITS_CONFIG"

echo
echo "Active swap:"
sudo swapon --show

echo
echo "Memory:"
free -h

echo
echo "Persistent swap configuration:"
sudo grep -E "^[[:space:]]*${SWAPFILE//\//\\/}[[:space:]]+none[[:space:]]+swap[[:space:]]" /etc/fstab

# =============================================================================
# Completion
# =============================================================================

echo
echo "====================================="
echo " System tuning completed"
echo "====================================="

echo
echo "Timezone       : $TIMEZONE"
echo "Journald       : Persistent"
echo "Journal limit  : 100M"
echo "Swappiness     : 10"
echo "Cache pressure : 50"
echo "File-max       : 2097152"
echo "nofile limit   : 65535"
echo "Swap           : $SWAPFILE ($SWAPSIZE target)"
