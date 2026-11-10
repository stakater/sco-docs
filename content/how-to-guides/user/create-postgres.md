# How to Create a Postgres Database

Learn how to provision a PostgreSQL database in your project. The examples below match the `my-database` shown in the console screenshots.

Jordan, a backend engineer at ACME Corp, needs a managed PostgreSQL database for her application. She can provision one, scale it for high availability, and connect to it from a workload in minutes.

## Prerequisites

- A [Project](create-project.md) already created
- The `postgres.database.cloud.stakater.com` API available
- `kubectl` configured with your project kubeconfig
- To read the credentials: access to your organisation's [Vault](create-vault.md) from a device enrolled on the [Mesh](create-mesh.md)

## What Gets Created

When you create a Postgres claim, the platform provisions:

- A **PostgreSQL database** sized to your requested number of instances and disk
- **Credentials in your organisation's Vault**, at the path published in the claim's status
- Optionally, an **externally-reachable endpoint** when `exposeLoadBalancer: true`

## In the Console

Databases are under **Database** in the sidebar. The create form opens in **Standard** mode and asks for a project and a name, the same as the minimal claim below:

![The Create Postgres form in Standard mode]({{ screenshot: postgres-create }})

**Advanced** reveals the optional parameters: whether to expose the database outside the project, the number of instances, the organisation groups allowed to reach it over the mesh, and the storage size.

![The lower part of the create form in Advanced mode, showing the expose option, instances, mesh access groups and storage]({{ screenshot: postgres-create-advanced }})

## Step 1: Define a Postgres Claim

Create a file named `db.yaml`:

```yaml
apiVersion: database.cloud.stakater.com/v1
kind: Postgres
metadata:
  name: my-database
spec:
  parameters: {}
```

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `parameters.instances` | `1` | Number of PostgreSQL instances (replicas). Use `3` for HA. |
| `parameters.storage.size` | `10Gi` | Disk size per instance |
| `parameters.exposeLoadBalancer` | `false` | When `true`, the database is reachable from outside the project |
| `parameters.meshAccess.groups` | — | Organisation groups whose members may reach the database over your organisation's [Mesh](create-mesh.md) on port 5432. Empty means no mesh access. Database credentials still control who can log in. |

## Step 2: Apply the Claim

```bash
kubectl apply -f db.yaml
```

## Step 3: Verify the Database

Check the claim status:

```bash
kubectl get postgres my-database
```

Wait for it to become ready:

```text
NAME          SYNCED   READY   AGE
my-database   True     True    2m
```

The list in the console shows the same readiness:

![The Postgres list in the console]({{ screenshot: postgres-list }})

Open the database to see its parameters, with the connection details and the Vault path holding the credentials further down the page:

![A Postgres detail page, showing the parameters, mesh access and storage]({{ screenshot: postgres-detail }})

Or inspect the same values with `kubectl`:

```bash
kubectl get postgres my-database -o jsonpath='{.status.connection}'
```

```json
{"host":"my-database-rw.projects.svc.cluster.local","port":"5432","database":"my-database","credentialsRef":{"vault":"https://bao.acme.mesh.example.stakater.cloud","mount":"services","path":"my-project/postgres/my-database"}}
```

## Step 4: Read the Credentials

The platform stores the credentials in your organisation's Vault at `status.connection.credentialsRef`. Open the Vault URL in a browser (from a Mesh-enrolled device) and navigate to the `services` secret engine, or use the CLI:

```bash
export BAO_ADDR=$(kubectl get postgres my-database -o jsonpath='{.status.connection.credentialsRef.vault}')
bao login -method=oidc
bao kv get -mount=services $(kubectl get postgres my-database -o jsonpath='{.status.connection.credentialsRef.path}')
```

Keys cover the common client conventions:

