# Mesh

Provisions a private WireGuard mesh for your organisation — management, signalling, and a web dashboard. Use it to securely connect laptops, virtual machines, and in-cluster services without exposing anything to the public internet.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `network.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `Mesh` |
| **Scope** | Namespace-scoped |

## Spec Parameters

`spec.parameters` is currently empty. The Mesh takes no user-tunable fields in v1. You configure networks, groups, and policies via the dashboard once the Mesh is ready.

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.mesh.dashboardURL` | `string` | URL of the Mesh dashboard. Log in with your organisation's single sign-on. |
| `status.mesh.mgmtURL` | `string` | Management endpoint that peers connect to (e.g. `netbird up --management-url=<this>`). |
| `status.mesh.signalURL` | `string` | Signalling endpoint. Used internally; you don't usually pass it explicitly. |
| `status.mesh.providerConfigName` | `string` | Name of the per-organisation provider configuration. Reference this if you'd rather manage groups and policies declaratively (see [example below](#defining-a-group-declaratively)). |

## Authentication

Both the dashboard and the management endpoint use your organisation's single sign-on. There is no separate username or password issued by the platform.

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

That's the entire claim. Once Ready, open `status.mesh.dashboardURL` in a browser to log in, generate setup keys, define groups, and write policies.

### Joining a laptop

Install the NetBird daemon on the laptop, then run:

```sh
netbird up \
  --management-url=$(kubectl get mesh my-mesh -o jsonpath='{.status.mesh.mgmtURL}')
```

This opens a browser for single sign-on. After registration, the peer appears in the dashboard and you can assign it to groups.

### Defining a Group declaratively

If you prefer YAML over the dashboard, target the per-organisation provider config from `status.mesh.providerConfigName`:

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

The same pattern applies to `NbPolicy`, `NbSetupKey`, and `NbNetworkResource` resources.

## How-to Guide

[Create a Mesh](../../how-to-guides/user/create-mesh.md)

## Related

- [NetbirdRouter](./netbird-router.md) — make in-cluster Services reachable from peers on this Mesh.
- [Vault](./vault.md) — common pattern: expose a Vault via a NetbirdRouter so peers reach it from their laptop without it being on the public internet.
