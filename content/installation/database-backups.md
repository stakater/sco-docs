# Platform Database Backups

Back up the PostgreSQL databases the platform runs for itself, to a bucket the platform creates or to one you bring.

These are the platform's own databases, not the ones your users create. Users back up their own databases from their [Postgres](../api-reference/public-apis/postgres.md#backup) claims.

Each database archives every change as it happens and also takes a full backup on a schedule. Settings go under `spec.parameters.postgresBackup` in your `KubeStackConfig` claim (see [OpenShift Installation](openshift.md#kubestackconfig-claim-kubestack-config-claimyaml)).

## Which databases are covered

| Key under `instances` | Database | Backed up when `instances` omits it? |
|---|---|---|
| `orgMesh` | One per organisation's Mesh. Each writes below `mesh/<organisation>` | Yes, to the default target |
| `keycloak` | The platform identity provider | Yes, to the default target |
| `keycloakPublic` | The public identity provider | No. List it to back it up |
| `keycloakSco` | The SCO console identity provider | No. List it to back it up |

The last two are off by default because turning backups on restarts a database once. To back one up to the default target, give it an empty entry (`keycloakPublic: {}`). A database is only backed up if its component is installed.

## Choosing a target

`postgresBackup.type` sets the default target:

| `type` | Target |
|---|---|
| `managed` | An Amazon S3 bucket named `<name>-postgres-backup`, which the platform creates through its AWS provider. Needs `aws.enabled`. The platform identity provider (`keycloak`) keeps its own bucket, `<name>-rhbk-postgres-backup`, so its existing backups stay where they are. |
| `byo` | An existing bucket you name in `s3`, on Amazon S3 or any S3-compatible service. The platform does not create or empty it. |
| `disabled` | No backups. |

If you leave `type` out, it is `managed` when `aws.enabled` is `true` and `disabled` otherwise. A cluster that sets no `postgresBackup` keeps the backups it had before.

## Bringing your own bucket

```yaml
spec:
  parameters:
    postgresBackup:
      type: byo
      s3:
        bucket: acme-platform-backups
        path: <cluster-name>
        endpointURL: https://s3.example.com   # omit for Amazon S3
        region: eu-central-1                  # omit to let the client resolve it
        endpointCA: true                      # only for a private certificate authority
      credentials:
        openbaoKey: stakater/postgres-backup/s3
      retentionPolicy: 7d
      schedule: "0 0 2 * * *"
```

Each database writes below its own folder under `s3.path`: `mesh/<organisation>`, `keycloak`, `keycloakPublic` or `keycloakSco`. Databases that share a bucket never share a folder.

### Access key

The access key holds `ACCESS_KEY_ID` and `ACCESS_SECRET_KEY`. It also holds `ca.crt`, the authority's PEM certificate, when `s3.endpointCA` is `true`. The key needs to list the bucket and to read, write and delete objects below `s3.path`, because backups older than `retentionPolicy` are deleted.

Give the key in one of two ways:

| Field | Description |
|---|---|
| `credentials.openbaoKey` | Path of an entry in the platform's own OpenBao, read through the `stakater-cluster-secret-store` store. Default `stakater/postgres-backup/s3`. |
| `credentials.secretRef.{name,namespace}` | An existing Secret, copied to each database that uses it. Use it on a platform without OpenBao. It takes precedence over `openbaoKey`. |

## Settings for one database

An entry under `instances` overrides the default target for that database. Each field set on the entry replaces the default's field of the same name, and fields you leave out keep the default's value. This example sends the identity provider to a customer bucket, backs up the public identity provider to the default target, and turns off the organisation Mesh backups:

```yaml
spec:
  parameters:
    postgresBackup:
      retentionPolicy: 10d
      instances:
        orgMesh:
          type: disabled
        keycloak:
          type: byo
          s3:
            bucket: customer-backups
            path: platform
          credentials:
            openbaoKey: customer/postgres-backup/s3
          schedule: "0 0 1 * * *"
        keycloakPublic: {}
```

## Reference

| Field | Default | Description |
|---|---|---|
| `postgresBackup.type` | `managed` with `aws.enabled`, otherwise `disabled` | `managed`, `byo` or `disabled` |
| `postgresBackup.s3.bucket` | - | Existing bucket. Required for `byo` |
| `postgresBackup.s3.path` | bucket root | Prefix inside the bucket, without leading or trailing slashes |
| `postgresBackup.s3.endpointURL` | Amazon S3 | HTTPS endpoint of an S3-compatible service |
| `postgresBackup.s3.region` | resolved by the client | Region requests are signed for |
| `postgresBackup.s3.endpointCA` | `false` | Verify the endpoint against `ca.crt` in the access key |
| `postgresBackup.credentials.openbaoKey` | `stakater/postgres-backup/s3` | Access key entry in the platform OpenBao |
| `postgresBackup.credentials.secretRef` | - | Existing Secret holding the access key |
| `postgresBackup.retentionPolicy` | `7d` | How long a database stays recoverable: a number followed by `d`, `w` or `m`. With `managed`, keep it under 14 days, since the bucket deletes objects after 14 days |
| `postgresBackup.schedule` | `0 0 2 * * *` | Full backup schedule: a six-field cron expression in UTC, seconds first |
| `postgresBackup.instances.<key>` | see [Which databases are covered](#which-databases-are-covered) | Accepts the same fields as `postgresBackup`, except `instances` |

`type: byo` needs `s3`, set either on the instance or on `postgresBackup`.

## What's Next?

- [Platform Configuration](configuration.md) — Override other platform defaults
- [Platform Secret Store Unseal Method](openbao-unseal.md) — Protect the store that holds the access key
