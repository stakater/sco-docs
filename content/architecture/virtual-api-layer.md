# Virtual API Layer

The virtual API layer is the mechanism that gives every project its own isolated Kubernetes API endpoint without running a separate physical cluster for each one. It is implemented by KCP (Kubernetes Control Plane) and is what makes the SCO model of per-project isolation practical at scale.

---

## The Problem with Shared API Servers

In a conventional Kubernetes cluster, every tenant shares one API server. Resources are separated by namespace, but the API surface itself — which resource types exist, what CRDs are installed, which API groups are available — is identical for every tenant. A CRD installed for one tenant is visible to all tenants.

Namespace-level isolation has limits: blast radius, noisy neighbours on the API server, and the inability to give different tenants different API surfaces. The alternative — one physical cluster per tenant — is expensive and difficult to operate at scale.

KCP solves this by serving thousands of independent virtual API servers (workspaces) from a single lightweight process.

---

## How KCP Workspaces Work

A KCP workspace is a virtual Kubernetes environment. It has:

- **Its own API server endpoint** — a unique URL with its own TLS certificate and kubeconfig
- **Its own resource set** — objects created in one workspace cannot be seen from any other
- **Its own API surface** — the set of resource types (CRDs) available can differ per workspace
- **Its own RBAC** — access grants are scoped within the workspace, not shared across workspaces
- **Its own OIDC issuer** — token validation is workspace-scoped, backed by the organisation's Keycloak realm

KCP stores all workspace state in a shared etcd, but each workspace is logically isolated. The KCP process serves each workspace's API from a single binary — there is no per-workspace API server pod or separate control plane process.

This makes workspaces extremely lightweight. Provisioning a new project workspace is a matter of seconds and requires no additional compute resources proportional to the number of projects.

---

## Workspace Hierarchy in SCO

SCO organises workspaces in a three-level tree:

```
root (platform workspace)
│  Holds: APIExports, platform-level configuration
│
├── org-acme  (organisation workspace)
│   │  Holds: IAM configuration (users, groups, IDP settings)
│   │
│   ├── proj-frontend  (project workspace)
│   │     Holds: APIBindings, consumer claims (VirtualMachine, etc.)
│   │     Endpoint: https://kcp.example.com/clusters/org-acme:proj-frontend
│   │
│   └── proj-backend  (project workspace)
│         Holds: APIBindings, consumer claims
│         Endpoint: https://kcp.example.com/clusters/org-acme:proj-backend
│
└── org-globex  (organisation workspace)
    └── proj-apps
```

**Root workspace:** Owned by the platform team. Hosts `APIExport` resources that declare which API groups are available for consumer workspaces to bind. Also holds the platform workspace template used when provisioning organisation and project workspaces.

**Organisation workspaces:** One per customer or business unit. Hold IAM resources — user and group definitions that are projected into Keycloak realm configuration. Organisation workspaces are not directly accessed by consumers.

**Project workspaces:** One per team or workload environment. These are the consumer-facing endpoints. Each project workspace contains `APIBinding` resources (automatically created by SCO) that import the published API groups from the root workspace, making the service catalogue available as native Kubernetes resource types.

---

## APIExport and APIBinding

### APIExport

An `APIExport` lives in the platform root workspace and declares that a set of Kubernetes resource types is available for other workspaces to consume.

When a platform provider publishes a new service (e.g., `databases.cloud.stakater.com/v1 PostgreSQLDatabase`), an `APIExport` is created for that API group. The export includes:

- The set of resource types included (kinds, versions)
- Permission claims — the access the export's controller (the api-syncagent) requires in consumer workspaces to manage the objects placed there

### APIBinding

An `APIBinding` lives in a project workspace and declares that this workspace should have access to a particular `APIExport`. When a binding is created, KCP makes the exported resource types available as native API types in the workspace.

SCO creates `APIBinding` resources automatically in every project workspace for all published API groups. Consumers do not configure bindings themselves — the APIs simply appear.

When a consumer runs `kubectl api-resources` against their project kubeconfig, they see all bound resource types as if they were built into their cluster.

### How KCP Handles API Requests

When a consumer applies a resource to their project workspace:

1. KCP validates the request against the API schema declared in the `APIExport`
2. KCP stores the object in the workspace's etcd partition
3. KCP notifies the `APIExport`'s virtual workspace endpoint that a new object is present
4. The api-syncagent (watching that virtual workspace) picks up the new object

