# InfraFlux - RKE2 Kubernetes Cluster Automation

InfraFlux provides a complete automation solution for deploying production-ready, highly available RKE2 Kubernetes clusters on Proxmox using Infrastructure as Code principles.

## 🚀 Features

- **🏗️ Automated Infrastructure**: Terraform provisions VMs on Proxmox
- **⚙️ Cluster Deployment**: Ansible installs and configures RKE2
- **🔄 High Availability**: 3-node control plane with etcd clustering
- **⚖️ Load Balancing**: Kube-VIP for API server, Cilium BGP for services
- **🎯 One-Command Deployment**: Simple script-based deployment
- **✅ Validation Tools**: Built-in cluster validation and health checks
- **🔐 Production Security**: FIPS 140-2 and CIS Kubernetes Benchmark compliance

## 🏛️ Architecture

### Infrastructure Components

- **Control Plane (3 Servers)**: RKE2 server nodes for HA control plane (VM IDs: 500-502)
- **Worker Nodes (2+ Agents)**: RKE2 agent nodes for workload execution (VM IDs: 550+)
- **Virtual IP**: Kube-VIP provides floating IP for API server access
- **Load Balancer**: Cilium BGP manages LoadBalancer service IPs
- **Network**: Static IP configuration with VLAN support
- **Storage**: Configurable disk allocation per node

### Solution Layers

- **Infrastructure Layer**: Proxmox VMs managed by Terraform
- **Kubernetes Layer**: RKE2 cluster managed by Ansible
- **Network Layer**: Kube-VIP for control plane HA, Cilium CNI with BGP for LoadBalancer services
- **Management Layer**: Deployment and validation scripts

## 🏃‍♂️ Quick Start

### Prerequisites

- Proxmox VE 8.x with API access
- Ubuntu cloud image template with cloud-init support
- Terraform >= 1.0 and Ansible >= 2.9
- SSH key pair for VM access

### Deploy in 3 Steps

1. **Configure**:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your environment details
   ```

2. **Deploy**:

   ```bash
   ./deploy.sh deploy
   ```

3. **Access**:
   ```bash
   export KUBECONFIG=$(pwd)/kubeconfig
   kubectl get nodes
   ```

## 🛠️ Deployment Commands

| Command                | Description                             |
| ---------------------- | --------------------------------------- |
| `./deploy.sh deploy`   | Full deployment (infrastructure + RKE2) |
| `./deploy.sh infra`    | Deploy only infrastructure              |
| `./deploy.sh rke2`     | Deploy only RKE2 cluster                |
| `./deploy.sh validate` | Validate cluster deployment             |
| `./deploy.sh status`   | Show cluster information                |
| `./deploy.sh destroy`  | Destroy all infrastructure              |

### Advanced Options

```bash
# Automated deployment (skip confirmations)
./deploy.sh deploy --auto-approve

# Show what would be done without executing
./deploy.sh deploy --dry-run

# Run individual modular scripts
./scripts/check-prerequisites.sh
./scripts/deploy-infrastructure.sh
./scripts/setup-ansible.sh
./scripts/deploy-rke2.sh
./scripts/generate-kubeconfig.sh
./scripts/validate-cluster.sh
./scripts/show-cluster-info.sh
./scripts/destroy-infrastructure.sh
```

### Configuration Files

| File | Purpose |
|------|---------|
| `terraform.tfvars` | Infrastructure configuration |
| `config/deploy.conf` | Deployment behavior settings |
| `config/deploy.conf.example` | Configuration template |

## ⚙️ Configuration

### Key Configuration Options (terraform.tfvars)

```hcl
# Proxmox Connection
proxmox_api_url = "https://proxmox.example.com:8006/api2/json"
proxmox_node = "proxmox-node1"
proxmox_api_token_id = "root@pam!terraform"
proxmox_api_token_secret = "your-secret-token"

# Cluster Configuration
rke2_servers = {
  count       = 3
  vm_id_start = 500
  ip_start    = "192.168.3.21"
  cpu_cores   = 2
  memory      = 4096
  disk_size   = 50
}

rke2_agents = {
  count       = 2
  vm_id_start = 550
  ip_start    = "192.168.3.24"
  cpu_cores   = 2
  memory      = 4096
  disk_size   = 50
}

# Network & RKE2 Settings
network_config = {
  bridge      = "vmbr0"
  subnet      = "192.168.3.0/24"
  gateway     = "192.168.3.1"
}

