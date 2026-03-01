# Workspace Mapping

This page describes the precise relationship between a consumer-facing project, the underlying KCP workspace, and the physical Kubernetes namespaces managed by MTO.

---

## The Mapping

Every SCO project maps to exactly one KCP workspace and one MTO Tenant. These three are created together and deleted together:

```text
Project claim (tenant.cloud.stakater.com/v1 Project)
        │
        ├──► KCP Workspace
        │    └── Virtual Kubernetes API endpoint
        │        Project consumers interact here
        │
        └──► MTO Tenant
             └── Physical namespaces (one per service type)
                 Actual resources live here
```

The `Project` claim is the single source of truth. Changes to the claim — updated quota, changed access, new network configuration — flow through to both the KCP workspace and the MTO Tenant.

---

## KCP Workspace Details

The KCP workspace for a project is a child of its organisation workspace:

```text
Organisation workspace:  org-acme
Project workspace:        org-acme:proj-frontend
Endpoint URL:             https://kcp.example.com/clusters/org-acme:proj-frontend
```

Within the workspace, SCO automatically creates `APIBinding` resources for all published service APIs. The available resource types in every project workspace are determined by the platform's published `APIExport` set — project administrators do not configure bindings manually.

When a new service is published to the platform, its `APIBinding` is added to all existing project workspaces as part of the platform's reconciliation loop.

---

## MTO Tenant Details

The MTO Tenant for a project defines the physical namespace structure. For a project named `proj-frontend` in organisation `org-acme`, with published services for VMs (`vms`) and PostgreSQL (`postgresql`):

```text
Namespace: ws-proj-frontend-vms
  Labels:
    stakater.com/tenant: proj-frontend
    stakater.com/org: org-acme
  ResourceQuota: (from project quota profile)
  NetworkPolicy: (MTO-managed, intra-tenant allow / cross-tenant deny)

Namespace: ws-proj-frontend-postgresql
  Labels:
    stakater.com/tenant: proj-frontend
    stakater.com/org: org-acme
  ResourceQuota: (from project quota profile)
  NetworkPolicy: (MTO-managed)
```

New namespaces are added automatically when new service types are published to the platform — MTO's Tenant reconciliation loop picks them up.

---

## How Claims Flow Through the Stack

When a consumer applies a `VirtualMachine` claim to their project workspace:

1. KCP stores the claim in the project workspace's etcd partition
1. The api-syncagent (watching the virtual workspace for the `compute.cloud.stakater.com` API export) detects the new object
1. The api-syncagent creates a mirrored object in `ws-proj-frontend-vms` on the service cluster
1. Crossplane's composition pipeline runs, creating KubeVirt resources in `ws-proj-frontend-vms`
1. The api-syncagent copies status back to the original claim in the KCP workspace

The consumer sees their claim move from `Provisioning` to `Ready`. The physical resources live in `ws-proj-frontend-vms`. The consumer has no access to that namespace — they interact only through the project workspace endpoint.

---

## Deletion Ordering

When a project is deleted, SCO ensures a safe teardown:

1. `APIBinding` resources removed from workspace — prevents new claims
1. api-syncagent propagates deletions to service cluster namespaces
1. Crossplane composition pipelines delete composed resources in correct dependency order
1. MTO Tenant deleted — namespaces and contained objects removed
1. KCP workspace deleted — etcd partition purged

Monitor deletion progress:

```bash
kubectl get project proj-frontend -o jsonpath='{.status.conditions}'
```

---

## What's Next?

- [Project Architecture](project-architecture.md) — Two-layer isolation model
- [Virtual API Layer](../../architecture/virtual-api-layer.md) — KCP workspace internals
- [MTO Integration](../../integrations/mto.md) — Tenant lifecycle and namespace management
