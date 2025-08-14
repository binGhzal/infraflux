# talos-cluster Terraform module

Generates Talos machine configs, disables kube-proxy, sets VIP and KubePrism, applies configs to nodes, bootstraps the cluster, and exports kubeconfig.

Inputs

- cluster_name (string)
- cluster_vip (string)
- controlplane_ips (list(string))
- worker_ips (list(string))
- talos_version (string, optional)
- install_disk (string, default "/dev/sda")

Outputs

- kubeconfig (sensitive)
- talos_client_configuration (sensitive)

Notes

- Requires nodes to be reachable on the management network and Talos API ports.
- VIP becomes active only after etcd is bootstrapped; do not use VIP for bootstrap step itself.
- KubePrism is enabled at port 7445.
