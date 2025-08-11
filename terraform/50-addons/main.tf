# Option A: Helm install Cilium to workload cluster using helm_release with values/cilium-full.yaml
# Option B: Create ClusterResourceSet to auto-apply Cilium across clusters.

# Example: render CRS from template with configmap references
# locals {
#   crs_yaml = templatefile("${path.module}/templates/crs-cilium.yaml.tftpl", {
#     name = "cilium-crs"
#   })
# }
