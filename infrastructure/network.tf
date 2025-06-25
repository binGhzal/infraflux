# TODO: InfraFlux Refactoring Tasks
# - [ ] Consider adding firewall rules for Cilium ports
# - [ ] Add validation for BGP configuration
# - [ ] Consider adding network monitoring resources

# Network configuration outputs for reference
output "network_config" {
  description = "Network configuration details"
  value = {
    bridge      = var.network_config.bridge
    subnet      = var.network_config.subnet
    gateway     = var.network_config.gateway
    vlan_id     = var.network_config.vlan_id
    vip         = var.rke2_config.vip
    lb_range    = var.rke2_config.lb_range
  }
}

# Cilium network requirements
output "cilium_ports" {
  description = "Required ports for Cilium operation"
  value = {
    health_checks    = 4240
    hubble_server    = 4244
    hubble_relay     = 4245
    bgp              = 179
    wireguard        = 51871
    vxlan            = 8472
    geneve           = 6081
  }
}

# BGP configuration for network team
output "bgp_config" {
  description = "BGP configuration for network infrastructure"
  value = {
    local_asn    = var.cilium_config.bgp_asn
    peer_asn     = var.cilium_config.bgp_peer_asn
    peer_address = var.network_config.gateway
    lb_ip_range  = var.cilium_config.lb_ip_range
  }
}