# NetbirdRouter

Provisions a per-tenant router pod that joins your organisation's NetBird [Mesh](./mesh.md) and advertises one or more in-cluster CIDRs / hosts to peers on the mesh. Use it to give laptops on the mesh routed access to services that don't run a NetBird daemon themselves — Vault, internal HTTP APIs, databases, kube-apiserver IPs, etc.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `netbird.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `NetbirdRouter` |
| **Scope** | Namespace-scoped |

## Spec Parameters

All parameters are nested under `spec.parameters`.

### Required

| Field | Type | Description |
|-------|------|-------------|
| `routes` | `array` | One or more CIDRs / hosts to advertise as NetBird Network Resources behind this router pod. Each entry becomes an `NbNetworkResource` bound to the routers group. |
| `routes[].name` | `string` | Stable identifier for the route (becomes part of the resource's external name). Must be unique within the router. |
| `routes[].address` | `string` | CIDR, host, or domain to advertise. Examples: `172.30.52.51/32`, `10.0.0.0/24`, `example.com`. |

### Optional

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `routes[].description` | `string` | `""` | Human-readable description shown in the dashboard. |
| `routerImage` | `string` | `docker.io/netbirdio/netbird:0.71.4` | Container image for the router pod. Leave default unless pinning to a different agent version. |
| `storageSize` | `string` | `100Mi` | PVC size for `/var/lib/netbird` (holds the WireGuard private key so the pod doesn't re-register on every restart). |
| `storageClassName` | `string` | `""` | Optional StorageClass. Empty means the cluster's default StorageClass. |
| `logLevel` | `string` | `info` | NetBird agent log level (`debug`, `info`, `warn`, `error`). |

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.router.routerPodNamespace` | `string` | Host-cluster namespace where the router Deployment runs (`<tenant>-netbird-router`). |
| `status.router.clientSetupKeySecretRef.name` | `string` | Name of the client setup-key Secret delivered into your project. |
| `status.router.clientSetupKeySecretRef.key` | `string` | Key inside that Secret holding the setup key. |
| `status.router.groups.routers` | `string` | NbGroup ID for the routers group (the router pod itself belongs to this). |
| `status.router.groups.clients` | `string` | NbGroup ID for the clients group (peers you grant access to the routes belong to this). |

## Credentials

When the router is Ready, the platform delivers a Secret named after the claim into the project, carrying the **client setup key**. Give this key to any laptop / VM that should be allowed to reach the advertised routes via the mesh:

```sh
netbird up \
  --management-url=<from your Mesh's status.mesh.mgmtURL> \
  --setup-key=$(kubectl get secret <claim-name> -o jsonpath='{.data.setupKey}' | base64 -d)
```

The peer joins the clients group automatically, which the Mesh's auto-generated policy already allows to reach the routers group.

## Examples

### Single route to a Vault Service

```yaml
apiVersion: netbird.cloud.stakater.com/v1
kind: NetbirdRouter
metadata:
  name: my-router
spec:
  parameters:
    routes:
      - name: vault
        address: 172.30.52.51/32        # Vault Service ClusterIP, /32
        description: "Internal Vault API"
```

After Ready, the peer with the setup key from `status.router.clientSetupKeySecretRef` can curl the Vault's HTTPS API by IP from its laptop.

### Multiple routes

```yaml
apiVersion: netbird.cloud.stakater.com/v1
kind: NetbirdRouter
metadata:
  name: my-router
spec:
  parameters:
    routes:
      - name: vault
        address: 172.30.52.51/32
        description: "Internal Vault API"
      - name: internal-app
        address: 10.128.0.0/14
        description: "Pod network — broad route for ad-hoc debugging"
      - name: corp-domain
        address: example.com
        description: "DNS-based route — daemon resolves and routes"
```

## How it works

The router pod:

- Runs a vanilla NetBird daemon (the same one customers run on laptops) in a Pod with `ip_forward` enabled and `runAsUser: 0` (privileged sysctl).
- Mounts a PersistentVolumeClaim at `/var/lib/netbird` so the WireGuard private key persists across pod restarts — without it, the pod would re-register as a fresh peer every restart and accumulate ghost peers in the dashboard.
- Uses two separate NbGroups and NbSetupKeys so the router itself (`routers` group) and the peers it serves (`clients` group) are tracked independently. A policy `clients → routers` is auto-generated.
- Emits one `NbNetworkResource` per `routes[]` entry, each pointing at the routers group as the advertising router.

## How-to Guide

[Expose an in-cluster Service via the NetBird mesh](../../how-to-guides/user/expose-service-via-netbird.md)

## Related

- [Mesh](./mesh.md) — the per-organisation NetBird control plane this router joins. A Mesh must exist before a NetbirdRouter can register.
- [Vault](./vault.md) — common service to expose via a router.
