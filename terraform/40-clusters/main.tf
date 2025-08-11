# Define Cluster, TalosControlPlane, MachineDeployment, ProxmoxMachineTemplate and MachineHealthCheck using kubernetes_manifest.

# Example: cluster manifests rendered from templates using templatefile()+yamldecode()
# locals {
#   cluster_yaml = templatefile("${path.module}/templates/cluster.yaml.tftpl", {
#     name         = var.cluster_name
#     cp_replicas  = var.cp_replicas
#     md_replicas  = var.md_replicas
#   })
# }
