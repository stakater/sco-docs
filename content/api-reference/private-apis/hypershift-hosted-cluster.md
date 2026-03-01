# HyperShift Hosted Cluster

Low-level infrastructure API for provisioning a HyperShift hosted OpenShift cluster with full control over etcd backup, provider configuration, ingress, DNS, and certificates.

!!! note
    This is a private infrastructure API intended for platform engineers. Cloud users should use the [OpenShift Cluster](../public-apis/openshift-cluster.md) public API instead.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `infrastructure.stakater.com` |
| **Version** | `v1` |
| **Kind** | `HyperShiftHostedCluster` |
| **Scope** | Cluster |

## Spec Parameters

All parameters are nested under `spec.parameters`.

### Required

| Field | Type | Description |
|-------|------|-------------|
| `etcdBackupBucket.name` | `string` | Name of the AWS S3 bucket for etcd backups |

### Optional — Cluster

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `hostedCluster.name` | `string` | — | Name of the HostedCluster resource |
| `hostedCluster.namespace` | `string` | — | Namespace for the HostedCluster resource |
| `image` | `string` | `quay.io/openshift-release-dev/ocp-release:4.14.7-x86_64` | OpenShift release image |
| `controllerAvailabilityPolicy` | `string` | `HighlyAvailable` | Control plane availability policy |
| `replicas` | `integer` | `3` | Number of worker nodes |
| `owner` | `string` | `stakater` | Owner identifier |
| `platform` | `object` | — | Platform-specific configuration (free-form) |
| `ingressController` | `object` | — | Ingress controller configuration (free-form) |
| `dns` | `object` | — | DNS configuration (free-form) |
| `certificate` | `object` | — | Certificate configuration (free-form) |

### Optional — Provider Config

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `kubernetesProviderConfigName` | `string` | `kubernetes-provider` | Crossplane Kubernetes provider config name |
| `awsProviderConfigName` | `string` | `stakater-aws` | Crossplane AWS provider config name |
| `vaultProviderConfigName` | `string` | `provider-vault` | Crossplane Vault provider config name |
| `vaultMountEngine` | `string` | `stakater` | Vault mount engine path |

### Optional — etcd Backup Bucket

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `etcdBackupBucket.region` | `string` | `eu-north-1` | AWS region for the S3 bucket |
| `etcdBackupBucket.crossplaneNamespace` | `string` | `stakater-crossplane` | Namespace where Crossplane runs |
| `etcdBackupBucket.deletionPolicy` | `string` | `Orphan` | Deletion policy for the S3 bucket resource |
| `etcdBackupBucket.schedule` | `string[]` | `["daily", "weekly"]` | Backup schedule intervals |
| `etcdBackupBucket.forceDestroy` | `boolean` | `true` | Allow deletion of non-empty bucket |
| `etcdBackupBucket.etcdBackupJobImage` | `string` | `ghcr.io/stakater/saap-catalog/images/hosted-cluster-etcd-backup:0.0.1` | Image for the etcd backup job |

## Status Fields

The `status` field is free-form (`x-kubernetes-preserve-unknown-fields: true`). Check the resource directly for current conditions.

## Examples

### Minimal

```yaml
apiVersion: infrastructure.stakater.com/v1
kind: HyperShiftHostedCluster
metadata:
  name: my-cluster
spec:
  parameters:
    hostedCluster:
      name: my-cluster
      namespace: my-cluster-ns
    etcdBackupBucket:
      name: my-cluster-etcd-backup
```

### Full

```yaml
apiVersion: infrastructure.stakater.com/v1
kind: HyperShiftHostedCluster
metadata:
  name: prod-cluster
spec:
  parameters:
    kubernetesProviderConfigName: kubernetes-provider
    awsProviderConfigName: stakater-aws
    vaultProviderConfigName: provider-vault
    vaultMountEngine: stakater
    hostedCluster:
      name: prod-cluster
      namespace: prod-cluster-ns
    etcdBackupBucket:
      name: prod-cluster-etcd-backup
      region: eu-north-1
      crossplaneNamespace: stakater-crossplane
      deletionPolicy: Orphan
      schedule:
        - daily
        - weekly
      forceDestroy: true
      etcdBackupJobImage: ghcr.io/stakater/saap-catalog/images/hosted-cluster-etcd-backup:0.0.1
    image: quay.io/openshift-release-dev/ocp-release:4.15.0-x86_64
    controllerAvailabilityPolicy: HighlyAvailable
    replicas: 3
```
