# Cilium module

Installs Cilium with KPR strict, socket LB, LB-IPAM, L2 Announcements, WireGuard, Hubble, Gateway API.

Inputs:

- namespace (default kube-system)
- lb_pool_start (default 10.0.15.100)
- lb_pool_stop (default 10.0.15.250)
- version (chart)

Resources:

- helm_release.cilium
- kubernetes_manifest.lb_pool (CiliumLoadBalancerIPPool)
- kubernetes_manifest.l2_policy (CiliumL2AnnouncementPolicy)
