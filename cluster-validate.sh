#!/bin/bash
# Simple cluster validation script

echo "=== RKE2 Cluster Validation ==="
echo

# Test direct connection to first server
echo "1. Testing connection to first server node..."
ssh -o StrictHostKeyChecking=no binghzal@10.0.1.100 'kubectl get nodes -o wide'
echo

# Test VIP access
echo "2. Testing cluster access via VIP (10.0.1.50)..."
ssh -o StrictHostKeyChecking=no binghzal@10.0.1.100 'kubectl --server=https://10.0.1.50:6443 --insecure-skip-tls-verify get nodes'
echo

# Show cluster info
echo "3. Cluster information..."
ssh -o StrictHostKeyChecking=no binghzal@10.0.1.100 'kubectl cluster-info'
echo

# Show all pods system
echo "4. System pods status..."
ssh -o StrictHostKeyChecking=no binghzal@10.0.1.100 'kubectl get pods -A | head -20'
echo
