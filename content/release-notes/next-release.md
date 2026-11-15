# Next Release (unreleased)

!!! warning "Draft"
    This release has no version yet and is not available. Its content and component versions can still change. Versions shown as **TBD** are not released yet. When the version is assigned, this page moves to `release-notes/<version>.html` and the JSON file to `release-notes/<version>.json`.

Machine-readable form: [`next-release.json`](next-release.json) (`status: draft`).

## Highlights

- **New: platform configuration APIs.** Tune the platform with typed, validated resources in `config.platform.stakater.com/v1alpha1`. The first is `NetworkingConfig`, for network isolation and egress rules of platform namespaces.
- **Project access is easier to fill in, and validated.** The console offers the project roles as a select with descriptions. `users` accepts email addresses only and `groups` group names only. **Breaking: check your Projects before you upgrade.**
- **Project network mode** offers only the modes your platform supports, with descriptions.
- **Initial passwords** of new users and of the organisation administrator are masked in the console, with reveal and copy.
- **Groups:** the unused `attributes` field is no longer offered in the console.
- **Fix:** the organisation Vault no longer reports a failed setup job on upgrade.

## Component Versions

| Component | Type | Version | Change |
|-----------|------|---------|--------|
| `NetworkingConfig` API (`networking-config`) | Crossplane package | TBD | New |
| Platform configuration APIs (`sco-package-platform-config`) | Helm chart | TBD | New. Installs the platform configuration APIs, their roles and the name policy |
| `network-policy-base` | Helm library chart | TBD | New. Network isolation for platform namespaces, used by the charts below |
| `forecastle` | Helm chart | TBD | Supports network isolation and egress rules, off by default |
| `Project` API (`project.tenant.cloud.stakater.com`) | Crossplane package | TBD | Validates `access[].users` and `access[].groups` |
| Project console catalogue (`crossplane-package-kcp`) | Helm chart | TBD | Select lists for `access[].role` and `network.mode` |
| `User` API (`user.iam.cloud.stakater.com`) | Crossplane package | TBD | Initial password marked as secret |
| `Group` API (`group.iam.cloud.stakater.com`) | Crossplane package | TBD | `attributes` hidden in the console; `members` described |
| `Organization` and `OrgOnboarding` APIs (`infrastructure.stakater.com`) | Crossplane packages | TBD | Initial administrator password marked as secret |
| Organisation Vault (`openbao`) | Helm chart | 0.0.74 | Setup job fix. The package that delivers it to organisations: TBD |
| Console | Container image | TBD | Masked secret values; select lists limited to the values the platform offers |

### Upgrade Paths

