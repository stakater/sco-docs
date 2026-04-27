# How to Create a Postgres Database

Learn how to provision a PostgreSQL database in your project.

Jordan, a backend engineer at ACME Corp, needs a managed PostgreSQL database for her application. She can provision one, scale it for high availability, and connect to it from a workload in minutes.

## Prerequisites

- A [Project](create-project.md) already created
- The `postgres.database.cloud.stakater.com` API available
- `kubectl` configured with your project kubeconfig

## What Gets Created

When you create a Postgres claim, the platform provisions:

- A **PostgreSQL database** sized to your requested number of instances and disk
- A **Secret** in your project containing the connection URI and credentials, named after the claim
- Optionally, an **externally-reachable endpoint** when `exposeLoadBalancer: true`

## Step 1: Define a Postgres Claim

Create a file named `db.yaml`:

```yaml
apiVersion: database.cloud.stakater.com/v1
kind: Postgres
metadata:
  name: my-db
spec:
  parameters: {}
```

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `parameters.instances` | `1` | Number of PostgreSQL instances (replicas). Use `3` for HA. |
| `parameters.storage.size` | `10Gi` | Disk size per instance |
| `parameters.exposeLoadBalancer` | `false` | When `true`, the database is reachable from outside the project |

## Step 2: Apply the Claim

```bash
kubectl apply -f db.yaml
```

## Step 3: Verify the Database

Check the claim status:

```bash
kubectl get postgres my-db
```

Wait for it to become ready:

```text
NAME    SYNCED   READY   AGE
my-db   True     True    2m
```

Inspect the endpoint metadata:

```bash
kubectl get postgres my-db -o jsonpath='{.status.connection}'
```

```json
{"host":"my-db-rw.projects.svc.cluster.local","port":"5432","database":"my-db"}
```

## Step 4: Consume the Credentials

The platform delivers a Secret named after the claim (`my-db`) into your project. Keys cover the common client conventions:

| Secret key | Description |
|------------|-------------|
| `username` / `user` | Application user (both keys carry the same value) |
| `password` | Password for the application user |
| `host` | Read-write service hostname |
| `port` | Service port |
| `dbname` | Database name |
| `uri` | PostgreSQL connection URI |
| `jdbc-uri` | JDBC URL |
| `fqdn-uri`, `fqdn-jdbc-uri` | URI / JDBC URL with the host's fully-qualified cluster DNS name |
| `pgpass` | A line for `~/.pgpass` |

### Mount it into a workload

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: app
          image: my-app:latest
          envFrom:
            - secretRef:
                name: my-db
```

The container will see `DATABASE_URL`-equivalent values through the standard keys (`host`, `port`, `username`, `password`, `database`, `uri`).

### Test from your workstation

Port-forward the Postgres service and open a `psql` session:

```bash
kubectl port-forward svc/my-db-rw 5432:5432 &

export PGUSER=$(kubectl get secret my-db -o jsonpath='{.data.username}' | base64 -d)
export PGPASSWORD=$(kubectl get secret my-db -o jsonpath='{.data.password}' | base64 -d)
export PGDATABASE=$(kubectl get secret my-db -o jsonpath='{.data.dbname}' | base64 -d)

psql -h 127.0.0.1 -p 5432 -c "SELECT version();"
```

## Step 5: Scale or Expose the Database (Optional)

### High availability with 3 instances

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

### Externally-reachable database

When you need to connect from outside the project — a local tool, a migration runner, a BI tool — set `exposeLoadBalancer: true`:

```yaml
apiVersion: database.cloud.stakater.com/v1
kind: Postgres
metadata:
  name: external-db
spec:
  parameters:
    exposeLoadBalancer: true
```

The external host is surfaced under `status.connection.externalHost`:

```bash
kubectl get postgres external-db -o jsonpath='{.status.connection.externalHost}'
```

Use that host with the credentials from the Secret to connect from outside.

## Step 6: Delete the Database

```bash
kubectl delete postgres my-db
```

The platform tears down the database. The credentials Secret is removed from your project on a best-effort basis — if a stale `<claim-name>` Secret remains after the claim is gone, drop it with:

```bash
kubectl delete secret my-db
```

!!! warning
    All data is deleted when the claim is removed. Back up any database you need to keep before deletion.

## What's Next?

- [Create an S3 Bucket](create-s3-bucket.md) - Provision object storage alongside your database
- [Provision a Virtual Machine](provision-virtual-machine.md) - Run compute that consumes the database
- [Deploy Your First App](deploy-first-app.md) - Wire the database into an application deployment
