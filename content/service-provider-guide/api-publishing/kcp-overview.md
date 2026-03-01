# KCP: The Virtual API Layer

KCP (Kubernetes Control Plane) is the subsystem that provides every organisation and project in SCO with its own isolated Kubernetes API endpoint. Understanding its model is essential for platform providers who need to expose services to consumers.

---

## The Problem KCP Solves

In a conventional Kubernetes cluster, all tenants share one API server. Separating them requires either namespace-level isolation (limited, shared API surface) or separate physical clusters (expensive, complex to operate).

KCP offers a third model: a single lightweight control plane that serves thousands of **virtual Kubernetes API endpoints** — called workspaces — each fully isolated from the others. From a consumer's perspective, a workspace is indistinguishable from a real cluster. It has its own kubeconfig, its own resources, its own RBAC, and its own API surface. But it runs on shared infrastructure.

SCO uses this to deliver per-project API endpoints without the cost of per-project clusters.

---

## Key Concepts

### Workspaces

A workspace is the fundamental KCP unit of isolation. It is a virtual Kubernetes environment with:

- Its own API server endpoint (a unique kubeconfig URL)
- Its own resource set — objects in one workspace cannot be seen from another
- Its own RBAC — access grants are scoped per workspace
- Its own API surface — different workspaces can expose different resource types

SCO maps workspaces to its own model:

| KCP concept | SCO concept | Scope |
|-------------|-------------|-------|
| Root workspace | Platform | Owned by the platform team |
| Organisation workspace | Organisation | One per customer or business unit |
| Project workspace | Project | One per team or workload |

Consumers receive a kubeconfig for their project workspace and interact with it as they would any cluster. They are not aware of the workspace abstraction — it simply behaves like a Kubernetes cluster.

### `APIExport`

An `APIExport` is how a provider declares that an API group (a set of Kubernetes resource types) is available for use across workspaces.

When the platform defines a new service — for example, a `VirtualMachine` resource under `compute.cloud.stakater.com` — that API is backed by a Crossplane composition on the management cluster. The `APIExport` is the declaration in KCP that says: "this API group exists and can be bound into workspaces".

An `APIExport` lives in a platform workspace and is referenced by name. It carries the API schema, and optionally a set of permission claims that grant the export's controller access to objects in consumer workspaces.

### `APIBinding`

An `APIBinding` is the consumer-side counterpart. It lives in a project workspace and declares that this workspace should have access to a particular `APIExport`.

When a project workspace has an `APIBinding` to `compute.cloud.stakater.com`, the `VirtualMachine` resource type appears natively in that workspace. A consumer can `kubectl apply` a `VirtualMachine` claim, and KCP routes it to the composition engine that fulfils it.

SCO creates `APIBinding` resources automatically when a project is provisioned. Consumers never configure bindings manually.

### PublishedResource and the Sync Agent

The `APIExport` declares an API group in KCP. But KCP needs to know how to actually handle objects of that type — where to create them, how to name them, how to map them to backing infrastructure.

The **`api-syncagent`** is the component that bridges this gap. It:

1. Watches for new objects of the exported type in consumer workspaces
1. Creates corresponding objects on the service cluster (where Crossplane compositions run)
1. Synchronises status and events back to the consumer workspace

This synchronisation is defined through `PublishedResource` objects, which describe the mapping: what kind of object to watch for in KCP workspaces, what namespace to create it in on the service cluster, and any field transformations needed.

Platform providers configure this through the `PublishedOffering` claim described in [Publishing APIs](publishing-apis.md). The sync agent deployment, RBAC, and `PublishedResource` configuration are all created automatically.

---

## How the Pieces Fit Together

The full stack for a provider-defined service:

```text
Platform team defines:
  Crossplane XRD (schema) + Composition (implementation)
                │
                ▼
  PublishedOffering claim applied
                │
                ▼
  SCO provisions:
  ├── PublishedResources     (mapping rules on the service cluster)
  ├── APIExport              (declaration in KCP)
  ├── RBAC                   (permissions for the sync agent)
  └── api-syncagent pod      (the live sync process)
                │
                ▼
  Consumer project workspace:
  └── APIBinding             (auto-created by SCO when project is provisioned)
                │
                ▼
  Consumer applies a VirtualMachine claim
                │
                ▼
  api-syncagent sees the claim → creates object on service cluster
                │
                ▼
  Crossplane composition reconciles → infrastructure provisioned
                │
                ▼
  Status synced back → consumer sees Ready
```

---

## Workspace Hierarchy in Practice

```text
root workspace (platform team)
├── Platform services workspace
│   ├── APIExport: compute.cloud.stakater.com
│   ├── APIExport: kubernetes.cloud.stakater.com
│   └── APIExport: iam.cloud.stakater.com
│
├── org-acme (Organisation workspace)
│   ├── org-acme-frontend (Project workspace)
│   │   ├── APIBinding → compute.cloud.stakater.com  ← auto-created
│   │   ├── APIBinding → kubernetes.cloud.stakater.com
│   │   └── VirtualMachine claim (applied by consumer)
│   └── org-acme-backend (Project workspace)
│       └── ...
│
└── org-globex (Organisation workspace)
    └── ...
```

Organisation workspaces hold IAM configuration. Project workspaces are where consumer workloads live. The platform workspace holds the `APIExport` declarations that all projects bind.

---

## What Providers Need to Know

As a platform provider, you do not interact with KCP directly for routine operations. the SCO automation handles workspace creation, binding setup, and sync agent configuration.

You interact with KCP indirectly through:

- **`PublishedOffering` claims** — to expose a new API group to consumer projects (see [Publishing APIs](publishing-apis.md))
- **`Organization` and `Project` resources** — to provision and manage the workspace hierarchy
- **kubeconfig management** — if you need direct workspace access for debugging

Understanding the KCP model is useful for reasoning about how APIs propagate to consumers, how objects flow between workspaces and the service cluster, and how isolation is enforced at the API layer.

---

## What's Next?

- [Publishing APIs](publishing-apis.md) — Expose a new service API to consumer projects
- [KCP Integration](../../integrations/kcp.md) — Deeper reference on KCP concepts and workspace management
- [Virtual API Layer](../../architecture/virtual-api-layer.md) — Architecture overview
