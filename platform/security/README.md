# Platform: Security

RBAC, NetworkPolicies, Gatekeeper/Kyverno baselines, and runtime security (Tetragon/Falco) live here.

- Start with deny-by-default and required labels/owners policies.

## Supply chain: image verification

Use Kyverno verifyImages to enforce signed images. Start in Audit, then Enforce.

- Keys: Prefer keyless (Fulcio + Rekor) or pinned public keys via a ConfigMap/Secret.
- Scope: Begin with platform namespaces; expand to apps when registries are compliant.
- Mutation: Use mutate policies to pin images to digests at admission for reproducibility.

Rollout steps:

1. Install Kyverno and Kyverno policies CRDs before application CRDs (Flux dependsOn/healthChecks).
2. Create a `ClusterPolicy` verifyImages rule targeting selected namespaces and registries.
3. Store Cosign roots (if using key-based) as a ConfigMap/Secret mounted in Kyverno.
4. Set `validationFailureAction: Audit` and monitor violations; fix unsigned images.
5. Toggle to `Enforce` once green. Consider per-namespace exceptions via `PolicyException`.

References:

- <https://kyverno.io/policies/> (verifyImages examples)
- <https://docs.sigstore.dev/cosign/overview/> (Cosign signing and verification)

## Baseline policy set

Recommended starting policies (tune per environment):

- Disallow latest tag; require image digest
- Require approved registries
- Require namespace labels (owner, env, tier)
- Disallow privileged/hostPath/cap-add; restrict hostNetwork
- Require readOnlyRootFilesystem and drop ALL capabilities by default
- Enforce resource requests/limits
- Require probes for Deployments
- Default deny NetworkPolicy per-namespace with explicit allows

## Runtime security

- Tetragon for eBPF-based runtime policy/observability (Cilium ecosystem)
- Falco as an alternative if preferred

## Secrets management

- Bootstrap secrets: SOPS or Sealed Secrets (Flux has first-class SOPS support)
- Runtime secrets: External Secrets Operator (ESO) reading from a cloud KMS/manager
- Avoid long-lived plaintext secrets in Git; prefer dynamic rotation and short TTLs
