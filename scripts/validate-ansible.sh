#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Checking Ansible playbook syntax"

for playbook in playbooks/*.yml; do
    echo "    $playbook"
    ansible-playbook "$playbook" \
        --syntax-check \
        -i inventory/inventory.ini
done

echo "==> Checking Ansible inventory"

ansible-inventory \
    -i inventory/inventory.ini \
    --graph >/dev/null

echo "==> Running ansible-lint"

ansible-lint \
    --offline \
    .

echo "==> Ansible validation passed"
