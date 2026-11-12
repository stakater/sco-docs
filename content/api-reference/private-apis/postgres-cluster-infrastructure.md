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
| `exposeLoadBalancer` | `boolean` | `false` | When `true`, ask CloudNativePG to provision an additional LoadBalancer Service targeting the primary (read-write) instance, so the database is reachable outside the cluster. Default is `false` (private, in-cluster only). |
| `kubernetesProviderConfigName` | `string` | `kubernetes-provider` | Name of the Kubernetes provider config to use. |

### Credential delivery

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `credentialsStore.providerConfigName` | `string` | — | Name of the per-tenant `vault.upbound.io` ProviderConfig pointing at the target OpenBao (created by `openbao-infrastructure`, `<tenant>-bao`). Set by the cloud tier; leave the whole block unset to skip credential delivery (infra-only use). |
| `credentialsStore.mount` | `string` | `services` | kv-v2 mount to write into. |
| `credentialsStore.path` | `string` | — | Full secret path within the mount, e.g. `<project>/postgres/<claim-name>`. |

### Backup

Continuous WAL archiving plus scheduled base backups to an existing S3 or S3-compatible bucket, through the CloudNativePG Barman Cloud plugin (`cloudnative-postgres-operator` 0.0.14 or later). The composition creates an `XPostgresBackup` (the plugin's `ObjectStore` and the access-key Secret), adds the plugin to the `Cluster`, and creates a daily `ScheduledBackup` that also runs once immediately. Switching backups on or off restarts the database instances once.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `backup.enabled` | `boolean` | `false` | Back the database up. |
| `backup.bucket` | `string` | — | Existing bucket. Not created or emptied. Required when `enabled` is `true`. |
| `backup.path` | `string` | bucket root | Prefix inside the bucket, without leading or trailing slashes. Barman adds a directory named after the cluster below it. |
| `backup.endpointURL` | `string` | Amazon S3 | HTTPS endpoint of an S3-compatible service. |
| `backup.region` | `string` | — | Region requests are signed for. Omit to let the client resolve it. |
| `backup.endpointCA` | `boolean` | `false` | Verify `endpointURL` against the PEM certificate under `ca.crt` in the credentials. |
| `backup.schedule` | `string` | `0 0 2 * * *` | Base backup schedule, six-field cron in UTC with seconds first. |
| `backup.retentionPolicy` | `string` | `7d` | Recovery window: a number followed by `d`, `w` or `m`. |
| `backup.credentials.openbao.key` | `string` | — | Path of the entry read through External Secrets. |
| `backup.credentials.openbao.secretStore.{kind,name}` | `string` | `ClusterSecretStore` / `stakater-cluster-secret-store` | Store that resolves `key`. |
| `backup.credentials.secretRef.{name,namespace}` | `string` | — | Existing Secret copied into the database namespace. Takes precedence over `openbao`. |

When `enabled` is `true`, `bucket` and one of `credentials.openbao` or `credentials.secretRef` are required. The credentials hold `ACCESS_KEY_ID` and `ACCESS_SECRET_KEY`, plus `ca.crt` when `endpointCA` is `true`.

The cloud tier ([Postgres](../public-apis/postgres.md)) confines `openbao.key` to the project's folder of the organisation's OpenBao (`projects/<organisation>-<project>/<secretPath>` in the `<organisation>-bao` store) and `secretRef` to the database's own namespace.

### Top-level fields

| Field | Type | Description |
|-------|------|-------------|
| `managementPolicies` | `string[]` | Crossplane management policy. Defaults to `["*"]`. |
| `providerConfigRef.name` | `string` | Reference to a provider configuration. |

## Status Fields

`status.connection` carries non-sensitive endpoint metadata only. Credentials live in the CloudNativePG-managed `<cluster-name>-app` Secret in the target namespace; the composition writes them into the tenant's OpenBao (kv-v2 `SecretV2` via the `credentialsStore` parameters) for cloud-tier consumers — not here.

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

### Backed up to an S3-compatible bucket

```yaml
apiVersion: infrastructure.stakater.com/v1
kind: XPostgresCluster
metadata:
  name: app-postgres
spec:
  parameters:
    namespace: postgres
    backup:
      enabled: true
      bucket: platform-backups
      path: postgres
      endpointURL: https://s3.example.com
      credentials:
        openbao:
          key: postgres-backup/s3
```
