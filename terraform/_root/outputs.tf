output "summary" {
  value = {
    mgmt_kubeconfig = module.mgmt_talos.mgmt_kubeconfig
  }
}
