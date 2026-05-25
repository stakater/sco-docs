# Vault

Provisions a per-tenant OpenBao instance with HA Raft storage and OIDC authentication wired to your organisation's Keycloak realm.

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
| `storage.dataSize` | `string` | `15Gi` | PVC size for Raft data storage. |
| `storage.auditSize` | `string` | `10Gi` | PVC size for audit log storage. |

## Status Fields

`status.endpoint` carries the address you point a Bao/Vault client at. The instance is OIDC-protected — there is no root token reflected here or delivered as a credential. Operators authenticate via the organisation's Keycloak realm.

| Field | Type | Description |
|-------|------|-------------|
| `status.endpoint.address` | `string` | HTTPS endpoint hostname for the Vault API (e.g. `bao-<tenant>.<cluster-domain>`). Reachable from inside the cluster, from peers on the organisation's NetBird mesh, and from the platform admin VPN. |

## Authentication

The Vault is configured with the **OIDC auth method** bound to your organisation's Keycloak realm — there is no static root token. To log in as an operator:

```sh
bao login -method=oidc
```

This opens your browser, completes Keycloak login, and writes a token to your local Bao/Vault CLI. Tokens are scoped by Keycloak group membership inside the realm.

The OIDC client is registered as a `KeycloakRealmClient` with an embedded audience mapper so the token's `aud` claim matches the Bao OIDC role.

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

## Network reachability

The Vault Service lives on the cluster's default network (lifted out of the project's primary cluster user-defined network) so that the OpenShift router, Crossplane controllers, External Secrets Operator, and your tenant's NetBird router pod can all reach it. A NetworkPolicy clamps ingress to the OpenShift router, intra-namespace pods, and Prometheus / User Workload Monitoring scrapers. An OVN EgressFirewall restricts egress to DNS, RFC1918, and the realm's OIDC discovery host.

External access lands on the cluster's default ingress shard, which on the platform's managed clusters is reachable only from the admin VPN — not the public internet. For end-user access from a laptop, use a [NetbirdRouter](./netbird-router.md) to advertise the Vault Service IP to peers on your organisation's [Mesh](./mesh.md).

## How-to Guide

[Create a Vault](../../how-to-guides/user/create-vault.md)

## Related

- [Mesh](./mesh.md) — provisions the per-organisation NetBird control plane that fronts in-cluster services for external access.
- [NetbirdRouter](./netbird-router.md) — advertises a Vault Service (or any other in-cluster CIDR / host) to peers on the Mesh.
