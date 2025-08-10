# Providers – Common Prerequisites

All providers share a few concepts:

- **Credentials**: store them as SOPS-encrypted Secrets; reference them from provider configs or kube-controllers that need them.
- **Networks**: either provision via Crossplane/OpenTofu/Pulumi or use existing; CAPI will need subnet/SG info depending on provider.
- **Images**: for Talos nodes, use official cloud images or build/import images appropriate to each provider (Proxmox needs a VM template).

> The management cluster itself can be anywhere (cloud or Proxmox). It hosts Flux and CAPI providers to create workload clusters elsewhere.
