# FAQ

**Q: Why Talos instead of Ubuntu + Ansible?**
A: Immutable API-driven nodes avoid drift and reduce bootstrap flakiness, enabling truly “push-button” flows.

**Q: Can I use Argo CD instead of Flux?**
A: Yes—InfraFlux ships Flux by default. You can add Argo as a recipe or swap if your org standardizes on Argo.

**Q: Do I need Crossplane?**
A: No. It’s optional, but ideal if you want cloud resources (DBs, buckets, DNS) to be managed in the same GitOps loop.

**Q: How do I change storage from Longhorn to a cloud CSI?**
A: Replace `recipes/base/storage-longhorn-helmrelease.yaml` with your provider CSI and update the Kustomization.
