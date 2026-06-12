# NetbirdRouter

Makes one or more in-cluster Services reachable from peers on your organisation's [Mesh](./mesh.md). Use this to give laptops on the Mesh routed access to your own services that don't run a NetBird daemon themselves — internal APIs, databases, admin UIs, etc. (Platform services such as [Vault](./vault.md) are published to Mesh peers automatically; you don't need a NetbirdRouter for those.)

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
| `routes` | `array` | One or more entries describing what to advertise via the Mesh. |
| `routes[].name` | `string` | Stable identifier for the route. Must be unique within the router. |
| `routes[].address` | `string` | CIDR, host, or domain to advertise. Examples: `172.30.52.51/32`, `10.0.0.0/24`, `example.com`. |

### Optional

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `routes[].description` | `string` | `""` | Description shown in the Mesh dashboard. |
| `storageSize` | `string` | `100Mi` | Persistent storage size for the router's state. |
| `storageClassName` | `string` | `""` | Storage class. Empty means the cluster's default. |
| `logLevel` | `string` | `info` | Agent log level (`debug`, `info`, `warn`, `error`). |

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.router.clientSetupKeySecretRef.name` | `string` | Name of the Secret containing the client setup key (see [Credentials](#credentials)). |
| `status.router.clientSetupKeySecretRef.key` | `string` | Key inside that Secret. |

## Credentials

When the router is Ready, a Secret named after the claim is delivered into your project. It contains the **client setup key** — share this with any laptop or VM that should be allowed to reach the advertised routes via the Mesh:

```sh
netbird up \
  --management-url=<your organisation's management URL> \
  --setup-key=$(kubectl get secret <claim-name> -o jsonpath='{.data.setupKey}' | base64 -d)
```

The peer is auto-allowed to reach the routes; no additional dashboard configuration needed.

## Examples

### Single route to an internal service

```yaml
apiVersion: netbird.cloud.stakater.com/v1
kind: NetbirdRouter
metadata:
  name: my-router
spec:
  parameters:
    routes:
      - name: internal-api
        address: 172.30.52.51/32        # ClusterIP of the Service, /32
        description: "Internal admin API"
```

After Ready, a laptop with the setup key can reach the service by that IP — no public endpoint needed.

### Multiple routes

```yaml
apiVersion: netbird.cloud.stakater.com/v1
kind: NetbirdRouter
metadata:
  name: my-router
spec:
  parameters:
    routes:
      - name: internal-api
        address: 172.30.52.51/32
        description: "Internal admin API"
      - name: internal-app
        address: 10.0.5.0/24
        description: "Internal app subnet"
      - name: corp-domain
        address: example.com
        description: "DNS-based route"
```

## How-to Guide

[Expose an internal service via the Mesh](../../how-to-guides/user/expose-service-via-netbird.md)

## Related

- [Mesh](./mesh.md) — the Mesh this router joins. A Mesh must exist before a NetbirdRouter can register.
- [Vault](./vault.md) — published to Mesh peers automatically by the platform; no NetbirdRouter needed.
