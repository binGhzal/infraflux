# InfraFlux - RKE2 Kubernetes Cluster Automation

This project provides a complete automation solution for deploying highly available RKE2 Kubernetes clusters on Proxmox using Infrastructure as Code principles.

## Features

- **Automated Infrastructure**: Terraform provisions VMs on Proxmox
- **Cluster Deployment**: Ansible installs and configures RKE2
- **High Availability**: 3-node control plane with etcd clustering
- **Load Balancing**: Kube-VIP for API server, MetalLB for services
- **One-Command Deployment**: Simple script-based deployment
- **Validation Tools**: Built-in cluster validation and health checks

## Architecture

The solution consists of:

- **Infrastructure Layer**: Proxmox VMs managed by Terraform
- **Kubernetes Layer**: RKE2 cluster managed by Ansible
- **Network Layer**: Kube-VIP for control plane HA, MetalLB for LoadBalancer services
- **Management Layer**: Deployment and validation scripts

## Quick Start

1. **Prerequisites**:

   - Proxmox VE with API access
   - VM template with cloud-init support
   - Local tools: Terraform, Ansible, SSH keys

2. **Configuration**:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your environment details
   ```

3. **Deploy**:

   ```bash
   ./deploy.sh deploy
   ```

4. **Validate**:
   ```bash
   ./deploy.sh validate
   ```

## Deployment Commands

- `./deploy.sh deploy` - Full deployment (infrastructure + RKE2)
- `./deploy.sh infra` - Deploy only infrastructure
- `./deploy.sh rke2` - Deploy only RKE2 cluster
- `./deploy.sh validate` - Validate cluster deployment
- `./deploy.sh status` - Show cluster information
- `./deploy.sh destroy` - Destroy all infrastructure

## Configuration

See `terraform.tfvars.example` for all configuration options including:

- Proxmox connection details
- VM specifications (CPU, memory, disk)
- Network configuration
- RKE2 cluster settings
- Kube-VIP and MetalLB configuration

## Architecture

The infrastructure consists of:

- **RKE2 Server Nodes**: 3 control plane nodes (default VM IDs: 500-502) for high availability
- **RKE2 Agent Nodes**: 2 worker nodes (default VM IDs: 550-551) for workload execution
- **Kube-VIP**: Provides virtual IP for cluster API endpoint high availability
- **MetalLB**: Bare-metal load balancer for service LoadBalancer type
- All nodes are created from an Ubuntu cloud image template
- Nodes are configured with static IP addresses
- All VMs are placed in a dedicated Proxmox resource pool named "rke2"

## Why RKE2?

RKE2 (Rancher Kubernetes Engine 2) offers several advantages for production workloads:

- **Security**: FIPS 140-2 compliance and CIS Kubernetes Benchmark compliance
- **High Availability**: Built-in HA support with etcd clustering
- **Production Ready**: Designed for enterprise and government workloads
- **Compliance**: Better suited for regulated environments
- **Stability**: More stable and feature-complete than K3s
- **Container Runtime**: Uses containerd by default

## Prerequisites

1. Proxmox VE server (tested with version 8.x)
2. SSH key pair for VM access
3. Ubuntu cloud image template in Proxmox (Ubuntu 20.04+ recommended)
4. Terraform installed locally (version 1.0+)
5. Proxmox API token with appropriate permissions
6. Ansible installed locally with required collections

## Quick Start

1. Clone this repository:

   ```bash
   git clone <repository-url>
   cd infraflux
   ```

2. Copy `terraform.tfvars.example` to `terraform.tfvars`:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit `terraform.tfvars` with your specific configuration:

   - Proxmox API credentials and node
   - Network settings (IPs, gateway, subnet)
   - SSH public key
   - VM resource allocations
   - RKE2 cluster configuration

4. Initialize and apply Terraform:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

5. Deploy RKE2 cluster using Ansible:
   ```bash
   cd ansible/RKE2
   ansible-playbook -i inventory/hosts.ini site.yaml
   ```

## Detailed Setup Instructions

### 1. Install Ansible Collections

Install the required Ansible collections:

```bash
cd ansible/RKE2
ansible-galaxy collection install -r collections/requirements.yaml
```

### 2. Create Ubuntu Cloud Image Template

First, create the Ubuntu cloud image template in Proxmox:

```bash
# Download Ubuntu Cloud Image (Ubuntu 22.04 LTS recommended)
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Install libguestfs-tools if not already installed
apt-get install -y libguestfs-tools

