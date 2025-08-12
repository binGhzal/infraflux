# Cluster Templates

This directory contains ClusterClass definitions for standardized cluster provisioning via Cluster API.

## Available Templates

### Small Cluster (`talos-proxmox-small`)

- **Control Plane**: 1 node, 2 CPU, 2GB RAM, 20GB disk
- **Workers**: 2 nodes (default), 2 CPU, 2GB RAM, 20GB disk
- **Use Case**: Development, testing, lightweight workloads

### Medium Cluster (`talos-proxmox-medium`)

- **Control Plane**: 3 nodes (HA), 4 CPU, 4GB RAM, 40GB disk
- **Workers**: 3 nodes (default), 4 CPU, 4GB RAM, 40GB disk
- **Use Case**: Staging, medium production workloads

### Large Cluster (`talos-proxmox-large`)

- **Control Plane**: 3 nodes (HA), 8 CPU, 8GB RAM, 80GB disk
- **Workers**: 5 nodes (default), 8 CPU, 8GB RAM, 80GB disk
- **Use Case**: Production workloads, high availability

## Usage

1. **Deploy ClusterClass templates** (one-time setup):

```bash
kubectl apply -f clusters/templates/
```

2. **Create a cluster using a template**:

```yaml
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: my-production-cluster
  namespace: default
spec:
  topology:
    class: talos-proxmox-medium
    version: v1.29.0
    variables:
      - name: cluster_name
        value: "my-production-cluster"
      - name: cluster_endpoint
        value: "10.0.1.100"
      - name: proxmox_node
        value: "pve01"
      - name: worker_count
        value: 5
    controlPlane:
      replicas: 3
    workers:
      machineDeployments:
        - class: worker-medium
          name: worker-pool-1
          replicas: 5
```

3. **Apply the cluster**:

```bash
kubectl apply -f my-cluster.yaml
```

## Customization

You can override default values by specifying variables in your cluster definition:

- `cluster_name`: Name of the cluster
- `cluster_endpoint`: IP address for the cluster API server
- `proxmox_node`: Proxmox node where VMs will be created
- `worker_count`: Number of worker nodes

## Prerequisites

- Cluster API and CAPMox provider installed
- Talos template (ID 9100) available in Proxmox
- Network bridge `vmbr0` configured
- Sufficient resources on target Proxmox node
