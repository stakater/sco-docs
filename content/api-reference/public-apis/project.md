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
| `role` | `string` | Role name to bind (e.g., `cluster-admin`, `view`) |
| `users` | `string[]` | List of user identifiers to grant the role |
| `groups` | `string[]` | List of group identifiers to grant the role |

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
      - role: cluster-admin
        groups:
          - platform-admins
        users:
          - alex@acmecorp.example.com
      - role: view
        groups:
          - developers
          - qa-team
```

## How-to Guide

[Create a Project](../../how-to-guides/user/create-project.md)
