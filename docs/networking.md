# Networking (Cilium & Gateway)

## Cilium

InfraFlux installs **Cilium** via Helm (Flux `HelmRelease`) with **kube-proxy replacement** enabled:

- Lower latency/CPU vs iptables-based kube-proxy.
- eBPF-powered services, network policies, and Hubble observability (optional).

Edit/overlay values in `clusters/cilium/helmrelease.yaml` as needed:

- `k8sServiceHost` / `k8sServicePort` for API server (optional, Talos often sets these).
- Enable Hubble UI by adding values and a HelmRelease for it.

## Gateway API + Envoy Gateway

We ship a `HelmRelease` for Envoy Gateway under `clusters/gateway/`.
Use **HTTPRoute/TLSRoute/GRPCRoute** for modern, portable L7 ingress.

If you need NGINX, add a `HelmRelease` using the `ingress-nginx` catalog instead.
