# Publishing APIs

When you define a new service — a Crossplane XRD and composition — that service lives on the management cluster. Making it available in consumer project workspaces requires publishing it through the KCP virtual API layer.

SCO handles this through the **api-syncagent**: a declarative composition that automates the entire publication pipeline from a single claim.

---

## What API Publishing Does

Publishing an API means making a resource type available as a native Kubernetes resource in consumer project workspaces. After publishing:

- Consumers can `kubectl get <resource>` in their project and see it as a first-class type
- `kubectl apply` of a claim triggers reconciliation on the service cluster via Crossplane
- Status, events, and connection details flow back to the consumer's workspace transparently

Without this, Crossplane XRDs exist only on the management cluster and are invisible to consumers working against their project API endpoint.

---

## The api-syncagent

The api-syncagent is the bridge between the service cluster (where Crossplane runs) and consumer workspaces (where consumers interact with their project APIs).

For each published API group, the api-syncagent:

1. **Watches** consumer workspaces for new claims of the exported type
2. **Creates** corresponding objects on the service cluster, namespaced per workspace
3. **Synchronises** status and connection details back to the consumer's workspace in real time

This is declarative and continuous — the sync agent reconciles state on both sides throughout the object's lifecycle, from creation through to deletion.

### What gets provisioned

When you publish an API group, SCO automatically creates:

| Resource | Where | Purpose |
|----------|-------|---------|
| `PublishedResource` (one per resource kind) | Service cluster | Maps the KCP resource type to service cluster namespacing and naming rules |
| `APIExport` (one per API group) | KCP workspace | Declares the API group as available for workspace binding |
| `ClusterRole` + `ClusterRoleBinding` | Service cluster | Grants the sync agent permission to manage the exported resource types |
| api-syncagent `Deployment` (via Helm) | Management cluster | The running sync process that watches and bridges workspaces |
| `EnvironmentConfig` | Management cluster | Registers the published services for platform-level integration |

All of this is driven by a single `ApiExport` claim.

---

## Prerequisites

Before publishing an API, ensure the following are in place:

- The Crossplane XRD and composition for your service are installed and working
- `infrastructure.stakater.com` api available (api-syncagent-package installed)
- The `kcp-api-syncagent` Helm chart installed on the service cluster (provides the `PublishedResource` CRD and OpenShift security constraints)
- Provider configs available: `kubernetes-provider`, a KCP provider config, and a Helm provider config

### Installing the catalog package

The `kcp-api-syncagent` Helm chart installs the `PublishedResource` CRD and (on OpenShift) the required `SecurityContextConstraints`. Install it on the service cluster before creating any `ApiExport` claims:

```bash
helm install kcp-api-syncagent oci://ghcr.io/stakater/catalog/kcp-api-syncagent \
  --namespace kcp-system \
  --create-namespace \
  --set scc.enabled=true     # set false if not running on OpenShift
```

---

## Publishing an API Group

Create an `ApiExport` claim declaring which API groups and resource types to publish:

```yaml
apiVersion: infrastructure.stakater.com/v1alpha1
kind: ApiExport
metadata:
  name: my-database-service
spec:
  providerConfigRef:
    name: kubernetes-provider
  kcpProviderConfigRef:
    name: kcp-provider
  helmProviderConfigRef:
    name: helm-provider
  parameters:
    apiSyncagent:
      namespace: kcp-system
    exports:
      - apiGroup: databases.cloud.stakater.com
        resources:
          - resource:
              kind: PostgreSQLDatabase
              plural: postgresqldatabases
              version: v1
            namespaceSuffix: postgresql
```

Apply this to the management cluster. SCO provisions the full publication stack automatically.

---

## Publishing Multiple API Groups

A single `ApiExport` claim can publish multiple API groups. Each group gets its own `APIExport`, `ClusterRole`, `ClusterRoleBinding`, and sync agent deployment:

```yaml
apiVersion: infrastructure.stakater.com/v1alpha1
kind: ApiExport
metadata:
  name: platform-services
spec:
  providerConfigRef:
    name: kubernetes-provider
  kcpProviderConfigRef:
    name: kcp-provider
  helmProviderConfigRef:
    name: helm-provider
  parameters:
    apiSyncagent:
      namespace: kcp-system
    exports:
      - apiGroup: databases.cloud.stakater.com
        resources:
          - resource:
              kind: PostgreSQLDatabase
              plural: postgresqldatabases
              version: v1
            namespaceSuffix: postgresql
          - resource:
              kind: MySQLDatabase
              plural: mysqldatabases
              version: v1
            namespaceSuffix: mysql
      - apiGroup: messaging.cloud.stakater.com
        resources:
          - resource:
              kind: KafkaCluster
              plural: kafkaclusters
              version: v1
            namespaceSuffix: kafka
```

This produces a sync agent per API group, each scoped to only the resources it manages.

---

## API Projections

By default, the resource type exposed in consumer workspaces matches the type on the service cluster exactly. Projections let you remap the API shape in KCP — different kind name, different group, different API version — while the underlying implementation remains unchanged.

This is useful when you want a user-friendly API surface that is decoupled from the internal composition API:

```yaml
exports:
  - apiGroup: infrastructure.stakater.com
    resources:
      - resource:
          kind: XPostgreSQLDatabase     # Internal composite type
          plural: xpostgresqldatabases
          version: v1
        namespaceSuffix: postgresql
        projection:
          kind: PostgreSQLDatabase      # What consumers see in their workspace
          group: databases.cloud.stakater.com
          version: v1
```

Consumers interact with `PostgreSQLDatabase` under `databases.cloud.stakater.com`. The sync agent translates this to the underlying `XPostgreSQLDatabase` on the service cluster. The consumer API is stable even if the internal implementation changes.

---

## Namespace Mapping

For each published resource, the sync agent creates objects on the service cluster in namespaces derived from the consumer workspace. The `namespaceSuffix` parameter controls the suffix of the generated namespace name.

For a project workspace named `org-acme-frontend` with a `PostgreSQLDatabase` claim, the sync agent creates the corresponding object in a namespace like `ws-org-acme-frontend-postgresql` on the service cluster. This keeps objects for different consumers isolated at the namespace level.

---

## Checking Publication Status

After applying an `ApiExport` claim, verify that all components are ready:

```bash
# Check the ApiExport composite status
kubectl get apiexport my-database-service -o yaml

# Confirm sync agents are running
kubectl get pods -n kcp-system -l api-group=databases.cloud.stakater.com

# Verify PublishedResources are present on the service cluster
kubectl get publishedresources

# Confirm APIExport exists in the KCP workspace
# (requires KCP workspace kubeconfig)
kubectl get apiexports
```

The `ApiExport` claim enters a `Ready: True` state once all constituent resources are healthy.

---

## How Consumer Projects Receive the API

When a new project is provisioned, SCO automatically creates `APIBinding` resources in that project's workspace for every published API group. This means consumers do not take any action to enable a published API — it is simply available in their project from the moment the project is created.

If you publish a new API group after projects already exist, the `APIBinding` is added to all existing project workspaces as part of the platform's reconciliation loop.

---

## What's Next?

- [KCP Overview](kcp-overview.md) — How the virtual API layer works
- [Creating Solutions](../solutions/creating-solutions.md) — Define the XRD and composition before publishing
- [Crossplane Integration](../../integrations/crossplane.md) — Writing compositions for your service
- [KCP Integration](../../integrations/kcp.md) — Reference on KCP workspace management
