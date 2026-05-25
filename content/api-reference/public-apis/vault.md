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
| `status.endpoint.address` | `string` | HTTPS endpoint to point a Vault / OpenBao client at. |

## Authentication

The Vault uses your organisation's single sign-on — there is no static root token to manage. To log in as an operator with the OpenBao or Vault CLI:

```sh
bao login -method=oidc
```

This opens your browser, completes login against your organisation's identity provider, and writes a token to the local CLI. Access is scoped by group membership.

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

- [Mesh](./mesh.md) — provisions your organisation's private VPN mesh.
- [NetbirdRouter](./netbird-router.md) — make this Vault reachable from peers on your Mesh without exposing it publicly.
