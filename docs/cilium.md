# Cilium deployment (Terraform Helm)

Config installs:

- KPR strict + socket LB
- LB IPAM pool 10.0.15.100–10.0.15.250
- L2 Announcements for LoadBalancer services
- WireGuard encryption, Hubble + UI
- Gateway API implementation

Verification checklist:

- Cilium DaemonSet Ready on all nodes
- Hubble UI accessible (ClusterIP/PortForward initially)
- Creating a LoadBalancer Service gets an IP from 10.0.15.100–.250
- L2 ARP is visible on the LAN for the assigned IP

Notes:

- Providers use `var.kubeconfig` path; ensure it points to Talos output after bootstrap.
