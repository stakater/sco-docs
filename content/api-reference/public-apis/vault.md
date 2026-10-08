# Vault

Provisions a private Vault instance for your organisation, with single sign-on against your organisation's identity provider.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `secrets.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `Vault` |
| **Scope** | Namespace-scoped |

## Spec Parameters

All parameters are nested under `spec.parameters`.

### Optional

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `storage.dataSize` | `string` | `15Gi` | Size of the persistent volume for Vault data. |
| `storage.auditSize` | `string` | `10Gi` | Size of the persistent volume for the audit log. |

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.endpoint.address` | `string` | Endpoint URL to point a Vault / OpenBao client at. |
| `status.endpoint.meshAddress` | `string` | Endpoint URL of this Vault on your organisation's [Mesh](./mesh.md). Set once the Mesh endpoint is live; reachable only from enrolled Mesh peers. |

## Authentication

The Vault uses your organisation's single sign-on — there is no static root token to manage. You sign in as your **organisation user**, and you pick a **role** that decides what you can reach. Signing in without a role succeeds but grants nothing.

### Project access

Every project gets its own folder in the organisation's Vault, and the project's [`access`](./project.md#access) entries decide who can use it:

| Project `access` role | Vault access to the project folder |
|---|---|
| `cluster-admin`, `admin`, `edit`, `platform-services-admin`, `secrets-user` | Read and write |
| `view`, `platform-services-view`, `secrets-viewer` | Read only |

Other roles grant no Vault access. The role you sign in with depends on how you were granted access:

| Granted through | Read and write | Read only |
|---|---|---|
| an organisation group in `access[].groups` | `<organisation>-<project>-rw` | `<organisation>-<project>-ro` |
| your user in `access[].users` | `<organisation>-<project>-rw-users` | `<organisation>-<project>-ro-users` |

The project status lists the roles that apply to it, the Vault address and the folder:

```sh
kubectl get project my-project -o jsonpath='{.status.openbao}'
```

```json
{"available":true,"address":"https://bao-acme.apps.example.com","secretPath":"stakater/projects/acme-my-project/","roles":["acme-my-project-rw-users"],"message":"Log in to your organization's OpenBao with OIDC and one of the listed roles"}
```

**Web UI:** open the address, choose method **OIDC**, enter the role in **Role**, and sign in. Browse `stakater` → `projects/` → your project. You can see the other projects' folder names in the list, but not open them.

**CLI:**

```sh
export BAO_ADDR=https://bao-acme.apps.example.com
bao login -method=oidc role=acme-my-project-rw-users
bao kv put -mount=stakater projects/acme-my-project/app/config user=app password=s3cret
bao kv get -mount=stakater projects/acme-my-project/app/config
```

Changes to a project's `access` apply to new sign-ins: removing a user or group revokes their role.

### What the platform keeps in your project folder

| Path (under `stakater/projects/<organisation>-<project>/`) | Written by | Contents |
|---|---|---|
| `vms/<vm>` | the platform | `username` and `password` of the local Administrator it generates for a Windows virtual machine installed without an answer file of your own |
| any path you choose | you | answer files a Windows virtual machine reads through `sysprep.secretPath` (property `autounattend.xml`), and credentials a virtual machine backup reads through `credentials.secretPath` |

A path you give a claim is always **relative to your project folder**: `win/standard` means `stakater/projects/<organisation>-<project>/win/standard`. A claim cannot name a path outside it.

## Access over the Mesh

When your organisation runs a [Mesh](./mesh.md), the platform automatically publishes the Vault to Mesh peers — no extra claim needed. The Mesh endpoint appears in the claim's status as `status.endpoint.meshAddress`:

- It is a stable DNS name (`https://bao.<organisation>.mesh.<cluster-domain>`), served on port 443 with a **publicly-trusted TLS certificate**.
- The name resolves from anywhere, but the Vault is **only reachable from peers enrolled in your organisation's Mesh** — it is never exposed to the public internet.
- Because the certificate is publicly trusted, clients work out of the box: no custom CA bundle, no `-tls-skip-verify`.

From an enrolled laptop:

```sh
export BAO_ADDR=$(kubectl get vault my-vault -o jsonpath='{.status.endpoint.meshAddress}')
bao login -method=oidc role=<organisation>-<project>-rw-users
```

## Examples

### Minimal

```yaml
apiVersion: secrets.cloud.stakater.com/v1
kind: Vault
metadata:
  name: my-vault
spec:
  parameters: {}
```

### Larger storage

```yaml
apiVersion: secrets.cloud.stakater.com/v1
kind: Vault
metadata:
  name: app-vault
spec:
  parameters:
    storage:
      dataSize: 50Gi
      auditSize: 20Gi
```

## How-to Guide

[Create a Vault](../../how-to-guides/user/create-vault.md)

## Related

- [Project](./project.md) — its `access` entries grant Vault access to the project folder (see [Project access](#project-access)).
- [Mesh](./mesh.md) — provisions your organisation's private VPN mesh. With a Mesh present, this Vault is published to Mesh peers automatically (see [Access over the Mesh](#access-over-the-mesh)).
- [MeshRouter](./mesh-router.md) — expose your **own** in-cluster services to Mesh peers the same way the platform exposes this Vault.
