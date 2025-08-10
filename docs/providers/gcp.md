# GCP (CAPG)

## Credentials

- A service account JSON key with roles for Compute, Networking, and optionally Cloud DNS.
- Encrypt with SOPS; mount or reference in CAPG controller.

## Networking

- Use a custom VPC with subnets and firewall rules or rely on defaults with tight security overlays.

## Overlays

- `clusters/gcp/` mirrors others:
  - region/zone (e.g., `europe-west1-b`)
  - machine type (`e2-standard-2`, etc.)
  - replicas and versions

## Notes

- For managed storage, use GCE PD CSI; otherwise Longhorn is cloud-agnostic.
