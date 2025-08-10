#!/bin/bash
set -e

echo "=== InfraFlux Proxmox Connectivity Diagnostics ==="
echo

# Set kubeconfig for bootstrap cluster
export KUBECONFIG=/tmp/bootstrap-kubeconfig

echo "1. Checking current cluster and CAPI resources..."
kubectl get clusters,proxmoxclusters,proxmoxmachinetemplates -A

echo
echo "2. Checking Proxmox cluster status and events..."
kubectl describe cluster mgmt-proxmox 2>/dev/null || echo "Cluster not found"
kubectl describe proxmoxcluster proxmox-cluster 2>/dev/null || echo "ProxmoxCluster not found"

echo
echo "3. Checking CAPI provider logs..."
kubectl logs -n capi-system -l cluster.x-k8s.io/provider=infrastructure-proxmox --tail=50

echo
echo "4. Testing Proxmox connectivity from local machine..."
PROXMOX_URL="https://10.0.0.69:8006"
echo "Testing connectivity to: $PROXMOX_URL"

# Test basic connectivity
if curl -k -m 10 -I "$PROXMOX_URL" 2>/dev/null | head -1; then
  echo "✅ Proxmox server is reachable"
else
  echo "❌ Cannot reach Proxmox server at $PROXMOX_URL"
  echo
  echo "Troubleshooting steps:"
  echo "1. Verify Proxmox server is running: ping 10.0.0.69"
  echo "2. Check if port 8006 is accessible: nc -zv 10.0.0.69 8006"
  echo "3. Verify firewall settings allow HTTPS on port 8006"
  echo "4. Check Proxmox web interface in browser: https://10.0.0.69:8006"
  echo "5. Verify credentials in secret-capmox.yaml are correct"
fi

echo
echo "5. Checking CAPMOX provider version and compatibility..."
kubectl get deployment -n capi-system -l cluster.x-k8s.io/provider=infrastructure-proxmox -o yaml | grep -A 5 -B 5 image:

echo
echo "6. Proxmox credentials check..."
kubectl get secret proxmox-credentials -n capi-system -o yaml | base64 -d | grep -E "(PROXMOX_URL|PROXMOX_TOKEN)"

echo
echo "=== Diagnostics Complete ==="