| Key | Description |
|-----|-------------|
| `username` / `user` | Application user (both keys carry the same value) |
| `password` | Password for the application user |
| `host` | Read-write service hostname |
| `port` | Service port |
| `dbname` | Database name |
| `uri` | PostgreSQL connection URI |
| `jdbc-uri` | JDBC URL |
| `fqdn-uri`, `fqdn-jdbc-uri` | URI / JDBC URL with the host's fully-qualified cluster DNS name |
| `pgpass` | A line for `~/.pgpass` |

### Mount the credentials into a workload

Create a Secret next to your workload from the Vault values, then reference it with `envFrom`:

```bash
bao kv get -mount=services -format=json my-project/postgres/my-database \
  | jq -r '.data.data' > creds.json
kubectl create secret generic my-database --from-env-file=<(jq -r 'to_entries[] | "\(.key)=\(.value)"' creds.json)
rm creds.json
```

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
                name: my-database
```

The container will see `DATABASE_URL`-equivalent values through the standard keys (`host`, `port`, `username`, `password`, `dbname`, `uri`).

### Test from your workstation

For ad-hoc testing — `psql` from your laptop, a local migration runner, a BI tool — set `parameters.exposeLoadBalancer: true` on the claim. The platform provisions an externally-routable endpoint and surfaces its hostname / IP under `status.connection.externalHost`:

```yaml
apiVersion: database.cloud.stakater.com/v1
kind: Postgres
metadata:
  name: my-database
spec:
  parameters:
    exposeLoadBalancer: true
```

!!! warning "Port 5432 may not be open to the internet"
    Whether `externalHost` is reachable from the internet depends on your cloud's network perimeter. On Stakater's production cloud the perimeter admits only a few ports, such as `443` for HTTPS, and PostgreSQL's port `5432` is not one of them: the claim still reports Ready and `externalHost` still gets an address, but connections from outside the platform's network time out. Ask your platform team which ports your perimeter admits.
    <!-- Source: ADR-0067 (gateway allowlist, confirmed for eu-1; eu-2 is more permissive, others unverified). Probe 2026-10-30: eu-1 VIP answers on 443, drops 5432. Not yet tested with a real Postgres claim. Tracked internally: SA-9189. -->

From a network that can reach the endpoint, connect using the credentials from the Vault:

```bash
PG_HOST=$(kubectl get postgres my-database -o jsonpath='{.status.connection.externalHost}')
CREDS=$(bao kv get -mount=services -format=json my-project/postgres/my-database | jq -r '.data.data')
export PGUSER=$(echo "$CREDS" | jq -r '.username')
export PGPASSWORD=$(echo "$CREDS" | jq -r '.password')
export PGDATABASE=$(echo "$CREDS" | jq -r '.dbname')

psql -h "$PG_HOST" -p 5432 -c "SELECT version();"
```

If you left `exposeLoadBalancer` off, the database is reachable from inside the project and, when `meshAccess.groups` lists a group you belong to, from any device enrolled on your organisation's [Mesh](create-mesh.md):

```yaml
apiVersion: database.cloud.stakater.com/v1
kind: Postgres
metadata:
  name: my-database
spec:
  parameters:
    meshAccess:
      groups:
        - database-admins
```

From an enrolled device, connect to the `host` published in the credentials with the same `psql` command as above. Mesh access opens only the network path; the database credentials still decide who can log in.

## Step 5: Scale the Database (Optional)

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

## Step 6: Delete the Database

```bash
kubectl delete postgres my-database
```

The platform tears down the database and removes the credentials from your organisation's Vault. If you copied the credentials into Secrets next to your workloads, remember to delete those too:

```bash
kubectl delete secret my-database
```

!!! warning
    All data is deleted when the claim is removed. Back up any database you need to keep before deletion.

## What's Next?

- [Create an S3 Bucket](create-s3-bucket.md) - Provision object storage alongside your database
- [Provision a Virtual Machine](provision-virtual-machine.md) - Run compute that consumes the database
- [Deploy Your First App](deploy-first-app.md) - Wire the database into an application deployment
