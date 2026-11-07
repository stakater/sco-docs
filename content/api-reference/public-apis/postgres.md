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
| `exposeLoadBalancer` | `boolean` | `false` | When `true`, the platform creates an external endpoint for the database and reports it in `status.connection.externalHost`. Whether that endpoint is reachable from the internet depends on your cloud's network perimeter; on Stakater's production cloud it is not, because the perimeter does not admit port `5432` (see [Test from Your Workstation](../../how-to-guides/user/create-postgres.md#test-from-your-workstation)). When `false`, the database is reachable only from inside the project. |

### Backup

Continuous backups to a bucket you own, on Amazon S3 or any S3-compatible service. Every change is archived as it happens, and a full backup is taken on a schedule. Turning backups on or off restarts the database once.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `backup.enabled` | `boolean` | `false` | Back the database up. |
| `backup.bucket` | `string` | — | Name of an existing bucket. The platform does not create or empty it. Required when `enabled` is `true`. |
| `backup.path` | `string` | bucket root | Folder inside the bucket, for example `postgres/orders`. The database writes below it in a folder of its own. |
| `backup.endpointURL` | `string` | Amazon S3 | `https://` address of an S3-compatible storage service, for example `https://s3.example.com`. |
| `backup.region` | `string` | detected | Region of the bucket, for example `eu-west-1`. |
| `backup.schedule` | `string` | `0 0 2 * * *` | When to take the full backup: a six-field cron expression in UTC, seconds first. The default is 02:00 every day. |
| `backup.retentionPolicy` | `string` | `7d` | How far back the database can be restored: a number followed by `d` (days), `w` (weeks) or `m` (months). |
| `backup.credentials.secretPath` | `string` | — | Path of the access key in your project's folder of your organisation's [Vault](./vault.md#what-the-platform-keeps-in-your-project-folder): `postgres/backup` reads `stakater/projects/<organisation>-<project>/postgres/backup`. Segments of letters, digits, `.`, `_` or `-`, separated by `/`. A path outside your project folder cannot be named. |
| `backup.credentials.secretName` | `string` | — | Name of an existing Secret in the namespace the database runs in. Takes precedence over `secretPath`. Your project kubeconfig may not reach that namespace, so use `secretPath` unless your platform team has created the Secret for you. |
| `backup.credentials.privateCA` | `boolean` | `false` | Verify the storage service against the certificate under `ca.crt` in the access key. Use it when the service's certificate is issued by a private certificate authority. |

When `enabled` is `true`, `bucket` and one of `credentials.secretPath` or `credentials.secretName` are required.

The access key, in the Vault or in the Secret, holds these keys:

| Key | Description |
|-----|-------------|
| `ACCESS_KEY_ID` | Access key ID for the bucket |
| `ACCESS_SECRET_KEY` | Secret access key for the bucket |
| `ca.crt` | PEM certificate of the private certificate authority. Needed only with `privateCA: true`. |

The key needs to list the bucket and to read, write and delete objects below `path`: the platform deletes backups older than `retentionPolicy`.

## Status Fields

`status.connection` carries non-sensitive endpoint metadata plus a pointer to the credentials. Credentials (username, password, URI) are **not** placed here — they are stored in your organisation's Vault (see [Credentials](#credentials)).

| Field | Type | Description |
|-------|------|-------------|
| `status.connection.host` | `string` | PostgreSQL read-write service hostname |
| `status.connection.port` | `string` | PostgreSQL service port (typically `5432`) |
| `status.connection.database` | `string` | Database name |
| `status.connection.externalHost` | `string` | Externally-reachable hostname or IP of the database. Populated only when `parameters.exposeLoadBalancer` is `true`. |
| `status.connection.credentialsRef.vault` | `string` | URL of the Vault holding the credentials, reachable over your organisation's [Mesh](./mesh.md) |
| `status.connection.credentialsRef.mount` | `string` | Secret engine the credentials are under (`services`) |
| `status.connection.credentialsRef.path` | `string` | Path of the credentials within the mount (`<project>/postgres/<claim-name>`) |

## Credentials

When the database is ready, the platform writes the credentials into your organisation's [Vault](./vault.md) at the location given by `status.connection.credentialsRef`. Read them in the Vault web UI, or with the CLI from a device enrolled on your organisation's Mesh:

```bash
export BAO_ADDR=$(kubectl get postgres my-db -o jsonpath='{.status.connection.credentialsRef.vault}')
bao login -method=oidc
bao kv get -mount=services $(kubectl get postgres my-db -o jsonpath='{.status.connection.credentialsRef.path}')
```

The keys cover the most common client conventions:

| Key | Description |
|-----|-------------|
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

### Backed up to your own bucket

```yaml
apiVersion: database.cloud.stakater.com/v1
kind: Postgres
metadata:
  name: orders-db
spec:
  parameters:
    backup:
      enabled: true
      bucket: acme-backups
      path: postgres/orders
      endpointURL: https://s3.example.com
      region: eu-central-1
      schedule: "0 15 1 * * *"
      retentionPolicy: 14d
      credentials:
        secretPath: postgres/backup
        privateCA: true
```

### Consuming the credentials from a workload

Fetch the credentials from the Vault and create a Secret next to your workload, then mount it as environment variables:

```bash
bao kv get -mount=services -format=json <project>/postgres/my-db \
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
