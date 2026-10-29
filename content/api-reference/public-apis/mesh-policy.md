# MeshPolicy

Grants access between groups on your organisation's [Mesh](./mesh.md). Each rule lets peers in one set of groups reach peers in another — for example, letting your developers' laptops reach the routes a [MeshRouter](./mesh-router.md) advertises.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `mesh.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `MeshPolicy` |
| **Scope** | Namespace-scoped |

!!! note "Current limitations"
    A MeshPolicy created **inside a project** does not take effect today: the platform looks for a project-level mesh, but the Mesh belongs to the organisation. Create MeshPolicy claims with your **organisation** kubeconfig, where they are applied to the organisation's Mesh.
    <!-- Tracked internally: SA-9272 (SA-8708). Remove this limitation when fixed. -->

## Spec Parameters

All parameters are nested under `spec.parameters`.

### Required

| Field | Type | Description |
|-------|------|-------------|
| `name` | `string` | Name of the access policy on the Mesh. Shown in the Mesh dashboard. |
| `rules` | `array` | One or more rules. At least one is required. |
| `rules[].name` | `string` | Name of the rule. |
| `rules[].sourceGroupNames` | `array` of `string` | Mesh groups whose peers may open connections. At least one. Your organisation's user groups (for example `org-admin`) are available as Mesh groups once a member has signed in to the Mesh. |
| `rules[].destinationGroupNames` | `array` of `string` | Mesh groups the source peers may reach. At least one. For a MeshRouter, use `<router claim name>-routers`. |

### Optional

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `description` | `string` | `""` | Description of the policy. |
| `enabled` | `boolean` | `true` | Set to `false` to switch the whole policy off without deleting it. |
| `rules[].description` | `string` | `""` | Description of the rule. |
| `rules[].action` | `string` | `accept` | `accept` or `drop`. |
| `rules[].bidirectional` | `boolean` | `true` | Also allow connections from the destination groups back to the source groups. Set to `false` for one-way access. |
| `rules[].enabled` | `boolean` | `true` | Set to `false` to switch one rule off. |
| `rules[].protocol` | `string` | `all` | `all`, `tcp`, `udp` or `icmp`. |
| `rules[].ports` | `array` of `string` | `[]` | Ports to allow, as strings (for example `"22"`, `"443"`). Use together with `protocol: tcp` or `udp`. Leave empty to allow every port. |

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.policy.policyId` | `string` | ID of the policy on the Mesh. The claim becomes Ready once this is set. |
| `status.policy.name` | `string` | Name of the policy on the Mesh. |

## Examples

### Allow a group to reach a MeshRouter

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
          - developers            # your users' group
        destinationGroupNames:
          - my-router-routers     # "<router claim name>-routers"
```

Peers in `developers` can then reach every address `my-router` advertises, on any port.

### Restrict to specific ports, one way

```yaml
apiVersion: mesh.cloud.stakater.com/v1
kind: MeshPolicy
metadata:
  name: admins-https-only
spec:
  parameters:
    name: admins-https-only
    description: "Admins may reach the internal API over HTTPS only"
    rules:
      - name: admins-to-api
        action: accept
        bidirectional: false
        protocol: tcp
        ports:
          - "443"
        sourceGroupNames:
          - org-admin
        destinationGroupNames:
          - my-router-routers
```

### Verify

```bash
kubectl get meshpolicy allow-devs-to-my-router
kubectl get meshpolicy allow-devs-to-my-router -o jsonpath='{.status.policy.policyId}'
```

The claim is Ready once the policy has an ID on the Mesh. The policy also appears in the Mesh dashboard under **Access Control**.
<!-- TODO(SA-8708): confirm the dashboard menu name ("Access Control") on the current NetBird dashboard version. -->

## How-to Guide

[Expose an internal service via the Mesh](../../how-to-guides/user/expose-service-via-mesh.md)

## Related

- [Mesh](./mesh.md) — the Mesh this policy applies to. A Mesh must exist first.
- [MeshRouter](./mesh-router.md) — advertises routes to the `<claim name>-routers` group that a MeshPolicy grants access to.
