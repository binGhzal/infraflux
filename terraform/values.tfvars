# location of talos iso file
talos_iso_file = "backups:iso/talos-nocloud-amd64.iso"

# talos control nodes configuration
talos_control_configuration = [
  {
    pm_node   = "pve1"
    vmid      = 1110
    vm_name   = "talos-control-1"
    cpu_cores = 2
    memory    = 4096
    disk_size = "50G"
    networks = [
      {
        id      = 0
        macaddr = "BC:24:13:5F:39:D1"
        tag     = 70
      }
    ]
  },
  {
    pm_node   = "pve2"
    vmid      = 2110
    vm_name   = "talos-control-2"
    cpu_cores = 2
    memory    = 4096
    disk_size = "50G"
    networks = [
      {
        id      = 0
        macaddr = "BC:24:13:5F:39:D2"
        tag     = 70
      }
    ]
  },
  {
    pm_node   = "pve3"
    vmid      = 3110
    vm_name   = "talos-control-3"
    cpu_cores = 2
    memory    = 4096
    disk_size = "50G"
    networks = [
      {
        id      = 0
        macaddr = "BC:24:13:5F:39:D3"
        tag     = 70
      }
    ]
  }
]


# talos worker nodes configuration
talos_worker_configuration = [
  {
    pm_node   = "pve1"
    vmid      = 1111
    vm_name   = "talos-worker-1"
    cpu_cores = 6
    memory    = 16384
    disk_size = "30G"
    networks = [
      {
        id      = 0
        macaddr = "BC:24:13:5F:39:D4"
        tag     = 70
      }
    ]
  },
  {
    pm_node   = "pve2"
    vmid      = 2111
    vm_name   = "talos-worker-2"
    cpu_cores = 6
    memory    = 16384
    disk_size = "50G"
    networks = [
      {
        id      = 0
        macaddr = "BC:24:13:5F:39:D5"
        tag     = 70
      }
    ]
  },
  {
    pm_node   = "pve3"
    vmid      = 3111
    vm_name   = "talos-worker-3"
    cpu_cores = 12
    memory    = 16384
    disk_size = "100G"
    networks = [
      {
        id      = 0
        macaddr = "BC:24:13:5F:39:D6"
        tag     = 70
      }
    ]
  }
]
