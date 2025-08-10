#!/bin/bash
set -e

echo "=== InfraFlux Proxmox Deployment - Apply Updated Configurations ==="
echo "This script applies the reconfigured addons for Proxmox deployment"
echo

# Set kubeconfig for bootstrap cluster
export KUBECONFIG=/tmp/bootstrap-kubeconfig

echo "1. Checking cluster connectivity..."
kubectl version --client
kubectl cluster-info

echo
echo "2. Applying updated external-dns configuration (webhook provider, dry-run mode)..."
kubectl apply -k ./platform/addons/external-dns/manifests

echo
echo "3. Applying updated external-secrets configuration (generic provider)..."
kubectl apply -k ./platform/addons/external-secrets/manifests

echo
echo "4. Checking HelmRelease status..."
kubectl get helmreleases -A

echo
echo "5. Waiting for external-dns pod to restart with new configuration..."
sleep 30
kubectl get pods -n external-dns

echo
echo "6. Checking for Kyverno CRDs and reapplying ClusterPolicy if ready..."
if kubectl get crd clusterpolicies.kyverno.io &>/dev/null; then
  echo "Kyverno CRDs are available, reapplying ClusterPolicy..."
  kubectl apply -k ./platform/addons/kyverno/manifests
else
  echo "Kyverno CRDs not yet available, waiting for Kyverno installation to complete..."
  echo "Run: kubectl get helmreleases -n kyverno -w"
fi

echo
echo "7. Final status check..."
kubectl get helmreleases,pods -A | grep -E "(cert-manager|external-dns|external-secrets|kyverno|podinfo)"

echo
echo "=== Configuration Update Complete ==="
echo "✅ external-dns: Reconfigured for webhook provider (dry-run mode)"
echo "✅ external-secrets: Updated with generic ClusterSecretStore"
echo "⏳ Waiting for pods to restart with new configurations"
echo
echo "Next steps:"
echo "1. Check Proxmox connectivity: kubectl get clusters,proxmoxclusters -A"
echo "2. Monitor addon deployments: kubectl get helmreleases -A -w"
echo "3. Verify Cilium status: cilium status"
