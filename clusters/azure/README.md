# Azure Provider Overlay

Defaults for Azure (CAPZ) used by the InfraFlux renderer.

Values in `values.example.yaml` are merged with CLI flags during `infraflux up`:

- clusterName, namespace, region
- k8sMinor, talosVersion
- controlPlane.replicas, controlPlane.instanceType
- workers.replicas, workers.instanceType

Kinds set by this overlay during rendering:

- INFRA_CLUSTER_KIND = AzureCluster
- INFRA_MACHINE_TEMPLATE_KIND = AzureMachineTemplate

Note: Region is passed through for consistency; CAPZ will use location fields in real templates.
