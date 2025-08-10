# Troubleshooting

## Flux not reconciling

- Check `kubectl -n flux-system get kustomizations,helmreleases,gitrepositories,helmrepositories`.
- Describe failing resources (`kubectl describe ...`) to see fetch/apply errors.

## Recipes fail due to missing catalogs

- Ensure `management/flux/kustomization.yaml` includes all HelmRepository sources you need.

## Secrets missing

- Validate SOPS decryption in your apply context.
- Confirm `.sops.yaml` matches your encrypted filenames/paths.

## Cluster API components not installed

- Re-export `gotk-components.yaml` after `flux install` and commit.
- Confirm `clusterctl init` providers match your intended targets.
