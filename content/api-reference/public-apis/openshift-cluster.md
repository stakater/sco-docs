# OpenShift Cluster

Provisions a managed OpenShift hosted cluster with a T-shirt sized default node pool, single sign-on integration, and group-based access control.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `kubernetes.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `OpenShiftCluster` |
| **Scope** | Namespace-scoped |

## Spec Parameters

All parameters are nested under `spec.parameters`.

### Required

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `clusterName` | `string` | 1–63 characters | Name of the OpenShift cluster |

### Optional

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `version` | `string` | `4.19` | OpenShift version. Allowed: `4.18`, `4.19`, `4.20` |
| `defaultNodepool.enabled` | `boolean` | `true` | Create a default node pool with the cluster. Set to `false` to manage node pools separately via `OpenShiftNodePool` claims. |
| `defaultNodepool.size` | `string` | `medium` | T-shirt size for default node pool nodes. Allowed: `small`, `medium`, `large`, `xlarge`. Maps to a predefined CPU, memory, and root volume configuration at the platform level. |
| `defaultNodepool.replicas` | `integer` | `3` | Number of nodes in the default node pool (1–10) |
| `networking.mode` | `string` | `public` | Network access mode for the cluster API and console. Allowed: `public`, `private` |
| `access.groups` | `array` | — | Grants organisation groups a role on the cluster (see below) |
| `bootstrap.enabled` | `boolean` | `false` | When `true`, the hosting cluster auto-installs core add-ons (Crossplane, ArgoCD, ksp-system). Enable for new clusters; leave disabled for clusters that were bootstrapped manually. |

### `access.groups[]`

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `name` | `string` | 1–253 characters, RFC 1123 subdomain | Organisation group name, exactly as it appears in your single sign-on. Names reserved for platform access are rejected: `customer-admin`, and names starting with `stakater-` or ending in `-cluster-admin` or `-stakater-admin`. |
| `role` | `string` | `view`, `edit`, `admin`, or `customer-admin` | Access level to grant the group. See [Access Roles](#access-roles). |

#### Access Roles

Every role applies to all projects on the cluster except the platform-managed ones (such as `default`, `kube-*` and `openshift-*`).

| Role | Grants |
|------|--------|
| `view` | read-only access to resources |
| `edit` | create and modify resources |
| `admin` | full administration, including managing access within each project |
| `customer-admin` | everything `admin` grants, plus selected cluster-wide permissions: browsing the full operator catalog, viewing nodes and storage classes, and managing cluster resource quotas. Nodes are read-only and privileged workloads are not allowed. |

`cluster-admin` and any role not listed above are rejected.

By default `customer-admin` is restricted as described in the table. It can browse the operator catalog but cannot create the operator group that an installation needs, so installing operators requires full cluster administration. Your platform administrator can enable full cluster administration for your organisation or for a single cluster. Members of a `customer-admin` group then also become cluster administrators, including in the platform-managed namespaces. The claim cannot change this setting.

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.ready` | `boolean` | Whether the cluster is ready for use |
| `status.phase` | `string` | Current phase: `Initializing`, `RegistrationPending`, or `Ready` |
| `status.message` | `string` | Human-readable status message explaining the current state |
| `status.version` | `string` | OpenShift cluster version |
| `status.consoleUrl` | `string` | URL to access the OpenShift console |
| `status.apiEndpoint` | `string` | Kubernetes API server endpoint URL |
| `status.credentials.username` | `string` | Bootstrap username for console access |
| `status.credentials.password` | `string` | Bootstrap password (kubeadmin) |

## Examples

### Minimal

```yaml
apiVersion: kubernetes.cloud.stakater.com/v1
kind: OpenShiftCluster
metadata:
  name: my-cluster
  namespace: my-tenant
spec:
  parameters:
    clusterName: my-cluster
```

### Full

```yaml
apiVersion: kubernetes.cloud.stakater.com/v1
kind: OpenShiftCluster
metadata:
  name: prod-cluster
  namespace: my-tenant
spec:
  parameters:
    clusterName: prod-cluster
    version: "4.19"
    defaultNodepool:
      enabled: true
      size: large
      replicas: 5
    networking:
      mode: public
    access:
      groups:
        - name: platform-admins
          role: customer-admin
        - name: developers
          role: edit
    bootstrap:
      enabled: true
```

## How-to Guide

[Provision an OpenShift Cluster](../../how-to-guides/user/provision-openshift-cluster.md)
