#!/bin/bash

# Simple kubeconfig validation script
# Tests the generated kubeconfig without complex logic

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Kubeconfig Validation ==="

# Check if kubeconfig exists
if [ ! -f "./kubeconfig" ]; then
    echo -e "${RED}❌ kubeconfig file not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ kubeconfig file exists${NC}"

# Test YAML parsing
if ! kubectl --kubeconfig=./kubeconfig config view --minify >/dev/null 2>&1; then
    echo -e "${RED}❌ kubeconfig has invalid YAML structure${NC}"
    exit 1
fi

echo -e "${GREEN}✓ kubeconfig has valid YAML structure${NC}"

# Check required fields
CLUSTER_NAME=$(kubectl --kubeconfig=./kubeconfig config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || echo "")
USER_NAME=$(kubectl --kubeconfig=./kubeconfig config view --minify -o jsonpath='{.users[0].name}' 2>/dev/null || echo "")
SERVER_URL=$(kubectl --kubeconfig=./kubeconfig config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo "")

if [ "$CLUSTER_NAME" != "infraflux-rke2" ]; then
    echo -e "${RED}❌ Incorrect cluster name: $CLUSTER_NAME${NC}"
    exit 1
fi

if [ "$USER_NAME" != "infraflux-admin" ]; then
    echo -e "${RED}❌ Incorrect user name: $USER_NAME${NC}"
    exit 1
fi

if [[ ! "$SERVER_URL" =~ ^https://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:6443$ ]]; then
    echo -e "${YELLOW}⚠ Server URL format: $SERVER_URL${NC}"
fi

echo -e "${GREEN}✓ kubeconfig structure is correct${NC}"
echo -e "${GREEN}✓ Cluster: $CLUSTER_NAME${NC}"
echo -e "${GREEN}✓ User: $USER_NAME${NC}"
echo -e "${GREEN}✓ Server: $SERVER_URL${NC}"

# Test connection (optional)
if kubectl --kubeconfig=./kubeconfig cluster-info >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Cluster is accessible${NC}"
    NODE_COUNT=$(kubectl --kubeconfig=./kubeconfig get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    echo -e "${GREEN}✓ Node count: $NODE_COUNT${NC}"
else
    echo -e "${YELLOW}⚠ Cluster not accessible (may be expected)${NC}"
fi

echo -e "${GREEN}=== Validation completed ===${NC}"
