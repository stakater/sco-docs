# MeshRouter

Makes one or more in-cluster Services reachable from peers on your organisation's [Mesh](./mesh.md). Use this to give laptops on the Mesh routed access to your own services that don't run a mesh agent themselves — internal APIs, databases, admin UIs, etc. (Platform services such as [Vault](./vault.md) are published to Mesh peers automatically; you don't need a MeshRouter for those.)

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `mesh.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `MeshRouter` |
| **Scope** | Namespace-scoped |

!!! warning "Current limitations"
    A MeshRouter created **inside a project** reports Ready but never joins the Mesh, so its routes are never advertised; a MeshPolicy created inside a project has the same problem. A MeshRouter created with your **organisation** kubeconfig joins the Mesh and advertises its routes, but it runs outside your projects' networks and **cannot reach workloads in your projects** — virtual machines on a project network, or Services inside an OpenShift cluster you provisioned. Until this is fixed you cannot publish your own project workloads with a MeshRouter. The intended way to reach a project virtual machine is the VM's built-in Mesh Route (`spec.parameters.meshRoute.enabled: true` on the [VirtualMachine](./virtual-machine.md)), which opens only SSH (tcp/22), RDP (tcp/3389) and ICMP, and does not deliver traffic yet either.
    <!-- Tracked internally: SA-9272, SA-9273 (SA-8708). Remove this limitation when fixed. -->

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
| `status.router.routerPodNamespace` | `string` | Namespace where the routing peer runs. |
| `status.router.groups.routers` | `string` | ID of the router's peer group — the destination group to reference from access policies. |

## Granting Access

Enrolled devices sign in to the Mesh with your organisation's single sign-on — there are no keys to distribute. Access to the advertised routes is governed by Mesh access policies: the router publishes its routes to a peer group named `<claim-name>-routers`, and you allow your users' groups to reach it with a [MeshPolicy](./mesh-policy.md) claim:

```yaml
apiVersion: mesh.cloud.stakater.com/v1
kind: MeshPolicy
metadata:
  name: allow-devs-to-my-router
spec:
  parameters:
    name: allow-devs-to-my-router
    rules:
      - name: devs-to-routes
        sourceGroupNames:
          - developers            # your users' Mesh group
        destinationGroupNames:
          - my-router-routers     # "<router claim name>-routers"
```

Peers in the source groups can then reach every address the router advertises.

## Examples

### Single route to an internal service

```yaml
apiVersion: mesh.cloud.stakater.com/v1
kind: MeshRouter
metadata:
  name: my-router
spec:
  parameters:
    routes:
      - name: internal-api
        address: 172.30.52.51/32        # a single host, as a /32
        description: "Internal admin API"
```

After Ready (plus a MeshPolicy allowing your group), an enrolled laptop can reach the service by that IP — no public endpoint needed.

### Multiple routes

```yaml
apiVersion: mesh.cloud.stakater.com/v1
kind: MeshRouter
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

[Expose an internal service via the Mesh](../../how-to-guides/user/expose-service-via-mesh.md)

## Related

- [Mesh](./mesh.md) — the Mesh this router joins. A Mesh must exist before a MeshRouter can register.
- [MeshPolicy](./mesh-policy.md) — grants your users' groups access to the router's routes.
- [Vault](./vault.md) — published to Mesh peers automatically; no MeshRouter needed.
