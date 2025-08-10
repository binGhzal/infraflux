This folder is intended for Cilium policy/infra CRDs applied post-install via the same
Kustomization.

- CiliumBGPClusterConfig / CiliumBGPPeerConfig (BGP Control Plane)
- CiliumEgressGatewayPolicy (egress IP policies)

Note: Ensure CRDs are present before applying these resources. The Kustomization for apps/cilium
will wait on cilium DS and hubble-ui deployments; if needed, split into a second Kustomization with
`dependsOn`.
