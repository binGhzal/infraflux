#!/bin/bash

# Kubeconfig Test Script
# This script tests the generated kubeconfig file

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Kubeconfig Validation Test ===${NC}"
echo ""

# Test 1: Check if kubeconfig exists
echo -n "1. Checking kubeconfig file exists... "
if [ -f "./kubeconfig" ]; then
    echo -e "${GREEN}✓ Found${NC}"
else
    echo -e "${RED}✗ Missing${NC}"
    echo "Run deployment first: ./deploy.sh deploy"
    exit 1
fi

# Test 2: Validate kubeconfig structure
echo -n "2. Validating kubeconfig structure... "
if kubectl --kubeconfig=./kubeconfig config view --minify >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Valid YAML structure${NC}"
else
    echo -e "${RED}✗ Invalid YAML structure${NC}"
    exit 1
fi

# Test 3: Check cluster name
echo -n "3. Checking cluster name... "
CLUSTER_NAME=$(kubectl --kubeconfig=./kubeconfig config view --minify -o jsonpath='{.clusters[0].name}')
if [ "$CLUSTER_NAME" = "infraflux-rke2" ]; then
    echo -e "${GREEN}✓ Correct (infraflux-rke2)${NC}"
else
    echo -e "${RED}✗ Incorrect ($CLUSTER_NAME)${NC}"
    exit 1
fi

# Test 4: Check user name
echo -n "4. Checking user name... "
USER_NAME=$(kubectl --kubeconfig=./kubeconfig config view --minify -o jsonpath='{.users[0].name}')
if [ "$USER_NAME" = "infraflux-admin" ]; then
    echo -e "${GREEN}✓ Correct (infraflux-admin)${NC}"
else
    echo -e "${RED}✗ Incorrect ($USER_NAME)${NC}"
    exit 1
fi

# Test 5: Check server URL
echo -n "5. Checking server URL... "
SERVER_URL=$(kubectl --kubeconfig=./kubeconfig config view --minify -o jsonpath='{.clusters[0].cluster.server}')
EXPECTED_VIP=$(terraform output -raw external_endpoint || echo "{{ external_endpoint }}")
if [[ "$SERVER_URL" == "https://$EXPECTED_VIP:6443" ]]; then
    echo -e "${GREEN}✓ Correct VIP ($SERVER_URL)${NC}"
else
    echo -e "${YELLOW}⚠ Different URL ($SERVER_URL)${NC}"
fi

# Test 6: Test cluster connectivity
echo -n "6. Testing cluster connectivity... "
if kubectl --kubeconfig=./kubeconfig cluster-info >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Connected${NC}"
else
    echo -e "${RED}✗ Connection failed${NC}"
    echo -e "${YELLOW}Note: This might be expected if cluster is not running${NC}"
fi

# Test 7: Test node listing (if cluster is available)
echo -n "7. Testing node listing... "
if kubectl --kubeconfig=./kubeconfig get nodes --no-headers >/dev/null 2>&1; then
    NODE_COUNT=$(kubectl --kubeconfig=./kubeconfig get nodes --no-headers | wc -l)
    echo -e "${GREEN}✓ Success (${NODE_COUNT} nodes)${NC}"
else
    echo -e "${YELLOW}⚠ Nodes not accessible (cluster may not be ready)${NC}"
fi

echo ""
echo -e "${GREEN}=== Kubeconfig validation completed ===${NC}"
echo ""
echo "Current kubeconfig details:"
echo "• Cluster: $CLUSTER_NAME"
echo "• User: $USER_NAME"
echo "• Server: $SERVER_URL"
echo ""
echo "Usage: export KUBECONFIG=\$(pwd)/kubeconfig"
