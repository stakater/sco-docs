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

Each entry in `spec.parameters.access` grants one role to the listed users and groups. `access` holds at most 50 entries.

| Field | Type | Description |
|-------|------|-------------|
| `role` | `string` | Role to grant. Use a platform role: `platform-services-admin`, `platform-services-view`, or `<service>-user` / `<service>-viewer` for one service (`compute`, `database`, `kubernetes`, `mesh`, `network`, `secrets`, `storage`). See [Project Roles](../../cloud-user-guide/projects/creating-projects.md#project-roles) |
| `users` | `string[]` | Email addresses of the people to grant the role, the address each person signs in with, for example `jane.doe@example.com`. Only email addresses are accepted. At most 100 |
| `groups` | `string[]` | Names of groups in your organisation, exactly as each group was created (its `metadata.name`), for example `platform-team`. Display names are not accepted. At most 100 |

The platform rejects a value in `users` that is not an email address, and a value in `groups` that is not a group name: only lowercase letters, digits, `-` and `.`, starting and ending with a letter or digit.

Mesh and virtual machine access (SSH, RDP) follows **groups only**: groups with the `compute-user`, `admin` or `cluster-admin` role get it. People listed in `users` get the project and its secrets, but not mesh or virtual machine access; grant that through a group.

!!! warning
    `role` is not validated. The console offers the platform roles first, and the built-in Kubernetes roles `cluster-admin`, `admin`, `edit` and `view` last, labelled *unrestricted*. A built-in role grants far broader rights in the project than any platform role, for example to create and delete Secrets or change who has access. A name that matches no role is accepted and grants nothing. Use the platform roles.

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
