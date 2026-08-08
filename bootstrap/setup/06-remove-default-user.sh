#!/usr/bin/env bash

set -euo pipefail

USER_TO_REMOVE="ubuntu"
USERNAME="admin"

echo "====================================="
echo " Remove Default User"
echo "====================================="

CURRENT_USER="$(whoami)"

if [[ "$CURRENT_USER" == "$USER_TO_REMOVE" ]]; then
    echo
    echo "ERROR: You are logged in as '$USER_TO_REMOVE'."
    echo "Login as the '$USERNAME' user first."
    exit 1
fi

if ! id "$USERNAME" >/dev/null 2>&1; then
    echo
    echo "ERROR: Admin user '$USERNAME' does not exist."
    exit 1
fi

if ! id "$USER_TO_REMOVE" >/dev/null 2>&1; then
    echo
    echo "✓ User '$USER_TO_REMOVE' already removed."
    exit 0
fi

echo
echo "==> Killing remaining user processes..."

sudo pkill -u "$USER_TO_REMOVE" 2>/dev/null || true

echo "==> Locking account..."

sudo passwd -l "$USER_TO_REMOVE"

echo "✓ Account locked."

echo
echo "==> Removing user..."

sudo deluser --remove-home "$USER_TO_REMOVE"

echo "✓ User removed."

echo
echo "====================================="
echo " Verification"
echo "====================================="

if id "$USER_TO_REMOVE" >/dev/null 2>&1; then
    echo "ERROR: User still exists."
    exit 1
fi

echo "✓ User '$USER_TO_REMOVE' successfully removed."

echo
echo "====================================="
echo " Default user removal completed"
echo "====================================="