# AWS Provider Overlay

This directory contains AWS-specific defaults for the InfraFlux renderer.

`values.example.yaml` provides baseline values consumed by `infraflux up`:

- `clusterName`
- `namespace`
- `region`
- `k8sMinor`
- `talosVersion`
- `controlPlane.replicas`
- `controlPlane.instanceType`
- `workers.replicas`
- `workers.instanceType`

These settings are merged with command line flags during rendering.
