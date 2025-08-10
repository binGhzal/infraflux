#!/usr/bin/env bash
set -euo pipefail

# management/bootstrap.sh
# Simple bootstrap helper for mgmt cluster prerequisites.
# Prereqs: talosctl, clusterctl, flux, kubectl

: "${IFX_NAMESPACE:=infraflux-system}"
: "${IFX_PROVIDERS:=aws,azure,gcp,proxmox}"
: "${IFX_GIT_REPO:?Set IFX_GIT_REPO to your Git repo (e.g., https://github.com/you/infraflux)}"

if ! command -v clusterctl >/dev/null; then echo "clusterctl not found"; exit 1; fi
if ! command -v flux >/dev/null; then echo "flux not found"; exit 1; fi
if ! command -v kubectl >/dev/null; then echo "kubectl not found"; exit 1; fi

providers_csv="$IFX_PROVIDERS"
# Convert to clusterctl flags
capi_flags=()
IFS=',' read -ra arr <<< "$providers_csv"
for p in "${arr[@]}"; do
  case "$p" in
    aws|azure|gcp|proxmox) capi_flags+=("-i" "$p") ;;
    *) echo "warning: unknown provider '$p' ignored" ;;
  esac
done

# Install CAPI providers
clusterctl init "${capi_flags[@]}"

# Namespace for mgmt artifacts
kubectl get ns "$IFX_NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$IFX_NAMESPACE"

# Flux bootstrap to current repo structure (export manifests and apply)
flux install --export > management/flux/gotk-components.yaml
kubectl apply -k management/flux

# Create a GitRepository source for the repo if missing
kubectl -n flux-system get gitrepository infraflux >/dev/null 2>&1 || cat <<EOF | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: infraflux
  namespace: flux-system
spec:
  interval: 1m
  url: $IFX_GIT_REPO
  ref:
    branch: main
EOF

echo "Bootstrap complete. Flux is syncing from $IFX_GIT_REPO."
