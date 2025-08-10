# GCP Provider Overlay

Defaults for GCP (CAPG) used by the InfraFlux renderer.

Values in `values.example.yaml` are merged with CLI flags during `infraflux up`:

- clusterName, namespace, region
- k8sMinor, talosVersion
- controlPlane.replicas, controlPlane.instanceType
- workers.replicas, workers.instanceType

Kinds used during rendering:

- INFRA_CLUSTER_KIND = GCPCluster
- INFRA_MACHINE_TEMPLATE_KIND = GCPMachineTemplate
