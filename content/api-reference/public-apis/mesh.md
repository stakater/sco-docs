# Mesh

Provisions a private mesh network for your organisation — management, signalling, and a web dashboard. Use it to securely connect laptops, virtual machines, and in-cluster services without exposing anything to the public internet.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `network.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `Mesh` |
| **Scope** | Namespace-scoped |

## Spec Parameters

`spec.parameters` is currently empty. The Mesh takes no user-tunable fields in v1. You configure networks, groups, and policies via the dashboard or the Mesh claims once the Mesh is ready.

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.mesh.dashboardURL` | `string` | URL of the Mesh dashboard. Log in with your organisation's single sign-on. |
| `status.mesh.mgmtURL` | `string` | Management endpoint that peers connect to (e.g. `netbird up --management-url=<this>`). |
| `status.mesh.signalURL` | `string` | Signalling endpoint. Used internally; you don't usually pass it explicitly. |

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

That's the entire claim. Once Ready, open `status.mesh.dashboardURL` in a browser to log in, define groups, and write policies.

### Joining a laptop

Install the NetBird daemon on the laptop, then run:

```sh
# copy the exact command from the Mesh dashboard's "Add Peer" dialog
netbird up --management-url=<your organisation's management URL>
```

This opens a browser for single sign-on. After registration, the peer appears in the dashboard and you can assign it to groups.

### Managing groups, policies, and setup keys

Manage them declaratively with claims in the same API group — `MeshGroup`, `MeshPolicy`, `MeshRoute`, and `MeshSetupKey` — or interactively in the Mesh dashboard at `status.mesh.dashboardURL`.

## Platform services over the Mesh

Platform-provisioned services in your organisation are published to Mesh peers automatically. A [Vault](./vault.md), for example, gets a stable DNS name (`bao.<organisation>.mesh.<cluster-domain>`) served with a publicly-trusted TLS certificate — reachable only from enrolled peers, with no extra claims or dashboard configuration. To expose your **own** services the same way, use a [MeshRouter](./mesh-router.md).

## How-to Guide

[Create a Mesh](../../how-to-guides/user/create-mesh.md)

## Related

- [MeshRouter](./mesh-router.md) — make your own in-cluster Services reachable from peers on this Mesh.
- [Vault](./vault.md) — published to Mesh peers automatically when your organisation runs a Mesh.