# Create VM template (ID 9000)
qm create 9000 --name ubuntu-cloud-init-template --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --agent 1
qm template 9000
```

### 3. Configure Terraform Variables

Edit `terraform.tfvars` with your specific settings. Key variables to configure:

- **Proxmox Connection**: API URL, node name, and credentials
- **Network Settings**: Ensure IP ranges don't conflict with existing infrastructure
- **RKE2 VIP**: Choose an unused IP for the cluster API endpoint
- **MetalLB Range**: Choose IP range for LoadBalancer services

### 4. Deploy Infrastructure

Run Terraform to create the VM infrastructure:

```bash
terraform init
terraform plan
terraform apply
```

This will:

- Create RKE2 server and agent VMs
- Configure static IP addresses
- Generate Ansible inventory automatically
- Set up VM templates with cloud-init

### 5. Deploy RKE2 Cluster

The Ansible playbook will automatically configure the entire RKE2 cluster:

```bash
cd ansible/RKE2
ansible-playbook -i inventory/hosts.ini site.yaml
```

The playbook performs these tasks:

1. **Prepare all nodes**: System updates, kernel parameters, IP forwarding
2. **Download RKE2**: Install RKE2 binaries on all nodes
3. **Deploy Kube-VIP**: Configure virtual IP for HA API endpoint
4. **Bootstrap first server**: Initialize the cluster and generate join token
5. **Add additional servers**: Join remaining servers to form HA control plane
6. **Add agents**: Join worker nodes to the cluster
7. **Apply manifests**: Deploy MetalLB for LoadBalancer services

## Cluster Operations

After successful deployment:

### 1. Access the Cluster

The kubeconfig file will be available on the first server node:

```bash
# SSH to first server
ssh ansible@<server1-ip>

# Copy kubeconfig
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

# Test cluster access
kubectl get nodes
kubectl get pods -A
```

### 2. Verify Cluster Components

Check that all components are running:

```bash
# Check node status
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Check RKE2 services
systemctl status rke2-server  # On server nodes
systemctl status rke2-agent   # On agent nodes

# Verify Kube-VIP
kubectl get pods -n kube-system | grep kube-vip

# Verify MetalLB
kubectl get pods -n metallb-system
```

terraform plan
terraform apply

````

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
````

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

### 3. Configuration Details

#### Network Configuration

The cluster uses the following network configuration:

- **Cluster Network**: Defined by `network_config.subnet`
- **Virtual IP (VIP)**: High availability endpoint for the Kubernetes API
- **MetalLB Range**: IP pool for LoadBalancer services
- **VLAN Support**: Optional VLAN tagging for network isolation

#### Security Features

- **Node-to-node encryption**: All communication encrypted with TLS
- **RBAC**: Role-based access control enabled by default
- **Network Policies**: Supported through CNI
- **Pod Security Standards**: Configurable security policies

#### High Availability

- **Multiple Control Plane**: 3 server nodes for API server redundancy
- **etcd Clustering**: Distributed etcd for data redundancy
- **Kube-VIP**: Virtual IP failover for API endpoint
- **Load Balancing**: MetalLB for service load balancing

## Customization

### Scaling the Cluster

To add more nodes, update the `terraform.tfvars` file:

```hcl
# Add more servers
rke2_servers = {
  count = 5  # Increase from 3 to 5
  # ... other settings
}

# Add more agents
rke2_agents = {
  count = 4  # Increase from 2 to 4
  # ... other settings
}
```

Then run:

```bash
terraform plan
terraform apply
cd ansible/RKE2
ansible-playbook -i inventory/hosts.ini site.yaml
```

### Custom RKE2 Configuration

To customize RKE2 settings, edit the role variables in:

- `ansible/RKE2/inventory/group_vars/all.yaml`
- Individual role defaults in `ansible/RKE2/roles/*/defaults/main.yaml`

Common customizations:

- RKE2 version
- CNI plugin selection
- Node taints and labels
- Resource reservations

## Troubleshooting

### Common Issues

1. **VMs fail to start**: Check template exists and has correct permissions
2. **Network connectivity**: Verify IP ranges don't conflict
3. **RKE2 installation fails**: Check internet connectivity and DNS resolution
4. **Cluster join fails**: Verify firewall rules and token validity

### Useful Commands

```bash
# Check RKE2 server logs
sudo journalctl -u rke2-server -f

# Check RKE2 agent logs
sudo journalctl -u rke2-agent -f

# Restart RKE2 services
sudo systemctl restart rke2-server  # On servers
sudo systemctl restart rke2-agent   # On agents

# Check cluster status
kubectl get nodes
kubectl get pods -A
kubectl top nodes
```

### Log Locations

- RKE2 Server logs: `/var/lib/rancher/rke2/server/logs/`
- Containerd logs: `journalctl -u containerd`
- Kubelet logs: `journalctl -u kubelet`

## Clean Up

To destroy the infrastructure:

```bash
terraform destroy
```

This will remove all VMs and associated resources from Proxmox.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- RKE2 team at Rancher for the excellent Kubernetes distribution
- Proxmox team for the robust virtualization platform
- Ansible community for automation tools
- Terraform team for infrastructure as code capabilities
