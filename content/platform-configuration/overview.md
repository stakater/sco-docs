# Platform Configuration APIs

Tune the platform with typed, validated resources that you commit to your GitOps repository.

!!! note "New in the next release"
    The platform configuration APIs ship with the [next release](../release-notes/next-release.md), which is not released yet.

## What They Are

A platform configuration API is a cluster-scoped kind in the API group `config.platform.stakater.com`, one kind per area of the platform. Each kind has a single object, named `cluster`, on the cluster that runs the platform.

| Kind | API version | Area | Reference |
|------|-------------|------|-----------|
| `NetworkingConfig` | `config.platform.stakater.com/v1alpha1` | Network isolation and egress rules of platform namespaces | [NetworkingConfig](networking-config.md) |

More kinds will follow for other areas of the platform.

## How Settings Are Applied

Platform settings come from four layers. A higher layer wins over a lower one:

| Layer | Set by |
|-------|--------|
| 1. Chart defaults | The platform |
| 2. Release defaults | The platform release you installed |
| 3. **Platform configuration APIs** | You, for example in `NetworkingConfig` |
| 4. Override `EnvironmentConfig` objects | You, as a last resort. See [Platform Configuration](../installation/configuration.md) |

A platform configuration API applies **only the values you set**. A value you leave unset keeps the release default, and a later release can change that default. Unsetting a value, or deleting the object, returns to the release default.

Prefer a platform configuration API over an override `EnvironmentConfig` whenever one covers the setting: it is validated by the API server, it has a published schema, and it does not pin a component's values against later releases.

## Availability

- Available on every platform variant (`hosting` and `scobasic`).
- A day-2 setting: it has no effect on installation. Apply it after `ksp up` has completed.
- The object must be named `cluster`. Any other name is rejected when it is created.

## Access

Each kind comes with two ClusterRoles. The platform binds neither of them, and neither is part of the built-in `admin`, `edit`, `view` or `cluster-reader` roles, so only cluster administrators have access until you bind them.

| ClusterRole | Grants |
|-------------|--------|
| `platform-config-networking-admin` | `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`, `deletecollection` on `networkingconfigs`, and `get` on their status |
| `platform-config-networking-view` | `get`, `list`, `watch` on `networkingconfigs` and their status |

To let a group manage `NetworkingConfig`, bind the admin role to it:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: networking-admins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: platform-config-networking-admin
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: <your-network-admins-group>
```

## Workflow

1. Write the object in your GitOps repository, next to your other platform configuration.
1. Validate it in CI against the JSON Schema of its kind (see the kind's reference page).
1. Raise a pull request, review and merge it. Your GitOps tool applies it.
1. Read the object's `status`, which reports the value that applies to each platform component and the level that set it.

## What's Next?

- [NetworkingConfig](networking-config.md) — Network isolation and egress rules for platform namespaces
- [Platform Configuration](../installation/configuration.md) — Override `EnvironmentConfig` objects, for settings no platform configuration API covers yet
- [Release Notes](../release-notes/index.md) — What changes in each release