rke2_config = {
  vip              = "192.168.3.50"     # Cluster API VIP
  lb_range         = "192.168.3.80-192.168.3.90"  # MetalLB range
  rke2_version     = "v1.29.4+rke2r1"
  kube_vip_version = "v0.8.0"
}

# External Access (for GitOps tools and remote kubectl)
external_endpoint = "203.0.113.10"  # Your public IP or FQDN
```

## 🌐 External Access Configuration

InfraFlux now supports external access for GitOps tools and remote kubectl usage. This fixes the common issue where kubeconfig files only work from within the internal network.

### Configuring External Access

1. **Set External Endpoint**: Add your public IP or FQDN to `terraform.tfvars`:
   ```hcl
   external_endpoint = "203.0.113.10"  # Your public IP
   # or
   external_endpoint = "k8s.yourdomain.com"  # Your FQDN
   ```

2. **Network Requirements**:
   - External firewall must allow port 6443 to your Proxmox network
   - Port forwarding or NAT rules should forward external:6443 → VIP:6443
   - Example: External IP:6443 → 192.168.3.50:6443

3. **SSL Certificate Considerations**:
   - RKE2 generates certificates with internal IPs by default
   - For FQDN access, consider adding certificate SANs
   - Or use `--insecure-skip-tls-verify` for testing

### Deployment Modes

| Mode | Configuration | Use Case |
|------|---------------|----------|
| **Internal Only** | `external_endpoint = ""` | Local network access only |
| **External Access** | `external_endpoint = "1.2.3.4"` | GitOps tools, remote kubectl |
| **FQDN Access** | `external_endpoint = "k8s.example.com"` | Production with proper DNS |

### Generated Kubeconfig Behavior

- **Internal Only**: Kubeconfig uses VIP (`192.168.3.50:6443`)
- **External Configured**: Kubeconfig uses external endpoint for remote access
- **Automatic Selection**: Scripts automatically choose the appropriate endpoint

### GitOps Integration

With external access configured, you can now use GitOps tools:

```bash
# ArgoCD installation
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# FluxCD installation  
curl -s https://fluxcd.io/install.sh | sudo bash
flux bootstrap github --owner=yourusername --repository=fleet-infra
```

### Troubleshooting External Access

1. **Connection Refused**: Check firewall and port forwarding
2. **Certificate Issues**: Use `--insecure-skip-tls-verify` for testing
3. **DNS Resolution**: Verify FQDN resolves to correct IP
4. **Network Path**: Ensure external traffic can reach internal VIP

## 🎯 Why RKE2?

RKE2 (Rancher Kubernetes Engine 2) is ideal for production workloads:

- **🔒 Security**: FIPS 140-2 compliance and CIS Kubernetes Benchmark compliance
- **🔄 High Availability**: Built-in HA support with etcd clustering
- **🏭 Production Ready**: Designed for enterprise and government workloads
- **📋 Compliance**: Better suited for regulated environments
- **💪 Stability**: More stable and feature-complete than K3s
- **🐳 Container Runtime**: Uses containerd by default

## 📋 Prerequisites & Setup

### System Requirements

1. **Proxmox Environment**:

   - Proxmox VE 8.x with API access
   - VM template with cloud-init support (Ubuntu 22.04+ recommended)
   - Network bridge configuration
   - Sufficient resources for cluster nodes

2. **Local Tools**:
   - Terraform >= 1.0
   - Ansible >= 2.9
   - SSH key pair for VM access

### Create Ubuntu Cloud Image Template

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

### Install Ansible Collections

```bash
cd ansible/RKE2
ansible-galaxy collection install -r collections/requirements.yaml
```

## 🚀 Deployment Process

### Automated Deployment

The Ansible playbook performs these tasks automatically:

1. **Prepare all nodes**: System updates, kernel parameters, IP forwarding
2. **Download RKE2**: Install RKE2 binaries on all nodes
3. **Deploy Kube-VIP**: Configure virtual IP for HA API endpoint
4. **Bootstrap first server**: Initialize the cluster and generate join token
5. **Add additional servers**: Join remaining servers to form HA control plane
6. **Add agents**: Join worker nodes to the cluster
7. **Apply manifests**: Deploy MetalLB for LoadBalancer services

### Manual Step-by-Step (Alternative)

1. **Initialize Infrastructure**:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

2. **Deploy RKE2 Cluster**:
   ```bash
   cd ansible/RKE2
   ansible-playbook -i inventory/hosts.ini site.yaml
   ```

## 🔍 Cluster Access & Operations

### Access the Cluster

After successful deployment:

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

### Cluster Endpoints

- **API Server**: `https://<vip>:6443`
- **LoadBalancer Services**: IPs from MetalLB range
- **Kubeconfig**: Available at `/etc/rancher/rke2/rke2.yaml` or `~/.kube/config`

