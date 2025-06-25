#!/bin/bash

# RKE2 Cluster Validation Script
# Tests cluster connectivity and basic functionality

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== RKE2 Cluster Validation ===${NC}"
echo ""

# Test 1: Check if kubeconfig exists
echo -n "Checking kubeconfig file... "
if [ -f "./kubeconfig" ]; then
    echo -e "${GREEN}✓ Found${NC}"
    export KUBECONFIG=$(pwd)/kubeconfig
else
    echo -e "${RED}✗ Missing${NC}"
    echo "Run the deployment first: ./deploy.sh deploy"
    exit 1
fi

# Test 2: Test cluster API connectivity
echo -n "Testing cluster API connectivity... "
if kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Connected${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
    echo "Cluster API is not reachable"
    exit 1
fi

# Test 3: Check nodes
echo -n "Checking cluster nodes... "
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
EXPECTED_NODES=$(terraform output -json rke2_server_ips | jq length)
EXPECTED_AGENTS=$(terraform output -json rke2_agent_ips | jq length)
TOTAL_EXPECTED=$((EXPECTED_NODES + EXPECTED_AGENTS))

if [ "$NODE_COUNT" -eq "$TOTAL_EXPECTED" ]; then
    echo -e "${GREEN}✓ All $NODE_COUNT nodes ready${NC}"
else
    echo -e "${YELLOW}⚠ $NODE_COUNT/$TOTAL_EXPECTED nodes ready${NC}"
fi

# Test 4: Display cluster information
echo ""
echo -e "${GREEN}=== Cluster Information ===${NC}"
echo "API Server: https://$(terraform output -raw rke2_cluster_endpoint):6443"
echo ""
echo "Nodes:"
kubectl get nodes -o wide

echo ""
echo "System Pods:"
kubectl get pods -n kube-system

echo ""
echo -e "${GREEN}=== Cluster Validation Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Deploy applications via GitOps (FluxCD)"
echo "2. Configure BGP peering with Cilium"
echo ""
echo "Test commands:"
echo "  export KUBECONFIG=\$(pwd)/kubeconfig"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
