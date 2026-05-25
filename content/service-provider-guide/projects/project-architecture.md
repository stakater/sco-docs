# Project Architecture

A project in SCO is a composed environment — it combines a virtual API endpoint with physical tenancy enforcement into a single isolated workspace for a team or workload.

---

## Two-Layer Model

Every project has two distinct layers that work together:

```text
Project: proj-frontend
│
├── Virtual API Layer (KCP workspace)
│   ├── Endpoint: https://kcp.example.com/clusters/org-acme:proj-frontend
│   ├── APIBindings: VirtualMachine, OpenShiftCluster, IAM resources
│   └── Consumer claims live here (what users apply)
│
└── Physical Tenancy Layer (MTO Tenant)
    ├── Namespaces: ws-proj-frontend-vms, ws-proj-frontend-postgresql, ...
    ├── ResourceQuota: CPU, memory, storage limits
    ├── NetworkPolicy: ingress/egress isolation from other projects
    └── RBAC: RoleBindings scoped to tenant namespaces
```

### Virtual API Layer

The KCP workspace gives the project its Kubernetes API endpoint. This is what consumers interact with: they point `kubectl`, ArgoCD, or Terraform at this endpoint and apply claims.

The workspace contains:

- `APIBinding` resources for each published service — making service resource types (e.g., `VirtualMachine`) available as native Kubernetes APIs in the workspace
- Consumer-applied resources (claims): `VirtualMachine`, `OpenShiftCluster`, `PostgreSQLDatabase`, etc.
- Project-scoped RBAC that controls what each user or group can do within the workspace

### Physical Tenancy Layer

The MTO tenant enforces tenancy in the actual cluster. For each project, MTO creates and continuously reconciles:

- **Namespaces** — one namespace per service category (e.g., `ws-proj-frontend-vms`). The `namespaceSuffix` defined in the service's `ApiExport` determines the suffix.
- **ResourceQuota** — compute, memory, and storage limits declared in the project claim, applied per namespace
- **NetworkPolicy** — default-deny ingress from other project namespaces; allow intra-project traffic and egress to platform services
- **RoleBindings** — user and group access from the project's `access` configuration, propagated from the organisation's identity provider

These resources are continuously reconciled. If a namespace is manually deleted, MTO recreates it. If a quota is edited, MTO reverts it.

---

## Namespace Naming

Namespaces for a project follow a deterministic naming pattern:

```text
ws-<project-name>-<namespaceSuffix>
```

For a project named `proj-frontend` with a VirtualMachine service (`namespaceSuffix: vms`):

```text
ws-proj-frontend-vms
```

When the `api-syncagent` syncs a `VirtualMachine` claim from the project workspace, it creates the corresponding object in `ws-proj-frontend-vms` on the service cluster. This keeps objects from different projects physically isolated at the namespace level even when served by the same sync agent process.

---

## Resource Quota Profiles

Projects are provisioned with a quota profile declared in the `Project` claim:

| Profile | CPU request | Memory request | CPU limit | Memory limit |
|---------|-------------|----------------|-----------|--------------|
| `small` | 4 cores | 8 Gi | 8 cores | 16 Gi |
| `medium` | 8 cores | 16 Gi | 16 cores | 32 Gi |
| `large` | 16 cores | 32 Gi | 32 cores | 64 Gi |

Quota profiles are configurable by platform operators via EnvironmentConfig overrides. See [Platform Configuration](../../installation/configuration.md).

---

## Network Isolation

MTO applies network policies at the namespace level:

- **Intra-project traffic:** Allowed — namespaces belonging to the same project can communicate
- **Cross-project traffic:** Denied — network policies block all ingress from namespaces belonging to other projects
- **Platform services:** Allowed — DNS, monitoring, and other platform services are accessible from all project namespaces

---

## RBAC and Access

Access to the project workspace is controlled by the `access` field in the `Project` claim:

| Role | Permissions |
|------|-------------|
| `admin` | Full control — create, update, delete all resources in the project |
| `edit` | Create and manage resources, cannot modify RBAC |
| `view` | Read-only access to all resources in the project |

Group membership from the organisation's identity provider is automatically propagated into Kubernetes role bindings. Adding a user to a group in the IdP grants them the corresponding project access with no manual Kubernetes RBAC update required.

---

## What's Next?

- [Workspace Mapping](workspace-mapping.md) — How virtual workspaces map to physical namespaces in detail
- [Create Project](../../how-to-guides/user/create-project.md) — How to provision a project
- [MTO Integration](../../integrations/mto.md) — Multi-Tenant Operator reference
- [Virtual API Layer](../../architecture/virtual-api-layer.md) — KCP workspace architecture
