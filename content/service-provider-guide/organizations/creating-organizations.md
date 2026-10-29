# Creating Organizations

Organizations are the top-level tenancy unit in SCO. Each organization gets a fully isolated identity realm, a dedicated virtual API workspace hierarchy, and its own set of users, groups, and projects.

---

## Prerequisites

- The `organizations.infrastructure.stakater.com` API available on the hosting cluster
- `kubectl` configured with platform administrator access to the hosting cluster
- An admin email address for the initial organization administrator

---

## What Gets Created

When an organization is provisioned, SCO automatically creates:

- An isolated identity realm for authentication (users, groups, SSO configuration)
- A virtual API workspace for the organization and its projects
- An initial administrator account for the admin email, with a generated password
- Default role bindings for the organization admin
- An organization mesh and secret store, unless you turn them off (`mesh.enabled`, `bao.enabled`)

!!! note
    The platform does **not** email the credentials. Organization realms have no mail server configured, so no welcome or password email is sent. You hand the initial credentials to the organization administrator yourself (see [Step 3](#step-3-hand-over-to-the-organization-administrator)).

---

## Step 1: Apply the Organization Claim

Organizations are `Organization` claims (`infrastructure.stakater.com/v1alpha1`) in the `kcp-sco-orgs` namespace of the hosting cluster:

```yaml
apiVersion: infrastructure.stakater.com/v1alpha1
kind: Organization
metadata:
  name: acme-corp
  namespace: kcp-sco-orgs
spec:
  providerConfigRef:
    name: kubernetes-provider
  kcpRootProviderConfigRef:
    name: cloud
  keycloakProviderConfigRef:
    name: keycloak-config-rhbk-public
  parameters:
    organizationName: acme-corp
    adminEmail: admin@acmecorp.example.com
    mesh:
      enabled: true
    bao:
      enabled: true
```

| Field | Description | Default |
|-------|-------------|---------|
| `metadata.name` | Claim name. Use the same value as `organizationName`. | — |
| `spec.providerConfigRef.name` | Provider configuration for the hosting cluster | — |
| `spec.kcpRootProviderConfigRef.name` | Provider configuration for the root virtual API workspace | — |
| `spec.keycloakProviderConfigRef.name` | Provider configuration for the identity service | — |
| `parameters.organizationName` | Organization identifier (required) | — |
| `parameters.adminEmail` | Email of the initial organization administrator (required) | — |
| `parameters.mesh.enabled` | Provision the organization's default mesh | `true` |
| `parameters.bao.enabled` | Provision the organization's default secret store | `true` |

The provider configuration names differ per platform; the values above are the ones used on Stakater-managed hubs. Copy them from an existing organization on your hosting cluster:

```bash
kubectl get organizations.infrastructure.stakater.com -n kcp-sco-orgs -o yaml
```

```bash
kubectl apply -f organization-acme-corp.yaml
```

On a platform managed through GitOps, commit the claim to the platform's GitOps repository instead of applying it by hand.

!!! note
    The `organizationName` value becomes the organization's identifier throughout the platform and cannot be renamed later. Choose a short, URL-safe name — lowercase letters, numbers, and hyphens only.

!!! warning
    Do not name an organization `alpha` or `constellation` on Stakater-managed hubs. The platform's tenant configuration ships sample tenants with those names, and an organization with the same name inherits their settings, which leaves its workloads with no node they can run on.

!!! warning
    Decide on `mesh.enabled` when you create the organization. Turning the mesh off later on an existing organization can leave mesh resources stuck on deletion.

## Step 2: Verify the Organization

Several APIs on the hosting cluster serve a resource called `organizations`, so always use the fully qualified name:

```bash
kubectl get organizations.infrastructure.stakater.com -n kcp-sco-orgs acme-corp
```

```text
NAME        SYNCED   READY   CONNECTION-SECRET   AGE
acme-corp   True     True                        2m
```

The organization is ready when `READY` is `True`. At this point:

- The administrator account has been created
- The organization's console URL is active

## Step 3: Hand Over to the Organization Administrator

No credentials email is sent, so share the following with the new organization administrator over a secure channel:

- The SCO console URL for their organization
- Their username (the admin email) and the initial password
- Links to the [Cloud User Guide](../../cloud-user-guide/getting-started.md)

<!-- TODO(SA-8708): document where a platform administrator reads the generated initial admin password, and whether the administrator must change it at first login. Not verified for this change. -->

The same applies to users the organization administrator creates later: they receive no email, and the organization administrator passes on their initial credentials (see [How to Create an IAM User](../../how-to-guides/user/create-iam-user.md)).

---

## Managing Multiple Organizations

Each organization is completely isolated — no shared user database, no cross-organization credential. As a platform provider you can:

```bash
# List all organizations
kubectl get organizations.infrastructure.stakater.com -n kcp-sco-orgs

# Inspect a specific organization
kubectl describe organizations.infrastructure.stakater.com -n kcp-sco-orgs acme-corp
```

!!! warning
    Deleting an organization removes all projects, provisioned services, users, and data within it. This action is irreversible. Notify the customer and ensure data has been exported before proceeding.

!!! note
    If your GitOps tooling syncs organization claims without pruning, removing the file from Git does not delete the organization. Delete the claim on the hosting cluster as well.

---

## What's Next?

- [Keycloak Realms](keycloak-realms.md) — Configure SSO and identity federation for the organization
- [Project Architecture](../projects/project-architecture.md) — How projects are structured within an organization
- [Create Project](../../how-to-guides/user/create-project.md) — Create projects for organization users
