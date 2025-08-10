# CLI Reference (`infraflux`)

The CLI renders plans/manifests and orchestrates composition. **It does not apply to live clusters.**

## Commands

### `infraflux init`

Bootstrap artifacts for the **management cluster**:

- Renders/prints steps for `clusterctl init` with selected providers.
- Renders Flux bootstrap pointing to this repo.

#### `init` Flags

- `--git-repo` (required): Git URL for Flux bootstrap.
- `--providers`: comma-separated (default: aws,azure,gcp,proxmox).
- `--namespace`: management namespace (default: `infraflux-system`).

### `infraflux up`

Render a **workload cluster** plan (CAPI + Talos) and the post-creation app setup.

#### `up` Flags

- `--provider`: `aws|azure|gcp|proxmox`
- `--name`: cluster name
- `--region`: cloud region (if applicable)
- `--workers`, `--cpu`, `--memory`, `--k8s`

### `infraflux destroy`

Render a deletion plan for a named cluster.

#### Common flags

- `--dry-run`: render only, no side effects
- `-c, --config`: optional config file for defaults

> The agent will implement file outputs to `./out/<cluster>/` so CI can apply plans safely.
