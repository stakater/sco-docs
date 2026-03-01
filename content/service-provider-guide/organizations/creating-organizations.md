# Creating Organisations

Organisations are the top-level tenancy unit in SCO. Each organisation gets a fully isolated identity realm, a dedicated virtual API workspace hierarchy, and its own set of users, groups, and projects.

---

## Prerequisites

- `infrastructure.stakater.com` api available
- `kubectl` configured with platform administrator access
- An admin email address for the initial organisation administrator

---

## What Gets Created

When an organisation is provisioned, SCO automatically creates:

- An isolated identity realm for authentication (users, groups, SSO configuration)
- A virtual API workspace for the organisation and its projects
- An initial administrator account with credentials sent to the specified email
- Default role bindings for the organisation admin

---

## Step 1: Apply the Organisation Onboarding Claim

```yaml
apiVersion: infrastructure.stakater.com/v1alpha1
kind: XOrgOnboarding
metadata:
  name: acme-corp
spec:
  providerConfigRef:
    name: kubernetes-provider
  kcpRootProviderConfigRef:
    name: kcp-root-provider
  parameters:
    organizationName: acme-corp
    adminEmail: admin@acmecorp.example.com
```

```bash
kubectl apply -f org-onboarding.yaml
```

!!! note
    The `organizationName` value becomes the organisation's identifier throughout the platform. Choose a short, URL-safe name — lowercase letters, numbers, and hyphens only.

## Step 2: Verify the Organisation

```bash
kubectl get organizations
```

```text
NAME        STATUS   AGE
acme-corp   Ready    2m
```

The organisation is ready when its `STATUS` is `Ready`. At this point:

- The administrator account has been created
- Login credentials have been sent to the specified email address
- The organisation's console URL is active

## Step 3: Notify the Organisation Administrator

Share the following with the new organisation administrator:

- The SCO console URL for their organisation
- That they have received login credentials by email
- Links to the [Cloud User Guide](../../cloud-user-guide/getting-started.md)

---

## Managing Multiple Organisations

Each organisation is completely isolated — no shared user database, no cross-organisation credential. As a platform provider you can:

```bash
# List all organisations
kubectl get organizations

# Inspect a specific organisation
kubectl describe organization acme-corp
```

!!! warning
    Deleting an organisation removes all projects, provisioned services, users, and data within it. This action is irreversible. Notify the customer and ensure data has been exported before proceeding.

---

## What's Next?

- [Keycloak Realms](keycloak-realms.md) — Configure SSO and identity federation for the organisation
- [Project Architecture](../projects/project-architecture.md) — How projects are structured within an organisation
- [Create Project](../../how-to-guides/user/create-project.md) — Create projects for organisation users
