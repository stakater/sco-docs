# KCP

KCP (Kubernetes Control Plane) is the virtual API layer at the heart of SCO. It provides every organisation and project with its own isolated Kubernetes API endpoint — without running a separate cluster for each.

---

## What KCP Does

A standard Kubernetes cluster has a single API server shared by all users. KCP inverts this: it runs one lightweight control plane that can serve thousands of independent, isolated API surfaces called **workspaces**. Each workspace behaves like a dedicated cluster to its owner, but shares the underlying infrastructure.

SCO uses KCP to give every organisation and every project within that organisation its own workspace. From a consumer's perspective, their project is a Kubernetes cluster with its own endpoint, its own resources, and its own access control. They have no visibility into any other tenant's workspace.

---

## KCP Nomenclature and SCO Mapping

KCP has its own terminology. SCO maps these concepts to the platform vocabulary consumers see:

| KCP concept | SCO equivalent | Description |
|-------------|---------------|-------------|
| **Workspace** | Organisation / Project | A virtual, isolated Kubernetes API environment |
| **Root workspace** | Platform root | The top-level workspace owned by the platform team |
| **Organisation workspace** | Organisation | A workspace per customer or business unit |
| **Project workspace** | Project | A workspace per team or workload; child of an organisation |
| **`APIExport`** | Service API | A provider publishes an API that consumers can bind to |
| **`APIBinding`** | Project capability | A project binds to an exported API to gain access to a service |
| **`APIResourceSchema`** | API schema | The OpenAPI schema for a virtual API type |
| **Virtual workspace** | (internal) | The dynamically generated endpoint serving an `APIExport` |
| **`SyncTarget`** | (internal) | Maps workspace resources to a physical cluster for scheduling |

!!! note
    Consumers interact with projects and organisations through the SCO platform, never directly with KCP workspaces or their raw APIs. The mapping above is relevant for platform operators and administrators.

---

## Workspace Hierarchy

SCO organises workspaces in a tree:

```text
root workspace (platform)
├── org-acme            ← Organisation workspace (Org A)
│   ├── proj-frontend   ← Project workspace (Team A)
│   ├── proj-backend    ← Project workspace (Team B)
│   └── proj-data       ← Project workspace (Team C)
└── org-globex          ← Organisation workspace (Org B)
    ├── proj-infra
    └── proj-apps
```

- **Organisation workspaces** hold IAM configuration (users, groups, identity provider settings) and act as a namespace for projects.
- **Project workspaces** are where consumers work. Each project workspace has its own kubeconfig endpoint, RBAC, and network isolation. Consumers `kubectl apply` claims into their project workspace exactly as they would into a real cluster.

---

## Virtual API Layer: How KCP Serves APIs to Projects

The key KCP capability is the ability to publish APIs from one workspace and have them appear as native Kubernetes APIs in another workspace. SCO uses this to deliver the service catalogue to consumers.

### `APIExport` and `APIBinding`

When the platform team defines a service — say, a `VirtualMachine` claim — SCO publishes that API through an `APIExport` in the platform's root workspace. The exported API becomes available for any project to bind.

When a project is created, SCO automatically creates `APIBinding` resources inside that project's workspace. These bindings import the exported APIs into the project, making them available as first-class Kubernetes resource types. A consumer in that project can then `kubectl apply` a `VirtualMachine` claim with no additional configuration.

```text
Platform root workspace
  └── APIExport: compute.cloud.stakater.com/v1 VirtualMachine

Project workspace (proj-frontend)
  └── APIBinding → compute.cloud.stakater.com
      └── Available resource: VirtualMachine (v1)
```

When a consumer runs `kubectl get virtualmachines`, KCP intercepts the request, routes it through the virtual workspace backing the `APIExport`, and Crossplane reconciles it. The consumer never knows this indirection exists.

### What this means for providers

Providers define APIs once in the platform workspace. KCP propagates them to all project workspaces through bindings. Changes to the API (new versions, schema updates) are managed through standard Crossplane XRD versioning and published via the `APIExport`. No per-project configuration is required.

---

## Managing the Workspace Tree

Platform operators interact with KCP using `kubectl` with a kubeconfig pointing at the root workspace (or an appropriate administrative workspace).

**List organisations (top-level workspaces):**

```bash
kubectl get workspaces
```

**Inspect a workspace:**

```bash
kubectl get workspace org-acme -o yaml
```

**List available API exports:**

```bash
kubectl get apiexports
```

**Inspect what APIs are bound in a project:**

```bash
# Switch to the project workspace kubeconfig
kubectl get apibindings
```

---

## How SCO Automates KCP

Platform operators do not manage KCP workspaces or bindings directly in normal operation. the SCO controllers handle the full lifecycle:

- When a **Organisation** is created, SCO creates the corresponding KCP workspace hierarchy and configures IAM.
- When a **Project** is created, SCO creates the project workspace, applies the appropriate `APIBinding` resources, and sets up network isolation and quota.
- When a project is deleted, SCO tears down the workspace and its contained resources in the correct order.

Direct KCP management is only needed for platform-level configuration: publishing new `APIExport` definitions, managing workspace templates, or troubleshooting workspace state.

---

## What's Next?

- [Virtual API Layer](../architecture/virtual-api-layer.md) — Architecture deep dive
- [Publishing APIs](../service-provider-guide/api-publishing/publishing-apis.md) — How to publish a new service API
- [Crossplane Integration](crossplane.md) — How Crossplane backs the APIs KCP serves
