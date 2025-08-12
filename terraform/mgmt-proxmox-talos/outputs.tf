output "kubeconfig_host" {
  value = talos_cluster_kubeconfig.kube.kubeconfig[0].host
}
