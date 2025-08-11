# Ansible: Proxmox Ubuntu VMs + kubeadm

This playbook provisions Ubuntu cloud-init VMs on Proxmox and bootstraps a Kubernetes cluster via kubeadm.

## Prereqs
- Ansible 9+ and Python 3 on control host (your Mac).
- Install collections:

```sh
ansible-galaxy collection install -r collections/requirements.yml
```

- Proxmox API creds in group_vars (vault recommended):
  - `vault_proxmox_host_password` or `proxmox_host_password`
- Inventory in `hosts.binghzal` updated with your hostnames and IPs.

## Run

```sh
ANSIBLE_INVENTORY=hosts.binghzal ansible-playbook -i hosts.binghzal deploy.yml
```

## Notes
- Uses `community.general.proxmox_kvm` to clone from a cloud-init Ubuntu template.
- Cloud-init user is `ci_user` (default `ubuntu`). SSH keys from `ci_ssh_authorized_keys`.
- kubeadm control-plane is initialized on the first host in `k8s_masters`.