The object in the consumer workspace is the source of truth for the consumer. Its status, conditions, and connection details are written back to it by the api-syncagent. The consumer never needs to know that the object is being reconciled on a different cluster.

---

## The API Sync Agent

The api-syncagent is the bridge between KCP workspaces and the Crossplane service cluster. For each published API group, a dedicated sync agent process watches the virtual workspace endpoint associated with the `APIExport`.

**Sync flow:**

```
Consumer workspace (project-frontend)
    VirtualMachine claim applied
           │
           ▼
KCP virtual workspace endpoint
    (for compute.cloud.stakater.com APIExport)
           │
           ▼
api-syncagent (watching the virtual workspace)
           │
           ├── Creates: namespace ws-proj-frontend-vms (if not exists)
           ├── Creates: VirtualMachine object in that namespace
           │           (mirroring the consumer's claim)
           │
           ▼
Crossplane composition runs
    Produces: KubeVirt VirtualMachine, DataVolume, Service
           │
           ▼
api-syncagent syncs status back
           │
           ▼
Consumer workspace: VirtualMachine shows Ready
```

**Namespace mapping:** For each consumer workspace, the sync agent creates a dedicated namespace on the service cluster (named after the workspace, with a suffix from the published resource's `namespaceSuffix` parameter). This keeps objects for different consumers physically isolated at the namespace level, even though they arrive through the same api-syncagent process.

**Deletion:** When a consumer deletes their claim, the api-syncagent removes the object from the service cluster namespace. Crossplane's composition engine handles the deletion of all composed resources (VMs, volumes, networking) in the correct dependency order.

---

## Project Workspace Lifecycle

### Provisioning

When a consumer creates a `Project` claim, SCO:

1. Creates the KCP project workspace (child of the organisation workspace)
2. Generates a kubeconfig for the project workspace and makes it available
3. Creates `APIBinding` resources in the project workspace for all published API groups
4. Creates a `Tenant` resource in MTO, triggering namespace, quota, and network policy provisioning
5. Configures RBAC in the workspace based on the project's `access` configuration

The workspace is ready in seconds. The consumer receives a kubeconfig and can immediately begin applying resources.

### Authentication

Each KCP workspace validates tokens against the organisation's Keycloak realm. A consumer authenticates to Keycloak (via OIDC), receives a token scoped to their organisation, and uses that token against their project workspace's API server. KCP validates the token signature against the organisation's realm public key.

RBAC within the workspace controls which resource types a user can interact with and at what permission level.

### Kubeconfig Structure

A project workspace kubeconfig looks like a standard Kubernetes kubeconfig:

```yaml
apiVersion: v1
kind: Config
clusters:
  - name: proj-frontend
    cluster:
      server: https://kcp.example.com/clusters/org-acme:proj-frontend
      certificate-authority-data: <ca-data>
users:
  - name: alice
    user:
      exec:
        # OIDC token exchange via kubelogin / oidc-login
        apiVersion: client.authentication.k8s.io/v1beta1
        command: kubectl
        args: [oidc-login, get-token, ...]
contexts:
  - name: proj-frontend
    context:
      cluster: proj-frontend
      user: alice
```

Standard tools — `kubectl`, ArgoCD, Flux, Terraform — work against this kubeconfig without modification.

### Deletion

When a project is deleted:

1. SCO removes `APIBinding` resources from the workspace (preventing new claims)
2. The api-syncagent completes deletion of all synced objects on the service cluster
3. Crossplane compositions delete all composed resources
4. MTO removes the tenant's namespaces and contained objects
5. KCP deletes the workspace and its etcd partition

Deletion is ordered and safe — infrastructure resources are not deleted until Crossplane confirms their removal.

---

## Scaling Characteristics

KCP's workspace model is designed for high workspace counts. A single KCP instance can serve tens of thousands of workspaces with low per-workspace overhead.

The limiting factors in SCO are:
- **api-syncagent instances:** one per published API group; each scales horizontally
- **Crossplane composition throughput:** scaled by adding provider replicas
- **MTO namespace count:** one namespace set per project; Kubernetes supports tens of thousands of namespaces per cluster

For large deployments, the platform can run multiple KCP instances with workspace routing distributed across them.

---

## What's Next?

- [KCP Integration](../integrations/kcp.md) — Configuration, workspace management, and operator access
- [Publishing APIs](../service-provider-guide/api-publishing/publishing-apis.md) — How to expose a new service through the virtual API layer
- [Components](components.md) — Overview of all platform components
- [Architecture](architecture.md) — Platform layers and design principles
