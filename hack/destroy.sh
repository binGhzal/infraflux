#!/usr/bin/env bash
set -Eeuo pipefail

# InfraFlux destroy helper: tears down mgmt/workload clusters via CAPI then removes bootstrap kind.

usage() {
  cat <<'USAGE'
Usage: hack/destroy.sh [--keep-kind]
USAGE
}

KEEP_KIND=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-kind) KEEP_KIND=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need clusterctl
need kubectl
need kind

# Placeholder: delete mgmt/workload clusters using CAPI manifests
# kubectl delete -f clusters/dev --ignore-not-found
# kubectl delete -f platform/capi --ignore-not-found

echo "Deleting bootstrap kind cluster (if present)..."
if kind get clusters | grep -q "bootstrap"; then
  if [[ $KEEP_KIND -eq 0 ]]; then
    kind delete cluster --name bootstrap
  else
    echo "--keep-kind set; skipping kind deletion"
  fi
else
  echo "No kind cluster named 'bootstrap' found"
fi

echo "Destroy scaffold complete."
