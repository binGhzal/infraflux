#!/usr/bin/env bash
set -Eeuo pipefail

# InfraFlux bootstrap: kind -> clusterctl init -> provision mgmt (Talos) -> move -> flux bootstrap
# This is a scaffold; fill provider specifics and versions in platform/* as you iterate.

usage() {
  cat <<'USAGE'
Usage: hack/bootstrap.sh --provider <aws|azure|gcp|proxmox|metal3> [--cluster-name <name>] [--git-url <git url>] [--branch <branch>]

Notes:
- --name is accepted as an alias for --cluster-name for convenience.
- This script creates a temporary kind cluster named "bootstrap" and initializes CAPI + Talos providers.

Requirements: docker, kind, clusterctl, talosctl, kubectl, flux
USAGE
}

PROVIDER=""
CLUSTER_NAME="mgmt"
GIT_URL=""
BRANCH="main"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) PROVIDER="$2"; shift 2 ;;
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
  # alias commonly used by users; keep backward compatible
  --name) CLUSTER_NAME="$2"; shift 2 ;;
    --git-url) GIT_URL="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$PROVIDER" ]]; then
  echo "--provider is required" >&2
  usage
  exit 1
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need docker
need kind
need clusterctl
need talosctl
need kubectl
need flux

# 1) Create ephemeral kind cluster
if ! kubectl config get-clusters | grep -q "kind-bootstrap"; then
  echo "[1/5] Creating ephemeral kind cluster..."
  kind create cluster --name bootstrap
else
  echo "[1/5] kind-bootstrap already exists; continuing"
fi

# 2) clusterctl init
echo "[2/5] Initializing Cluster API providers (incl. Talos) on kind-bootstrap..."
TMP_KUBECONFIG=$(mktemp)
kind get kubeconfig --name bootstrap >"${TMP_KUBECONFIG}"
KUBECONFIG="${TMP_KUBECONFIG}" clusterctl init \
  --infrastructure "${PROVIDER}" \
  --bootstrap talos \
  --control-plane talos

# Apply Proxmox credentials early if provided
if [[ "$PROVIDER" == "proxmox" ]]; then
  if [[ -f platform/capi/proxmox/manifests/secret-capmox.yaml ]]; then
    echo "Applying Proxmox credentials Secret to cluster (preflight)..."
    KUBECONFIG="${TMP_KUBECONFIG}" kubectl apply -f platform/capi/proxmox/manifests/secret-capmox.yaml || true
  fi
fi

# 3) Provision management cluster (Talos) - wait for providers then apply manifests
echo "[3/5] Waiting for CAPI providers to be ready..."
if [[ "$PROVIDER" == "proxmox" ]]; then
  # Wait for controller-manager Deployments to be Available; use broad waits to avoid name typos across versions
  KUBECONFIG="${TMP_KUBECONFIG}" kubectl -n capi-system wait deploy --all --for=condition=Available --timeout=300s || true
  # Talos providers (bootstrap/control-plane) use these namespaces upstream
  KUBECONFIG="${TMP_KUBECONFIG}" kubectl -n capi-bootstrap-talos-system wait deploy --all --for=condition=Available --timeout=300s || true
  KUBECONFIG="${TMP_KUBECONFIG}" kubectl -n capi-control-plane-talos-system wait deploy --all --for=condition=Available --timeout=300s || true
  # Proxmox provider
  KUBECONFIG="${TMP_KUBECONFIG}" kubectl -n capmox-system wait deploy --all --for=condition=Available --timeout=300s || true
  sleep 5
  echo "[3/5] Applying management cluster manifests (with retry)..."
  apply_ok=false
  for i in {1..5}; do
    if KUBECONFIG="${TMP_KUBECONFIG}" kubectl apply -k platform/capi/proxmox/manifests; then
      apply_ok=true; break
    else
      echo "Apply failed (attempt $i). Waiting for webhooks and retrying..."
      sleep 10
    fi
  done
  if [[ "$apply_ok" != true ]]; then
    echo "Failed to apply Proxmox manifests after retries." >&2
    exit 1
  fi
else
  echo "Provider '$PROVIDER' not yet wired; add manifests under platform/capi/ and apply them here."
fi

# 4) Move CAPI objects to the new mgmt cluster
echo "[4/5] Moving CAPI objects to management cluster (placeholder)..."
# clusterctl move --to-kubeconfig <mgmt-kubeconfig>

echo "NOTE: Wire clusterctl move once mgmt cluster is reachable."

# 5) Flux bootstrap pointing to this repo
if [[ -n "$GIT_URL" ]]; then
  echo "[5/5] Bootstrapping Flux from $GIT_URL ($BRANCH)..."
  KUBECONFIG="${TMP_KUBECONFIG}" flux bootstrap git \
    --url="$GIT_URL" \
    --branch="$BRANCH" \
    --path="/" \
    --silent
else
  echo "[5/5] Skipping Flux bootstrap (no --git-url provided)."
fi

rm -f "${TMP_KUBECONFIG}"

echo "Bootstrap scaffold complete. Fill in platform/capi and run again."
