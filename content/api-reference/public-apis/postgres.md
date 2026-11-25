# Postgres

Provisions a PostgreSQL database.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `database.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `Postgres` |
| **Scope** | Namespace-scoped |

## Spec Parameters

All parameters are nested under `spec.parameters`.

### Optional

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `instances` | `integer` | `1` | Number of PostgreSQL instances (replicas) |
| `plan` | `string` | — | Size of each instance (CPU and memory), one of the sizes your platform offers, for example `o1.small`. Empty keeps the default size. See [Sizes](../../how-to-guides/user/create-postgres.md#sizes). |
| `storage.size` | `string` | `10Gi` | Disk size per PostgreSQL instance |
| `meshAccess.groups` | `array` | — | Organisation groups whose members may reach the database over your organisation's [Mesh](./mesh.md) on port `5432`. Once `meshAccess` is set, project members with database access are included automatically. Leave `meshAccess` out for no mesh access. |
| `exposeLoadBalancer` | `boolean` | `false` | When `true`, the platform creates an external endpoint for the database and reports it in `status.connection.externalHost`. Whether that endpoint is reachable from the internet depends on your cloud's network perimeter; on Stakater's production cloud it is not, because the perimeter does not admit port `5432` (see [Test from Your Workstation](../../how-to-guides/user/create-postgres.md#test-from-your-workstation)). When `false`, the database is reachable only from inside the project. |

## Status Fields

`status.connection` carries non-sensitive endpoint metadata. Credentials (username, password, URI) are **not** placed in the status — they are stored in your organisation's Vault, and `status.credentials` says where (see [Credentials](#credentials)).

| Field | Type | Description |
|-------|------|-------------|
| `status.connection.host` | `string` | PostgreSQL read-write service name (`<name>-rw`). The full name to connect to is `<name>-rw.<organisation>-<project>-databases.svc.cluster.local`. |
| `status.connection.port` | `string` | PostgreSQL service port (typically `5432`) |
| `status.connection.database` | `string` | Database name |
| `status.plan.message` | `string` | Set when the chosen size cannot be applied, with the reason |
| `status.connection.externalHost` | `string` | Externally-reachable hostname or IP of the database. Populated only when `parameters.exposeLoadBalancer` is `true`. |
| `status.credentials.delivered` | `boolean` | `true` once the credentials are stored in your organisation's Vault |
| `status.credentials.secretStore` | `string` | The store the credentials were written to |
| `status.credentials.secretPath` | `string` | Path of the credentials, mount included: `stakater/projects/<organisation>-<project>/databases/<claim-name>` |
| `status.credentials.message` | `string` | Where the credentials are, or why they were not delivered |

## Credentials

When the database is ready, the platform writes the credentials into your organisation's [Vault](./vault.md), in your project's folder, at the path given by `status.credentials.secretPath`. Read them in the Vault web UI, or with the CLI from a device enrolled on your organisation's Mesh. Sign in with one of your project's roles (see [Project access](./vault.md#project-access)); the Vault address and the roles are in the project's `status.openbao`:

```bash
kubectl get postgres my-db -o jsonpath='{.status.credentials.secretPath}'
kubectl get project my-project -o jsonpath='{.status.openbao}'

export BAO_ADDR=<address from the project status>
bao login -method=oidc role=<organisation>-<project>-rw
bao kv get -mount=stakater projects/<organisation>-<project>/databases/my-db
```

The entry holds these keys:

| Key | Description |
|-----|-------------|
| `username` | Application user |
| `password` | Password for the application user |
| `host` | Read-write service name (matches `status.connection.host`) |
| `port` | Service port |
| `dbname` | Database name |
| `uri` | PostgreSQL connection URI (`postgresql://user:pass@host:port/db`) |

The entry stays in the Vault after the database is deleted; remove it with a read-write project role.

## Examples

### Minimal

```yaml
apiVersion: database.cloud.stakater.com/v1
kind: Postgres
metadata:
  name: my-db
spec:
  parameters: {}
```

### Highly-available, larger storage

```yaml
apiVersion: database.cloud.stakater.com/v1
kind: Postgres
metadata:
  name: app-db
spec:
  parameters:
    instances: 3
    storage:
      size: 50Gi
```

### Externally-reachable

```yaml
apiVersion: database.cloud.stakater.com/v1
kind: Postgres
metadata:
  name: external-db
spec:
  parameters:
    exposeLoadBalancer: true
```

### Consuming the credentials from a workload

Fetch the credentials from the Vault and create a Secret next to your workload, then mount it as environment variables:

```bash
bao kv get -mount=stakater -format=json projects/<organisation>-<project>/databases/my-db \
  | jq -r '.data.data' > creds.json
kubectl create secret generic my-db --from-env-file=<(jq -r 'to_entries[] | "\(.key)=\(.value)"' creds.json)
rm creds.json
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres-client
  template:
    metadata:
      labels:
        app: postgres-client
    spec:
      containers:
        - name: app
          image: my-app:latest
          envFrom:
            - secretRef:
                name: my-db
```

## How-to Guide

[Create a Postgres Database](../../how-to-guides/user/create-postgres.md)

## Related

- [Vault](./vault.md) — where your database credentials live
- Platform-tier API: [Postgres Cluster (Infrastructure)](../private-apis/postgres-cluster-infrastructure.md)
