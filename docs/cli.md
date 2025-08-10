# CLI Reference (`infraflux`)

The CLI renders plans/manifests and orchestrates composition. By default it does not apply to live clusters.

## Commands

### `infraflux init`

Bootstrap artifacts for the management cluster.

- Use `management/bootstrap.sh` for a simple bootstrap flow.
- This command prints next steps with required tools.

#### `init` Flags

- `--git-repo` (required): Git URL for Flux bootstrap.
- `--providers`: comma-separated (default: aws,azure,gcp,proxmox).
- `--namespace`: management namespace (default: `infraflux-system`).

### `infraflux up`

Render a workload cluster plan (CAPI + Talos) and the post-creation app setup.

#### `up` Flags

- `--provider`: `aws|azure|gcp|proxmox`
- `--name`: cluster name
- `--region`: cloud region (if applicable)
- `--workers`, `--cpu`, `--memory`, `--k8s`

### `infraflux apply`

Apply rendered manifests to the current kube context from `out/<name>/`.

#### `apply` Flags

- `--name` (required): cluster name
- `--sections`: subset of `cluster,addons,recipes` (default: all)

### `infraflux talos-gen`

Generate sample Talos configs (or write guidance if `talosctl` is not installed).

#### `talos-gen` Flags

- `--name`: Talos cluster name (default: `infraflux-mgmt`)
- `--endpoint`: Cluster endpoint URL (default: `https://127.0.0.1:6443`)

### `infraflux destroy`

Render a deletion plan for a named cluster.

### `infraflux version`

Print CLI version.

#### Common flags

- `--dry-run`: render only, no side effects
- `-c, --config`: optional config file for defaults

> Outputs are written under `./out/<cluster>/` so that humans/CI can apply plans safely.
