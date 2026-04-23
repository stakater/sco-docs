# Postgres Cluster (Infrastructure)

Low-level infrastructure API for provisioning a PostgreSQL cluster via CloudNativePG with explicit control over instances, storage, PostgreSQL version, resource sizing, and optional external exposure.

!!! note
    This is a private infrastructure API intended for platform engineers. Cloud users should use the [Postgres](../public-apis/postgres.md) public API instead.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `infrastructure.stakater.com` |
| **Version** | `v1` |
| **Kind** | `XPostgresCluster` |
| **Scope** | Cluster-scoped |
| **Claim Kind** | `PostgresCluster` |

## Spec Parameters

All parameters are nested under `spec.parameters`.

### Required

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `namespace` | `string` | `postgres` | Namespace where the CloudNativePG `Cluster` will be created. |

### Sizing

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `instances` | `integer` | `1` | Number of PostgreSQL instances (replicas) |
| `postgresVersion` | `string` | `16` | PostgreSQL major version (used to select the CNPG image) |

### Storage

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `storage.size` | `string` | `10Gi` | PVC size for each PostgreSQL instance |
| `storage.storageClass` | `string` | `ocs-storagecluster-ceph-rbd` | StorageClass to use for PostgreSQL PVCs |

### Resources

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `resources.requests.cpu` | `string` | `500m` | CPU request per Postgres pod |
| `resources.requests.memory` | `string` | `512Mi` | Memory request per Postgres pod |
| `resources.limits.cpu` | `string` | `2000m` | CPU limit per Postgres pod |
| `resources.limits.memory` | `string` | `2Gi` | Memory limit per Postgres pod |

### Networking and provider config

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `exposeLoadBalancer` | `boolean` | `false` | When `true`, ask CloudNativePG to provision an additional LoadBalancer Service targeting the primary (rw) instance, so the database is reachable outside the cluster. Default is `false` (private, in-cluster only). |
| `kubernetesProviderConfigName` | `string` | `kubernetes-provider` | Name of the Kubernetes provider config to use. |

### Top-level fields

| Field | Type | Description |
|-------|------|-------------|
| `managementPolicies` | `string[]` | Crossplane management policy. Defaults to `["*"]`. |
| `providerConfigRef.name` | `string` | Reference to a provider configuration. |

## Status Fields

`status.connection` carries non-sensitive endpoint metadata only. Credentials live in the CloudNativePG-managed `<cluster-name>-app` Secret in the target namespace; they are surfaced to cloud-tier consumers via api-syncagent related resources on the cloud-tier `PublishedResource` — not here.

| Field | Type | Description |
|-------|------|-------------|
| `status.connection.host` | `string` | PostgreSQL read-write service hostname (FQDN) |
| `status.connection.port` | `string` | PostgreSQL service port |
| `status.connection.database` | `string` | Database name |
| `status.connection.externalHost` | `string` | Externally-reachable hostname or IP of the LoadBalancer Service. Populated only when `parameters.exposeLoadBalancer` is `true`. |

## Examples

### Minimal (single-instance, private)

```yaml
apiVersion: infrastructure.stakater.com/v1
kind: XPostgresCluster
metadata:
  name: my-postgres
spec:
  parameters:
    namespace: postgres
```

### HA with larger storage and external exposure

```yaml
apiVersion: infrastructure.stakater.com/v1
kind: XPostgresCluster
metadata:
  name: app-postgres
spec:
  parameters:
    namespace: postgres
    instances: 3
    postgresVersion: "16"
    storage:
      size: 100Gi
      storageClass: ocs-storagecluster-ceph-rbd
    resources:
      requests:
        cpu: 1000m
        memory: 2Gi
      limits:
        cpu: 4000m
        memory: 8Gi
    exposeLoadBalancer: true
```
