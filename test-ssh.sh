#!/bin/bash

# Simple SSH test
echo "Testing SSH connectivity to RKE2 nodes..."

# Get IPs from Terraform output
SERVER_IPS=$(terraform output -json rke2_server_ips | jq -r '.[]')
AGENT_IPS=$(terraform output -json rke2_agent_ips | jq -r '.[]')

echo "Testing server nodes:"
for ip in $SERVER_IPS; do
    echo -n "  $ip: "
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes binghzal@$ip "echo 'OK'" 2>/dev/null; then
        echo "✓ Connected"
    else
        echo "✗ Failed"
    fi
done

echo "Testing agent nodes:"
for ip in $AGENT_IPS; do
    echo -n "  $ip: "
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes binghzal@$ip "echo 'OK'" 2>/dev/null; then
        echo "✓ Connected"
    else
        echo "✗ Failed"
    fi
done

echo ""
echo "If all connections are successful, you can proceed with the Ansible deployment."