### Verify Cluster Components

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

# Verify Cilium BGP
kubectl get pods -n kube-system | grep cilium
```

## ⚡ Scaling & Customization

### Adding More Nodes

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
terraform apply
cd ansible/RKE2
ansible-playbook -i inventory/hosts.ini site.yaml
```

### Custom RKE2 Configuration

Customize RKE2 settings by editing:

- `ansible/RKE2/inventory/group_vars/all.yaml`
- Individual role defaults in `ansible/RKE2/roles/*/defaults/main.yaml`

Common customizations:

- RKE2 version
- CNI plugin selection
- Node taints and labels
- Resource reservations

## 🔧 Troubleshooting

### Common Issues & Solutions

1. **VMs fail to start**:

   - Check template exists and has correct permissions
   - Verify Proxmox API credentials

2. **Network connectivity**:

   - Verify IP ranges don't conflict
   - Check firewall rules

3. **RKE2 installation fails**:

   - Check internet connectivity and DNS resolution
   - Verify system resources

4. **Cluster join fails**:

   - Verify firewall rules and token validity
   - Check system clock synchronization

5. **Kubeconfig authentication issues**:
   - Run validation tools to check kubeconfig generation
   - Verify certificate authority data

### Validation Tools

The project includes several validation tools:

```bash
# Full cluster validation
./deploy.sh validate

# Basic cluster connectivity test
./test-cluster.sh

# Cluster validation via SSH
./cluster-validate.sh
```

### Log Locations & Debugging

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

**Log Locations**:

- RKE2 Server logs: `/var/lib/rancher/rke2/server/logs/`
- RKE2 Agent logs: `/var/lib/rancher/rke2/agent/logs/`
- Containerd logs: `journalctl -u containerd`
- Kubelet logs: `journalctl -u kubelet`

## 🔐 Security & Best Practices

### Security Features

- **Node-to-node encryption**: All communication encrypted with TLS
- **RBAC**: Role-based access control enabled by default
- **Network Policies**: Supported through CNI
- **Pod Security Standards**: Configurable security policies
- **Secure token handling**: Automatic token generation and secure sharing

### High Availability Features

- **Multiple Control Plane**: 3 server nodes for API server redundancy
- **etcd Clustering**: Distributed etcd for data redundancy
- **Kube-VIP**: Virtual IP failover for API endpoint
- **Load Balancing**: MetalLB for service load balancing

### Maintenance & Backup

**Backup**:

- **etcd**: Automatic snapshots are configured by RKE2
- **Configuration**: Backup `terraform.tfvars` and any custom Ansible files

**Updates**:

- **OS Updates**: Use Ansible to manage OS updates across nodes
- **RKE2 Updates**: Follow RKE2 upgrade documentation
- **Application Updates**: Use standard Kubernetes deployment practices

## ✅ Known Issues Fixed

### Major Fixes Implemented

1. **Installation Method**: Replaced manual binary download with official RKE2 installer script
2. **Dynamic Server References**: Updated templates to use dynamic group references instead of hard-coded names
3. **Service Configuration**: Enhanced systemd service files with proper restart policies and resource limits
4. **Token Security**: Implemented secure token sharing using Ansible facts
5. **Directory Permissions**: Fixed incorrect directory permissions (0644 → 0755)
6. **Kubeconfig Authentication**: Complete rewrite with template-based generation ensuring consistent naming
7. **MetalLB Configuration**: Updated to current version with proper L2Advertisement configuration
8. **Node Preparation**: Added essential system configuration for Kubernetes
9. **Cluster Validation**: Added comprehensive validation logic

### Authentication & Access Improvements

- Fixed certificate authority data mismatch
- Changed cluster name from "default" to "infraflux-rke2"
- Changed user name from "default" to "infraflux-admin"
- Added backup functionality for existing kubeconfig files
- VIP access now working correctly with proper certificates

## 🧹 Clean Up

To destroy the infrastructure:

```bash
./deploy.sh destroy
# or manually:
terraform destroy
```

This will remove all VMs and associated resources from Proxmox.

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- RKE2 team at Rancher for the excellent Kubernetes distribution
- Proxmox team for the robust virtualization platform
- Ansible community for automation tools
- Terraform team for infrastructure as code capabilities
