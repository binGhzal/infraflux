# Proxmox foundation

Terraform module `terraform/00-proxmox-foundation` prepares Proxmox for Talos clusters.

## Responsibilities

- Configure the Proxmox provider using API token credentials.
- Surface datastore and network bridge names for later modules.
- Optionally upload a Talos image and convert it to a VM template.

## Talos image upload

The Telmate Proxmox provider cannot upload images directly. If a Talos template is missing, upload one manually:

```bash
# download a Talos image
talos_version=v1.6.4
curl -L -o talos.qcow2 \
  "https://github.com/siderolabs/talos/releases/download/${talos_version}/talos-generic-amd64.qcow2"

# create a template (example ID 9000)
qm create 9000 --name talos-template \
  --net0 virtio,bridge=vmbr0 \
  --scsi0 local-lvm:0,import-from=talos.qcow2 --ostype l26
qm template 9000
```

Adjust datastore, bridge and IDs to your environment, then set `talos_template` accordingly.

## Usage

```bash
cd terraform/00-proxmox-foundation
tofu init
tofu plan \
  -var='pm_api_url=https://proxmox.example:8006/api2/json' \
  -var='pm_api_token_id=root@pam!token' \
  -var='pm_api_token_secret=REDACTED' \
  -var='pm_tls_insecure=true' \
  -var='datastore=local-lvm' \
  -var='bridge=vmbr0' \
  -var='talos_template=talos-template'
```

Outputs:

- `talos_template`
- `datastore`
- `bridge`
