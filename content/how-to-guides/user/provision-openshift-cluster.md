# How to Provision an OpenShift Cluster

Learn how to provision a managed OpenShift cluster for your team via an OpenShiftCluster claim.

Sam, a senior platform engineer at ACME Corp, needs to provide a dedicated OpenShift cluster for a product team. Sam can provision a fully managed cluster with a default node pool, networking mode, and group-based access — all through a single claim.

## Prerequisites

- Access to your organisation's project
- The `openshiftcluster.kubernetes.cloud.stakater.com` API available
- `kubectl` configured with your organisation project kubeconfig
- Sufficient permissions to create `OpenShiftCluster` resources

## What Gets Created

When you create an OpenShiftCluster claim, the platform provisions:

- A managed **OpenShift hosted cluster** with a dedicated control plane
- A default **node pool** sized via a T-shirt size (`small`, `medium`, `large`, `xlarge`)
- **Single sign-on integration** so users can sign in with their organisation identity
- **Group-to-role bindings** for cluster access (optional)
- **Bootstrap credentials**, console URL, and API endpoint exposed on the claim status

## In the Console

Clusters are under **Containers** in the sidebar:

![The OpenShift cluster list in the console]({{ screenshot: cluster-list }})

The create form opens in **Standard** mode, which asks for the same one field the minimal claim below does — everything else falls back to a platform default:

![The Create OpenShift Cluster form in Standard mode]({{ screenshot: cluster-create-standard }})

**Advanced** reveals the rest of the claim further down the form — node pool sizing, the networking **Mode** as a Public / Private choice with what each one exposes, and the OpenShift **Version**:

![The lower part of the create form in Advanced mode, showing the networking mode choice and the version selector]({{ screenshot: cluster-create-advanced }})

## Step 1: Minimal Configuration

Create a file named `cluster.yaml` with only the required parameter:

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

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `parameters.clusterName` | Name of the OpenShift cluster (1–63 characters) |

All other parameters fall back to platform-managed defaults — version `4.19`, a `medium` node pool with `3` replicas, and `public` networking mode.

## Step 2: Full Configuration

For production use, customise the version, node pool size, networking mode, and access groups:

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

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `parameters.version` | `4.19` | OpenShift version (`4.18`, `4.19`, or `4.20`) |
| `parameters.defaultNodepool.enabled` | `true` | Create a default node pool with the cluster. Set to `false` to manage node pools separately via `OpenShiftNodePool` claims. |
| `parameters.defaultNodepool.size` | `medium` | T-shirt size for default node pool nodes: `small`, `medium`, `large`, or `xlarge`. Each size maps to a predefined CPU, memory, and root volume configuration at the platform level. |
| `parameters.defaultNodepool.replicas` | `3` | Number of nodes in the default node pool (1–10) |
| `parameters.networking.mode` | `public` | Network access mode for the cluster API and console: `public` or `private` |
| `parameters.access.groups` | — | Grants organisation groups a role on the cluster (see below) |
| `parameters.bootstrap.enabled` | `false` | When `true`, the hosting cluster auto-installs core add-ons (Crossplane, ArgoCD, ksp-system). Enable for new clusters; leave disabled for clusters that were bootstrapped manually. |

### Access Grants

Each entry under `access.groups` grants an organisation group a role on the cluster. Members of that group receive the role when they sign in. Platform-managed namespaces are excluded.

| Field | Description |
|-------|-------------|
| `name` | Organisation group name, exactly as it appears in your single sign-on. Must be a valid Kubernetes name (RFC 1123 subdomain). Names reserved for platform access are rejected: `customer-admin`, and names starting with `stakater-` or ending in `-cluster-admin` or `-stakater-admin`. |
| `role` | Access level to grant: `view`, `edit`, `admin`, or `customer-admin`. |

**What each role grants:**

| Role | Scope | Grants |
|------|-------|--------|
| `view` | your projects | read-only access to resources in your projects on the cluster |
| `edit` | your projects | create and modify resources in your projects on the cluster |
| `admin` | your projects | full administration of your projects on the cluster, including managing access within them |
| `customer-admin` | the cluster | `admin` on every project you use on the cluster, plus selected cluster-wide permissions such as browsing and installing operators from the marketplace. Platform-managed namespaces and host-level (node) access stay off-limits. |

`cluster-admin` and any role not listed above are rejected. Members must sign out and back in after a grant is added for it to take effect.

!!! note "Full cluster administration"
    By default `customer-admin` is restricted as described in the table. Your platform administrator can enable full cluster administration for your organisation or for a single cluster. Members of a `customer-admin` group then also become cluster administrators, including in the platform-managed namespaces. The claim cannot change this setting.

## Step 3: Apply the Claim

```bash
kubectl apply -f cluster.yaml
```

## Step 4: Monitor Provisioning

Cluster provisioning takes several minutes. Monitor progress:

```bash
kubectl get openshiftcluster my-cluster -n my-tenant
```

Check the detailed status and conditions:

```bash
kubectl describe openshiftcluster my-cluster -n my-tenant
```

Once provisioning completes, the claim reports `READY=True` and `SYNCED=True`:

```text
NAME         READY   SYNCED   AGE
my-cluster   True    True     15m
```

For a more granular view, read `status.phase` directly. It moves through `Initializing` → `RegistrationPending` → `Ready`:

```bash
kubectl get openshiftcluster my-cluster -n my-tenant -o jsonpath="{.status.phase}"
```

The cluster's detail page in the console shows the same phase, alongside the console URL and API endpoint that [Step 5](#step-5-access-the-cluster) reads out of the status:

![A cluster detail page showing the phase and access grants]({{ screenshot: cluster-detail }})

The console URL and API endpoint are in the **Status** block further down the page, shown in **Advanced** mode.

## Step 5: Access the Cluster

Once the cluster is ready, the claim status exposes the console URL, API endpoint, and bootstrap credentials:

```bash
kubectl get openshiftcluster my-cluster -n my-tenant -o jsonpath="{.status.consoleUrl}"
kubectl get openshiftcluster my-cluster -n my-tenant -o jsonpath="{.status.apiEndpoint}"
```

Users sign in through your organisation's identity provider with the roles granted via `access.groups`. A private cluster is reachable only over your organisation's mesh. [Connect to an OpenShift Cluster](connect-to-openshift-cluster.md) walks through enrolling a device, opening the console and logging in with the CLI.

!!! tip
    Contact your platform administrator for the list of validated OpenShift versions and the CPU/memory mappings backing each T-shirt size in your environment.

## What's Next?

- [Connect to an OpenShift Cluster](connect-to-openshift-cluster.md) - Join the mesh, open the console and sign in
- [Create a Project](create-project.md) - Create projects for teams on the new cluster
- [Create an IAM Group](create-iam-group.md) - Set up group-based access to the cluster
- [Provision a Virtual Machine](provision-virtual-machine.md) - Deploy VMs alongside your cluster
