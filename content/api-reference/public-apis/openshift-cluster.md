# OpenShift Cluster

Provisions a managed OpenShift hosted cluster with configurable compute and node pool settings.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `kubernetes.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `OpenShiftCluster` |
| **Scope** | Namespace-scoped |

## Spec Parameters

All parameters are nested under `spec.parameters`.

### Required

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `clusterName` | `string` | 1–63 characters | Name of the OpenShift cluster |
| `compute.cpu` | `integer` | 1–8 | Number of CPU cores per node |
| `compute.memory` | `string` | e.g., `8Gi` | Memory per node |

### Optional

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `version` | `string` | `4.19` | OpenShift version. Allowed: `4.18`, `4.19`, `4.20` |
| `storage.rootVolumeSize` | `string` | `10Gi` | Root volume size per node (e.g., `120Gi`) |
| `nodePool.replicas` | `integer` | `3` | Number of nodes in the pool (1–10) |
| `nodePool.labels` | `object` | — | Custom key/value labels to apply to nodes |

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.clusterReady` | `boolean` | Whether the cluster is fully ready |
| `status.controlPlaneReady` | `boolean` | Whether the control plane is ready |
| `status.nodePoolReady` | `boolean` | Whether the node pool is ready |
| `status.conditions` | `array` | Standard Kubernetes conditions |

## Examples

### Minimal

```yaml
apiVersion: kubernetes.cloud.stakater.com/v1
kind: OpenShiftCluster
metadata:
  name: my-cluster
spec:
  parameters:
    clusterName: my-cluster
    compute:
      cpu: 2
      memory: "8Gi"
```

### Full

```yaml
apiVersion: kubernetes.cloud.stakater.com/v1
kind: OpenShiftCluster
metadata:
  name: prod-cluster
spec:
  parameters:
    clusterName: prod-cluster
    version: "4.19"
    compute:
      cpu: 4
      memory: "16Gi"
    storage:
      rootVolumeSize: "120Gi"
    nodePool:
      replicas: 3
      labels:
        environment: production
        team: platform
```

## How-to Guide

[Provision an OpenShift Cluster](../../how-to-guides/user/provision-openshift-cluster.md)