| From | To this release | Notes |
|------|-----------------|-------|
| TBD (the previous platform release) | Supported | Do the [actions before upgrading](#before-you-upgrade) first |

## Breaking Changes

### Project access accepts only email addresses and group names

**What changes.** The `Project` API validates each entry of `spec.parameters.access`:

| Field | Accepted | Example |
|-------|----------|---------|
| `users[]` | An email address: one `@`, a dot in the domain, no spaces, commas or colons. At most 254 characters | `jane.doe@example.com` |
| `groups[]` | A group name as created in the organisation: lowercase letters, digits, `-` and `.`, starting and ending with a letter or digit. At most 253 characters | `platform-team` |
| `access` | At most 50 entries | |
| `users`, `groups` | At most 100 items per entry | |

Both fields still accept an optional `oidc:` prefix.

**Who is affected.** Projects whose `users` hold a name or username instead of an email address, or whose `groups` hold a display name, capitals, spaces or commas. Such values never granted access: a user is matched by email address and a group by its name. The project keeps running, but it can be rejected when it is next changed, from `kubectl` or from the console.

#### Before you upgrade

Ask each organisation administrator to run this check with their organisation kubeconfig (it needs `kubectl` and `jq`). It prints every value the new validation rejects:

```bash
kubectl get projects -A -o json | jq -r '
  .items[] | .metadata.name as $p | (.spec.parameters.access // [])[] |
  ( (.users  // [])[] | select(test("^(oidc:)?[^@\\s,:]+@[^@\\s,]+\\.[^@\\s,]+$") | not) | "\($p)\tusers\t\(.)" ),
  ( (.groups // [])[] | select(test("^(oidc:)?[a-z0-9]([-a-z0-9.]*[a-z0-9])?$")   | not) | "\($p)\tgroups\t\(.)" )'
```

For each line printed, edit the project:

- `users`: replace the value with the email address the person signs in with. For a username from a `User` claim, use that claim's `spec.parameters.email`.
- `groups`: replace the value with the group's name, its `metadata.name` (`kubectl get groups`).

No output means no project is affected. A project with more than 50 `access` entries, or more than 100 users or 100 groups in one entry, is also rejected; split such entries, or grant access through groups.

#### After you upgrade

1. Check that every project is ready: `kubectl get projects -A` shows `READY` `True`.
1. Open a project in the console and save it without changes. It saves without a validation error.

## Configuration and API Changes

### Added

| Interface | Details |
|-----------|---------|
| `config.platform.stakater.com/v1alpha1`, kind `NetworkingConfig` | Cluster-scoped, one object named `cluster`. Network isolation and egress rules for platform namespaces. See [NetworkingConfig](../platform-configuration/networking-config.md) |
| ClusterRoles `platform-config-networking-admin` and `platform-config-networking-view` | Manage or read `NetworkingConfig`. Not bound to anyone, and not part of `admin`, `edit` or `view` |
| ValidatingAdmissionPolicy `platform-config-singleton-name` | Rejects a `config.platform.stakater.com` object whose name is not `cluster` |
| `forecastle` chart values `networkPolicy.*` | Network isolation and egress rules. Set them through `NetworkingConfig`, not directly |
| `crossplane-package-kcp` chart values `serviceCatalogs.project.enabled`, `projectCatalog.accessRoles`, `projectCatalog.networkModes` | The console select lists for a Project's role and network mode, and the values they offer. Whether `serviceCatalogs.project.enabled` is on by default in this release: TBD |

### Changed

| Interface | Details |
|-----------|---------|
| `Project` `spec.parameters.access[].users` | **Breaking.** Email addresses only. See [Breaking Changes](#breaking-changes) |
| `Project` `spec.parameters.access[].groups` | **Breaking.** Group names only. See [Breaking Changes](#breaking-changes) |
| `Project` `spec.parameters.access`, `users`, `groups` | At most 50 entries, and 100 users and 100 groups per entry |
| `Project` `spec.parameters.access[].role` | The console offers the project roles as a select with descriptions. The API still accepts any role name |
| `Project` `spec.parameters.network.mode` | The console offers `udn` and `native`, with descriptions. `external` is offered only on platforms that add it. The API still accepts all three modes |
| `User` `status.user.initialPassword` | Shown masked in the console, with reveal and copy |
| `Organization` and `OrgOnboarding` `status.admin.passwordBase64` | Shown masked in the console, with reveal and copy |
| `Group` `spec.parameters.attributes` | No longer offered in the console. It stays in the API and has no effect on access |

### Deprecated

None.

### Removed

None.

## New Features

### Platform configuration APIs

Platform configuration APIs are typed resources for tuning the platform, one kind per area, in `config.platform.stakater.com/v1alpha1`. You commit them to your GitOps repository instead of writing override `EnvironmentConfig` objects. They are validated by the API server and come with a JSON Schema for your CI.

`NetworkingConfig` is the first:

- **Network isolation** for platform namespaces, platform-wide, per stack or per namespace. An isolated namespace denies incoming traffic except from its own pods and from platform monitoring, plus the router and the host network where you allow them, and any extra ingress rules you add.
- **Egress rules** for traffic leaving the cluster from platform namespaces: Allow and Deny rules in priority order, by DNS name, address range or node. Nothing is denied unless you add a Deny rule.
- **Only what you set is applied.** Every value you leave unset keeps the default of the platform release. Isolation and egress rules are off by default.
- **Roles per kind**: an admin and a view role, bound by you.
- **Available on every platform variant.** It is a day-2 setting and has no effect on installation.

In this release, **Forecastle** (namespace `stakater-forecastle`) is the platform component that supports it.

See [Platform Configuration APIs](../platform-configuration/overview.md) and [NetworkingConfig](../platform-configuration/networking-config.md), including how to enable isolation for Forecastle, verify it and roll it back.

### Project form in the console

- **Role** is a select of the project roles, each with a description. The platform roles come first. The built-in roles `cluster-admin`, `admin`, `edit` and `view` are last and labelled *unrestricted*.
- **Users** and **Groups** explain what to enter. A value that is not an email address or a group name is rejected when you submit.
- **Network mode** offers *Isolated network* (`udn`) and *Shared cluster network* (`native`), each with a description. On a platform where organisations have external networks, add an `external` entry under `projectCatalog.networkModes` to offer that mode too.

The role and network mode select lists appear when the project catalogue (`serviceCatalogs.project.enabled`) is on. Without it, both fields are text boxes, as before.

### Masked initial passwords

The console shows the initial password of a new user, and of an organisation's first administrator, masked. **Reveal** shows the decoded password, and **Copy** copies it and masks it again. The password is temporary: the user must change it at first sign-in.

## Fixes

| Component | Fix |
|-----------|-----|
| Organisation Vault | On upgrade, the Vault setup job no longer fails and retries when single sign-on (OIDC) is already configured. Before, the job could show a failed pod before it completed on a retry. No action required |
| `Group` API | `members` is described as usernames (on this platform, a user's email address) |

## Known Issues

| Issue | Workaround |
|-------|------------|
| A `NetworkingConfig` with a name other than `cluster` is rejected when it is created. On a cluster where the name policy is not installed, it is accepted but never applied, and reports why in its status | Name it `cluster` |
| Namespaces you configure in `NetworkingConfig` that no platform component supports in this release are not changed | Check `status.isolation.unmatched.namespaces` and `status.egress.unmatched.namespaces` |
| An override `EnvironmentConfig` for a component takes precedence over `NetworkingConfig` for the same values | Remove the network policy values from the override, or set them there |
| In the console, editing an existing Project whose network mode the platform no longer offers shows an empty network mode select | Change the Project with `kubectl` |
