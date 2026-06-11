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

## Authentication

The Vault uses your organisation's single sign-on — there is no static root token to manage. To log in as an operator with the OpenBao or Vault CLI:

```sh
bao login -method=oidc
```

This opens your browser, completes login against your organisation's identity provider, and writes a token to the local CLI. Access is scoped by group membership.

## Access over the Mesh

When your organisation runs a [Mesh](./mesh.md), the platform automatically publishes the Vault to Mesh peers — no extra claim needed:

- The Vault gets a stable DNS name of the form `bao.<organisation>.mesh.<cluster-domain>`, served on standard HTTPS (port 443) with a **publicly-trusted TLS certificate**.
- The name resolves from anywhere, but the Vault is **only reachable from peers enrolled in your organisation's Mesh** — it is never exposed to the public internet.
- Because the certificate is publicly trusted, clients work out of the box: no custom CA bundle, no `-tls-skip-verify`.

From an enrolled laptop:

```sh
export BAO_ADDR=https://bao.<organisation>.mesh.<cluster-domain>
bao login -method=oidc
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

- [Mesh](./mesh.md) — provisions your organisation's private VPN mesh. With a Mesh present, this Vault is published to Mesh peers automatically (see [Access over the Mesh](#access-over-the-mesh)).
- [NetbirdRouter](./netbird-router.md) — expose your **own** in-cluster services to Mesh peers the same way the platform exposes this Vault.
