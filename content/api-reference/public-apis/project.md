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
| `network.cidr` | `string` | CIDR block for the network (e.g., `10.0.0.0/16`). Required when `network.mode` is `udn`. Choose a range that does not overlap another project in your organisation |

### Optional

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `network.mode` | `string` | `udn` | How the project is networked. See [Network Modes](#network-modes) |
| `network.name` | `string` | `default` | Name of the project's network. Only used in `udn` mode |
| `network.externalRef` | `string` | — | Name of the external network assigned to your organisation. Required when `network.mode` is `external` |
| `tenantQuota` | `string` | `small` | Resource quota size for the project (`small`, `medium`, `large`) |
| `access` | `array` | — | List of role-based access entries (see [Access](#access)) |

### Network Modes

| Mode | What the project gets | Use it when |
|------|-----------------------|-------------|
| `udn` (default) | Its own isolated network, addressed from `network.cidr` | Virtual machines and services only need to reach each other inside the project |
| `native` | The platform's shared cluster network, with every project resource closed to traffic from outside the project by default | Virtual machines must be reachable from this project's OpenShift clusters, using [`peers`](./virtual-machine.md#peers) |
| `external` | An external network assigned to your organisation, named by `network.externalRef` | Your organisation has been assigned an external network |

!!! note
    A project cannot change to or from `udn` after it is created. To move virtual machines between the two, create a new project with the mode you need.

In both `udn` and `native` mode, people in your organisation can still reach the project's virtual machines over your organisation mesh.

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

### Native Network

A project whose virtual machines can be reached from its OpenShift clusters. `network.cidr` is not needed.

```yaml
apiVersion: tenant.cloud.stakater.com/v1
kind: Project
metadata:
  name: app-platform
spec:
  parameters:
    name: app-platform
    network:
      mode: native
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

- [Create a Project](../../how-to-guides/user/create-project.md)
- [Connect an OpenShift Cluster to a Virtual Machine](../../how-to-guides/user/connect-openshift-cluster-to-virtual-machine.md)
