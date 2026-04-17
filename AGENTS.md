# Documentation Authoring Guidelines

This file describes conventions for AI agents and human contributors authoring content in this repository.

## Audience and Perspective

Documentation in this repository targets **platform users** — developers, team leads, and organisation administrators who interact with the SCO platform through its user-facing APIs. Docs should be written from their perspective, not from the perspective of platform engineers or operators who built the underlying system.

## Abstraction Principle

**Hide implementation details. Use platform-level terminology.**

Users interact with the SCO platform through claims and the SCO console. They do not need to know about the underlying components that fulfil those claims. When writing documentation:

| Avoid | Use instead |
|-------|-------------|
| `namespace:` in claim `metadata` | omit — projects have a single default namespace |
| `labels: stakater.com/tenant` in claim `metadata` | omit — implementation detail |
| KCP workspace | project |
| Keycloak user / group / realm | organisation user / group / IDP |
| Crossplane composition | platform / the platform provisions |
| ClusterRoleBinding | role-based access |
| Tenant resource (MTO) | project quota |
| ClusterUserDefinedNetwork (cUDN) | network isolation |
| `composition available (installed by your administrator)` | `<api-group> api available` |
| "the composition provisions" | "the platform provisions" |
| workspace kubeconfig | project kubeconfig |
| namespace (user-facing context) | project |

### Examples

**Wrong:**
> When you create a Group claim, the Keycloak composition provisions a Keycloak group in your organisation's Keycloak realm.

**Correct:**
> When you create a Group claim, the platform provisions an organisation group in your organisation's IDP.

---

**Wrong:**
> Prerequisites: The `IAM Group` composition available (installed by your platform administrator), `kubectl` configured with your organisation workspace kubeconfig.

**Correct:**
> Prerequisites: The `group.iam.cloud.stakater.com` api available, `kubectl` configured with your organisation project kubeconfig.

## Terminology Reference

| Platform concept | Description |
|-----------------|-------------|
| **organisation** | A tenant on the SCO platform. Corresponds to an isolated realm in the IDP. |
| **project** | An isolated environment within an organisation for deploying resources. |
| **IDP** | The organisation's identity provider, managed by the platform. |
| **organisation user** | A user account in the organisation's IDP. |
| **organisation group** | A group in the organisation's IDP, used for role-based access. |
| **claim** | A Kubernetes custom resource a user applies to request platform resources. |
| **platform** | The SCO platform and its automation — used instead of naming specific components. |

## Documentation Structure

How-to guides live under `content/how-to-guides/` split by audience:

- `user/` — guides for cloud users (developers, team leads)
- `provider/` — guides for platform/service providers

### How-to Guide Template

Each guide should follow this structure:

```markdown
# How to <verb> <noun>

<One sentence describing what the user will achieve.>

<Persona sentence: "Alex, a <role> at <org>, needs to...">

## Prerequisites

- ...

## What Gets Created

When you create a <Kind> claim, the platform provisions:

- ...

## Step 1: ...

## Step N: Verify

## Full Example

## What's Next?

- [Related guide](related-guide.md) - Short description
```

### Style Conventions

- Use **UK English** spelling (organisation, colour, etc.)
- Use **persona-driven** introductions
- Parameter tables must include a **Default** column when defaults exist
- Use `!!! note` and `!!! tip` admonitions for callouts
- Prerequisite bullets list the **API group** (`the <resource>.<group> api available`), not the composition name
- Cross-link to related how-to guides at the end of every guide

## API Group Conventions

SCO compositions are split across two API group namespaces with distinct purposes:

| API group | Purpose | Who uses it |
|-----------|---------|-------------|
| `*.cloud.stakater.com` (e.g. `kubernetes.cloud.stakater.com`, `compute.cloud.stakater.com`, `iam.cloud.stakater.com`, `tenant.cloud.stakater.com`) | **User-facing APIs** — simplified, opinionated interfaces designed for cloud users | Developers, team leads, org admins |
| `infrastructure.stakater.com` | **Backend/infrastructure APIs** — low-level APIs used by the platform internally | Platform engineers only |

**Rule:** How-to guides in `user/` must only reference `*.cloud.stakater.com` APIs. Never document `infrastructure.stakater.com` resources as user-facing. If a user-facing equivalent exists in a `cloud.stakater.com` group, always prefer it.

## Source of Truth for YAML Examples

YAML examples in how-to guides are derived from test cases in the compositions repository at `/home/callum/code/stakater/compositions/`. The canonical location for each package's example claims is:

```
compositions/<package-name>/<kind>/test/cases/<case-name>/claim.yaml
```

API definitions (including required fields and defaults) live at:

```
compositions/<package-name>/<kind>/resources/definition.yaml
```

Always derive examples from these sources rather than writing YAML from memory.
