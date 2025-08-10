# Management Cluster (Talos)

This directory holds **sample** Talos machine and cluster configs for the **management cluster**.

- Real configs should be generated with `talosctl gen config` and stored securely (or transiently).
- The coding agent should not commit real secrets; keep placeholders or SOPS-encrypted files.
