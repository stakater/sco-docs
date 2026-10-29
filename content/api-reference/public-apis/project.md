# Project

Creates an isolated project environment with network isolation, resource quota, and role-based access control.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `tenant.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `Project` |
| **Scope** | Namespace-scoped |

## Spec Parameters

All parameters are nested under `spec.parameters`.

### Required

| Field | Type | Description |
|-------|------|-------------|
| `name` | `string` | Project name used for resource naming |
| `network.name` | `string` | Network identifier for the project's isolated network |
| `network.cidr` | `string` | CIDR block for the network (e.g., `10.0.0.0/16`) |

### Optional

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `tenantQuota` | `string` | `small` | Resource quota size for the project (`small`, `medium`, `large`) |
| `access` | `array` | — | List of role-based access entries (see [Access](#access)) |

### Access

Each entry in `spec.parameters.access` defines role bindings for the project:

| Field | Type | Description |
|-------|------|-------------|
| `role` | `string` | Role to grant: `platform-services-admin`, `platform-services-view`, or `<service>-user` / `<service>-viewer` for one service (`compute`, `database`, `kubernetes`, `mesh`, `network`, `secrets`, `storage`). See [Project Roles](../../cloud-user-guide/projects/creating-projects.md#project-roles) |
| `users` | `string[]` | Email addresses of the users to grant the role |
| `groups` | `string[]` | Names of the groups to grant the role |

!!! warning
    `role` is not validated. Any other name is accepted, and if it matches a built-in Kubernetes role such as `edit` or `cluster-admin`, it grants that role in the project, with far broader rights than the SCO roles. Use only the roles listed above.

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.workspaceReady` | `boolean` | Whether the project workspace is ready |
| `status.tenantReady` | `boolean` | Whether the project quota is ready |
| `status.networksReady` | `boolean` | Whether network isolation is ready |
| `status.namespacesReady` | `boolean` | Whether the project namespace is ready |
| `status.allResourcesReady` | `boolean` | Whether all project resources are ready |
| `status.message` | `string` | Human-readable status message |
| `status.workspace.name` | `string` | Project workspace name |
| `status.workspace.url` | `string` | Project workspace API server URL |
| `status.workspace.kubeconfigBase64` | `string` | Base64-encoded kubeconfig for the project |
| `status.openbao.available` | `boolean` | Whether your organisation's Vault is available to this project |
| `status.openbao.address` | `string` | Vault address to sign in to |
| `status.openbao.secretPath` | `string` | The project's folder in the Vault, e.g. `stakater/projects/<organisation>-<project>/` |
| `status.openbao.roles` | `string[]` | Vault roles to sign in with, derived from `access` — see [Vault: Project access](./vault.md#project-access) |
| `status.openbao.message` | `string` | Human-readable Vault access state |

## Examples

### Minimal

```yaml
apiVersion: tenant.cloud.stakater.com/v1
kind: Project
metadata:
  name: my-project
spec:
  parameters:
    name: my-project
    network:
      name: app-network
      cidr: 10.0.0.0/16
```

### Full

```yaml
apiVersion: tenant.cloud.stakater.com/v1
kind: Project
metadata:
  name: team-dev
spec:
  parameters:
    name: team-dev
    network:
      name: dev-network
      cidr: 10.100.0.0/16
    tenantQuota: medium
    access:
      - role: platform-services-admin
        groups:
          - platform-admins
        users:
          - alex@acmecorp.example.com
      - role: platform-services-view
        groups:
          - developers
          - qa-team
```

## How-to Guide

[Create a Project](../../how-to-guides/user/create-project.md)
