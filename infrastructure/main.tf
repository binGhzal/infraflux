# TODO: InfraFlux Refactoring Tasks
# - [x] Moved terraform and provider blocks to versions.tf
# - [x] Added external_endpoint variable to templatefile for ansible_group_vars
# - [ ] Consider breaking this file into modules (network, compute, templates)
# - [ ] Consider adding validation for IP ranges and network configurations

# Provider configuration moved to providers.tf

# Resource pool for our RKE2 cluster
resource "proxmox_virtual_environment_pool" "rke2_pool" {
  comment = "RKE2 cluster resources"
  pool_id = "rke2"
}

# RKE2 Server nodes (Control Plane)
resource "proxmox_virtual_environment_vm" "rke2_server" {
  count     = var.rke2_servers.count
  name      = "server${count.index + 1}"
  node_name = var.proxmox_node
  pool_id   = proxmox_virtual_environment_pool.rke2_pool.pool_id
  vm_id     = var.rke2_servers.vm_id_start + count.index
  started   = true

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores = var.rke2_servers.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.rke2_servers.memory
  }

  network_device {
    bridge  = var.network_config.bridge
    model   = "virtio"
    vlan_id = var.network_config.vlan_id
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.rke2_servers.disk_size
    interface    = "scsi0"
    file_format  = "raw"
  }

  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = "${join(".", [
          split(".", var.rke2_servers.ip_start)[0],
          split(".", var.rke2_servers.ip_start)[1],
          split(".", var.rke2_servers.ip_start)[2],
          tostring(tonumber(split(".", var.rke2_servers.ip_start)[3]) + count.index)
        ])}/${var.network_config.subnet_mask}"
        gateway = var.network_config.gateway
      }
    }

    user_account {
      keys     = [var.ssh_public_key]
      username = var.vm_username
    }
  }

  tags = ["rke2", "server", "kubernetes"]
}

# RKE2 Agent nodes (Worker Nodes)
resource "proxmox_virtual_environment_vm" "rke2_agent" {
  count     = var.rke2_agents.count
  name      = "agent${count.index + 1}"
  node_name = var.proxmox_node
  pool_id   = proxmox_virtual_environment_pool.rke2_pool.pool_id
  vm_id     = var.rke2_agents.vm_id_start + count.index

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores = var.rke2_agents.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.rke2_agents.memory
  }

  network_device {
    bridge  = var.network_config.bridge
    model   = "virtio"
    vlan_id = var.network_config.vlan_id
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.rke2_agents.disk_size
    interface    = "scsi0"
    file_format  = "raw"
  }

  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = "${join(".", [
          split(".", var.rke2_agents.ip_start)[0],
          split(".", var.rke2_agents.ip_start)[1],
          split(".", var.rke2_agents.ip_start)[2],
          tostring(tonumber(split(".", var.rke2_agents.ip_start)[3]) + count.index)
        ])}/${var.network_config.subnet_mask}"
        gateway = var.network_config.gateway
      }
    }

    user_account {
      keys     = [var.ssh_public_key]
      username = var.vm_username
    }
  }

  tags = ["rke2", "agent", "kubernetes"]
}

# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../configuration/inventory/hosts.ini"
  content = templatefile("${path.module}/templates/ansible_inventory.tpl", {
    servers = [for i, server in proxmox_virtual_environment_vm.rke2_server : {
      name = server.name
      ip   = split("/", server.initialization[0].ip_config[0].ipv4[0].address)[0]
    }]
    agents = [for i, agent in proxmox_virtual_environment_vm.rke2_agent : {
      name = agent.name
      ip   = split("/", agent.initialization[0].ip_config[0].ipv4[0].address)[0]
    }]
    ansible_user         = var.vm_username
    ssh_private_key_file = var.ssh_private_key_file
  })

  depends_on = [
    proxmox_virtual_environment_vm.rke2_server,
    proxmox_virtual_environment_vm.rke2_agent
  ]
}

# Generate Ansible group variables
resource "local_file" "ansible_group_vars" {
  filename = "${path.module}/../configuration/inventory/group_vars/all.yaml"
  content = templatefile("${path.module}/templates/ansible_group_vars.tpl", {
    os                = var.rke2_config.os
    arch              = var.rke2_config.arch
    ansible_user      = var.vm_username
    vip               = var.rke2_config.vip
    vip_interface     = var.rke2_config.vip_interface
    external_endpoint = var.external_endpoint
    metallb_version   = var.rke2_config.metallb_version
    lb_range          = var.rke2_config.lb_range
    lb_pool_name      = var.rke2_config.lb_pool_name
    rke2_version      = var.rke2_config.rke2_version
    kube_vip_version  = var.rke2_config.kube_vip_version
    cilium_config     = var.cilium_config
  })

  depends_on = [
    proxmox_virtual_environment_vm.rke2_server,
    proxmox_virtual_environment_vm.rke2_agent
  ]
}

# Generate Ansible configuration file
resource "local_file" "ansible_config" {
  filename = "${path.module}/../configuration/ansible.cfg"
  content = templatefile("${path.module}/templates/ansible_config.tpl", {
    ansible_user         = var.vm_username
    ssh_private_key_file = var.ssh_private_key_file
  })

  depends_on = [
    proxmox_virtual_environment_vm.rke2_server,
    proxmox_virtual_environment_vm.rke2_agent
  ]
}

# Outputs
output "rke2_server_ips" {
  description = "IP addresses of RKE2 server nodes"
  value = [for server in proxmox_virtual_environment_vm.rke2_server :
    split("/", server.initialization[0].ip_config[0].ipv4[0].address)[0]
  ]
}

output "rke2_agent_ips" {
  description = "IP addresses of RKE2 agent nodes"
  value = [for agent in proxmox_virtual_environment_vm.rke2_agent :
    split("/", agent.initialization[0].ip_config[0].ipv4[0].address)[0]
  ]
}

output "rke2_cluster_endpoint" {
  description = "RKE2 cluster endpoint (VIP)"
  value       = var.rke2_config.vip
}

output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}

output "cilium_lb_ip_range" {
  description = "Cilium BGP LoadBalancer IP range for services"
  value       = var.cilium_config.lb_ip_range
}

output "ansible_config_path" {
  description = "Path to generated Ansible configuration file"
  value       = local_file.ansible_config.filename
}

output "cilium_bgp_asn" {
  description = "Cilium BGP ASN for cluster"
  value       = var.cilium_config.bgp_asn
}

output "external_endpoint" {
  description = "External endpoint for cluster access"
  value       = var.external_endpoint != "" ? var.external_endpoint : var.rke2_config.vip
}