# Mesh

Provisions a per-tenant NetBird control plane (management + signal + dashboard) so your organisation can build a WireGuard mesh covering laptops, VMs, in-cluster services, and anything else that runs the NetBird daemon.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `network.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `Mesh` |
| **Scope** | Namespace-scoped |

## Spec Parameters

`spec.parameters` is currently empty. v1 takes no user-tunable fields — every value (mesh URL hostnames, OIDC client wiring, relay reference) is derived from platform configuration. You carve up the mesh into Networks, Groups, and Policies via the dashboard or by creating NetBird Crossplane resources against the per-org [ProviderConfig](#status-fields) this composition wires up.

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.mesh.dashboardURL` | `string` | NetBird dashboard URL (HTTPS). Log in via Keycloak SSO from your organisation's realm. |
| `status.mesh.mgmtURL` | `string` | NetBird management gRPC URL (HTTPS, port 443). Configure peers with `netbird up --management-url=<this>`. |
| `status.mesh.signalURL` | `string` | NetBird signal gRPC URL (HTTPS, port 443). Used by the management URL configuration; you don't usually pass it explicitly. |
| `status.mesh.providerConfigName` | `string` | Name of the per-organisation NetBird Crossplane ProviderConfig. Downstream resources (e.g. [NetbirdRouter](./netbird-router.md), `NbGroup`, `NbPolicy`, `NbSetupKey`) reference this to scope themselves to this mesh. |

## Authentication

The dashboard and the management gRPC endpoint are both OIDC-protected against your organisation's Keycloak realm. There is no separate username/password issued by the platform — operators and end users log in with their existing organisation identity.

## Examples

### Minimal

```yaml
apiVersion: network.cloud.stakater.com/v1
kind: Mesh
metadata:
  name: my-mesh
spec:
  parameters: {}
```

That's the entire claim. Once Ready, open `status.mesh.dashboardURL` in a browser to log in, generate setup keys, define groups + policies, etc.

### Joining a laptop

After the Mesh is Ready, install the NetBird daemon on the laptop and join via SSO:

```sh
# macOS / Linux
netbird up \
  --management-url=$(kubectl get mesh my-mesh -o jsonpath='{.status.mesh.mgmtURL}')
# Opens a browser for OIDC login against your Keycloak realm.
```

After registration the peer appears in the dashboard, where you assign it to groups and policies.

### Defining a Group via Crossplane (optional)

If you'd rather manage groups + policies declaratively rather than via the dashboard, target the per-org ProviderConfig that the Mesh wired up:

```yaml
apiVersion: netbird.io/v1alpha1
kind: NbGroup
metadata:
  name: laptops
spec:
  forProvider:
    name: laptops
  providerConfigRef:
    name: <value of status.mesh.providerConfigName>
```

## Network reachability

`mgmtURL` and `signalURL` are served by a NetBird gRPC stack that needs HTTP/2 ALPN end-to-end. The platform exposes them via MetalLB-backed LoadBalancer Services rather than OpenShift Routes — on the managed clusters this lands on an externally-routable IP from the BGP-advertised pool. On enterprise self-hosted clusters, the same LoadBalancer Service lands on whichever IPAddressPool the cluster operator has configured (typically a private internal pool).

`dashboardURL` is served over HTTP/1.1 + TLS via a regular OpenShift edge Route.

## How-to Guide

[Create a Mesh](../../how-to-guides/user/create-mesh.md)

## Related

- [NetbirdRouter](./netbird-router.md) — advertise in-cluster Services / CIDRs to peers on the Mesh.
- [Vault](./vault.md) — common access pattern: advertise the Vault Service via a NetbirdRouter so peers reach `bao` from their laptop without exposing it to the internet.
