#!/bin/bash

# Test kubeconfig generation in Ansible
# This script tests only the kubeconfig manager role

set -e

echo "=== Testing Kubeconfig Generation ==="

# Change to ansible directory
cd ansible/RKE2

# Run only the kubeconfig manager role
echo "Running kubeconfig manager role..."
ansible-playbook -i inventory/hosts.ini -l servers[0] --tags kubeconfig_manager --ask-become-pass site.yaml

echo "Checking generated kubeconfig..."
if [ -f "../../kubeconfig" ]; then
    echo "✓ kubeconfig generated successfully"

    # Basic validation
    if kubectl --kubeconfig=../../kubeconfig config view --minify >/dev/null 2>&1; then
        echo "✓ kubeconfig is valid YAML"

        CLUSTER_NAME=$(kubectl --kubeconfig=../../kubeconfig config view --minify -o jsonpath='{.clusters[0].name}')
        USER_NAME=$(kubectl --kubeconfig=../../kubeconfig config view --minify -o jsonpath='{.users[0].name}')

        echo "✓ Cluster: $CLUSTER_NAME"
        echo "✓ User: $USER_NAME"
    else
        echo "✗ kubeconfig has invalid structure"
        exit 1
    fi
else
    echo "✗ kubeconfig not generated"
    exit 1
fi

echo "=== Test completed ==="
