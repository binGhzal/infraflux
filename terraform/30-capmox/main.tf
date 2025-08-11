# Apply CAPMOX-specific CRDs and ProxmoxCluster Secret if needed via kubernetes_manifest

# Example: render ProxmoxCluster and Secret from a template with inputs
# locals {
#   proxmoxcluster_yaml = templatefile("${path.module}/templates/proxmoxcluster.yaml.tftpl", {
#     name = "capmox"
#   })
# }
