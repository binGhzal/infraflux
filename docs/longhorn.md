# Longhorn (Step 10)

This document covers installing Longhorn via Argo CD and required Talos prerequisites.

## Prerequisites

- Talos image includes system extensions:
  - siderolabs/iscsi-tools (for iscsiadm and iscsid)
  - siderolabs/util-linux-tools
- Worker nodes have an additional data disk (e.g., 200 GiB) attached for Longhorn.
- Cilium is installed and stable; kube-proxy is disabled (KPR strict).

## Installation (GitOps)

- Argo CD Application `longhorn` is defined in `old/gitops/apps/longhorn/helm-release.yaml`.
  - Uses official chart `longhorn` from `https://charts.longhorn.io`.
  - Sync options include `CreateNamespace=true`.
  - Sync wave is set to 2 to follow CRDs/controllers and secrets consumers.

### Chart values

- `defaultSettings.defaultReplicaCount: 2` (adjust based on node count).
- `defaultSettings.defaultDataPath: /var/lib/longhorn`
- `persistence.defaultClass: true` and `persistence.defaultClassReplicaCount: 2`

## Post-install validation

- Ensure all pods in `longhorn-system` are Ready.
- Verify the default StorageClass exists:
  - `kubectl get sc` should show `longhorn` marked as `(default)`.
- Create a test PVC/Pod and confirm volume attach/mount.

## Troubleshooting

- If volumes fail to attach:
  - Check that `iscsiadm` and `iscsid` are present on nodes (Talos extension enabled).
  - Ensure worker data disks are visible and not mounted elsewhere.
  - Inspect `longhorn-manager` and `instance-manager` pod logs.
