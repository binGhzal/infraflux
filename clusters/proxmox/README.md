# Proxmox provider overlay

This directory contains Proxmox-specific defaults used by `infraflux up` when rendering a cluster plan.

## values.example.yaml

The `values.example.yaml` file defines baseline settings:

- `clusterName`: name of the workload cluster.
- `namespace`: namespace for Cluster API resources.
- `region`: logical datacenter or region name.
- `k8sMinor`: Kubernetes minor version to deploy.
- `talosVersion`: Talos Linux release for nodes.
- `controlPlane.replicas`: number of control plane machines.
- `controlPlane.instanceType`: Proxmox template or hardware ID for control plane nodes.
- `workers.replicas`: number of worker machines.
- `workers.instanceType`: Proxmox template or hardware ID for worker nodes.

All values may be overridden with CLI flags when executing `infraflux up`.
