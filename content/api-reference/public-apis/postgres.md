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
| `storage.size` | `string` | `10Gi` | Disk size per PostgreSQL instance |
| `exposeLoadBalancer` | `boolean` | `false` | When `true`, the database is reachable from outside the project via an externally-routable endpoint. When `false`, the database is reachable only from inside the project. |

## Status Fields

`status.connection` carries non-sensitive endpoint metadata only. Credentials (username, password, URI) are **not** placed here — they are delivered to the project as a Secret (see [Credentials](#credentials)).

| Field | Type | Description |
|-------|------|-------------|
| `status.connection.host` | `string` | PostgreSQL read-write service hostname |
| `status.connection.port` | `string` | PostgreSQL service port (typically `5432`) |
| `status.connection.database` | `string` | Database name |
| `status.connection.externalHost` | `string` | Externally-reachable hostname or IP of the database. Populated only when `parameters.exposeLoadBalancer` is `true`. |

## Credentials

When the database is ready, the platform delivers a Secret named after the claim (`<metadata.name>`) into the project. The keys cover the most common client conventions:

| Secret key | Description |
|------------|-------------|
| `username` / `user` | Application user (both keys carry the same value) |
| `password` | Password for the application user |
| `host` | Read-write service hostname (matches `status.connection.host`) |
| `port` | Service port |
| `dbname` | Database name |
| `uri` | PostgreSQL connection URI (`postgresql://user:pass@host:port/db`) |
| `jdbc-uri` | JDBC URL (`jdbc:postgresql://host:port/db?password=...&user=...`) |
| `fqdn-uri` | Same as `uri` but with the host's fully-qualified cluster DNS name |
| `fqdn-jdbc-uri` | Same as `jdbc-uri` but with the host's fully-qualified cluster DNS name |
| `pgpass` | A line for `~/.pgpass` (`host:port:db:user:password`) |

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

### Consuming the credentials

Mount the delivered Secret as environment variables on a workload:

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

- Platform-tier API: [Postgres Cluster (Infrastructure)](../private-apis/postgres-cluster-infrastructure.md)
