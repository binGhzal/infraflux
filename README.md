# Terraform Proxmox Ansible RKE2

This repository contains Terraform config to automatically provision a production-ready Kubernetes cluster using RKE2 on Proxmox VE. It creates a high-availability cluster with multiple master nodes and worker nodes, all running Ubuntu Server.

My primary goal is reproducability. I try to achieve this by:

- Infrastructure as Code (IaC) using Terraform to create and manage VMs in Proxmox
- Configuration management with Ansible to consistently deploy and configure RKE2 across nodes

## Architecture

The infrastructure consists of:

- 3 RKE2 master nodes (VM IDs: 200, 201, 202) for high availability
- 3 RKE2 worker nodes (VM IDs: 203, 204, 205)
- All nodes are created from an Ubuntu cloud image template
- Nodes are configured with static IP addresses
- All VMs are placed in a dedicated Proxmox resource pool named "rke2"

## Why RKE2 over K3s?

RKE2 (Rancher Kubernetes Engine 2) offers several advantages over K3s for production workloads:

- **Security**: FIPS 140-2 compliance and enhanced security features
- **High Availability**: Built-in HA support with multiple master nodes
- **Production Ready**: Designed for enterprise and government workloads
- **Compliance**: Better suited for regulated environments
- **Stability**: More stable and feature-complete than K3s

## Prerequisites

1. Proxmox VE server (tested with version 8.x)
2. SSH key pair for VM access
3. Ubuntu cloud image template in Proxmox
4. Terraform installed locally
5. Proxmox API token with appropriate permissions
6. Ansible installed locally (for k3s setup)

## Quick Start

1. Clone this repository
2. Copy `terraform.tfvars.example` to `terraform.tfvars`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
3. Edit `terraform.tfvars` with your specific configuration:

   - Proxmox API credentials
   - Network settings
   - SSH public key
   - VM resource allocations

4. Initialize and apply Terraform:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

5. Set up RKE2 using Ansible:

   ```bash
   cd ansible
   ansible-playbook -i hosts setup-rke2.yml
   ```

## Detailed Setup Instructions

### 1. Create Ubuntu Cloud Image Template

First, create the Ubuntu cloud image template in Proxmox:

```bash
# Download Ubuntu Cloud Image
wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img

# Install libguestfs-tools
apt-get install -y libguestfs-tools

# Create VM template (ID 9000)
qm create 9000 --name ubuntu-cloud-init-template --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 focal-server-cloudimg-amd64.img local-zfs
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-zfs:vm-9000-disk-0
qm set 9000 --ide2 local-zfs:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --agent 1
qm template 9000
```

### 2. Configure Terraform Variables

Edit `terraform.tfvars` with your specific settings

### 3. Deploy Infrastructure

Run Terraform to create the infrastructure:

```bash
terraform init
terraform plan
terraform apply
```

### 4. Configure Ansible

The Ansible playbooks are located in the `ansible` directory. The setup process is automated and will:

1. Configure all nodes with:

   - System updates
   - Required packages
   - Disabled swap
   - Required kernel modules and parameters

2. Set up the first master node with:

   - RKE2 server installation
   - Cluster initialization
   - Token generation
   - Kubeconfig setup

3. Configure additional master nodes with:

   - RKE2 server installation
   - Cluster joining using token
   - High availability setup

4. Configure worker nodes with:

   - RKE2 agent installation
   - Cluster joining as workers

To run the setup:

```bash
cd ansible
ansible-playbook -i hosts setup-rke2.yml
```

The playbook will automatically:

- Use the correct IP addresses from your Terraform configuration
- Generate and save the kubeconfig files locally (single and HA versions)
- Configure all necessary system requirements
- Set up the complete RKE2 cluster with high availability

## Post-Deployment

After the infrastructure and RKE2 are set up:

1. Access the cluster:

   ```bash
   # The kubeconfig files will be automatically saved in the ansible directory
   export KUBECONFIG=./ansible/rke2.yaml
   kubectl get nodes

   # For HA access (recommended for production)
   export KUBECONFIG=./ansible/rke2-ha.yaml
   kubectl get nodes
   ```

2. Verify the cluster:

   ```bash
   kubectl get nodes
   kubectl get pods -A
   kubectl cluster-info
   ```
