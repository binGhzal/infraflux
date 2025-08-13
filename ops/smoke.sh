#!/usr/bin/env bash
set -euo pipefail

echo "[*] Nodes"
kubectl get nodes -o wide

echo "[*] Cilium & kube-proxy status (kube-proxy should be absent)"
kubectl -n kube-system get ds cilium
kubectl -n kube-system get ds kube-proxy || echo "kube-proxy not found (expected)"

echo "[*] Hubble"
kubectl -n kube-system get deploy hubble-ui || true

echo "[*] Gateway API"
kubectl get gatewayclasses
kubectl get gateways -A
kubectl get httproutes -A

echo "[*] Cilium LB/L2 CRDs"
kubectl get ciliumloadbalancerippools.cilium.io -A
kubectl get ciliuml2announcementpolicies.cilium.io -A

echo "[*] cert-manager"
kubectl -n cert-manager get clusterissuer
kubectl -n cert-manager get certificaterequests -A | head

echo "[*] ExternalDNS"
kubectl -n external-dns logs -l app.kubernetes.io/name=external-dns --tail=50

echo "[*] ESO"
kubectl -n external-secrets get externalsecrets,secrets

echo "[*] Longhorn"
kubectl get sc | grep -i longhorn || true

echo "[*] Velero"
kubectl -n velero get backups || true

echo "[*] Argo CD"
kubectl -n argocd get pods
