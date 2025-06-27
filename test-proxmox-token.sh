#!/bin/bash

# Proxmox API Token Test Script
# This script tests if your Proxmox API token is valid

set -e

# Load variables from terraform.tfvars
PROXMOX_API_URL=$(grep proxmox_api_url infrastructure/terraform.tfvars | cut -d'"' -f2)
PROXMOX_TOKEN_ID=$(grep proxmox_api_token_id infrastructure/terraform.tfvars | cut -d'"' -f2)
PROXMOX_TOKEN_SECRET=$(grep proxmox_api_token_secret infrastructure/terraform.tfvars | cut -d'"' -f2)

echo "Testing Proxmox API Token..."
echo "API URL: $PROXMOX_API_URL"
echo "Token ID: $PROXMOX_TOKEN_ID"
echo "Token Secret: ${PROXMOX_TOKEN_SECRET:0:8}... (truncated for security)"
echo ""

# Test the API token
echo "Testing API connection..."
echo "Full token: ${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}"
echo ""

# Test basic connectivity first
echo "Testing basic connectivity..."
BASIC_RESPONSE=$(curl -k -s -w "%{http_code}" "${PROXMOX_API_URL}/version" -o /tmp/proxmox_basic.json)
BASIC_HTTP_CODE="${BASIC_RESPONSE: -3}"
echo "Basic connectivity: HTTP $BASIC_HTTP_CODE"

if [ "$BASIC_HTTP_CODE" != "401" ] && [ "$BASIC_HTTP_CODE" != "200" ]; then
    echo "❌ Cannot reach Proxmox API at all"
    cat /tmp/proxmox_basic.json
    exit 1
fi

RESPONSE=$(curl -k -s -w "%{http_code}" -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}" \
     "${PROXMOX_API_URL}/version" -o /tmp/proxmox_test.json)

HTTP_CODE="${RESPONSE: -3}"

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ SUCCESS: Proxmox API token is valid!"
    echo "Proxmox Version:"
    cat /tmp/proxmox_test.json | jq '.' 2>/dev/null || cat /tmp/proxmox_test.json
else
    echo "❌ FAILED: HTTP $HTTP_CODE"
    echo "Response:"
    cat /tmp/proxmox_test.json
    echo ""
    echo "Common issues:"
    echo "1. Token secret might be incorrect (check for typos)"
    echo "2. Token might be disabled in Proxmox"
    echo "3. Token might not have proper permissions"
    echo "4. API URL might be incorrect"
    echo ""
    echo "To fix:"
    echo "1. Go to Proxmox Web UI > Datacenter > Permissions > API Tokens"
    echo "2. Find or create token 'root@pam!packer'"
    echo "3. Ensure it has Administrator role or proper permissions"
    echo "4. Copy the exact secret to terraform.tfvars"
fi

# Cleanup
rm -f /tmp/proxmox_test.json