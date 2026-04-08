# Creating Organizations

Organizations are the top-level tenancy unit in SCO. Each organization gets a fully isolated identity realm, a dedicated virtual API workspace hierarchy, and its own set of users, groups, and projects.

---

## Prerequisites

- `infrastructure.stakater.com` API available
- `kubectl` configured with platform administrator access
- An admin email address for the initial organization administrator

---

## What Gets Created

When an organization is provisioned, SCO automatically creates:

- An isolated identity realm for authentication (users, groups, SSO configuration)
- A virtual API workspace for the organization and its projects
- An initial administrator account with credentials sent to the specified email
- Default role bindings for the organization admin

---

## Step 1: Apply the Organization Onboarding Claim

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
    The `organizationName` value becomes the organization's identifier throughout the platform. Choose a short, URL-safe name: lowercase letters, numbers, and hyphens only.

## Step 2: Verify the Organization

```bash
kubectl get organizations
```

```text
NAME        STATUS   AGE
acme-corp   Ready    2m
```

The organization is ready when its `STATUS` is `Ready`. At this point:

- The administrator account has been created
- Login credentials have been sent to the specified email address
- The organization's console URL is active

## Step 3: Notify the Organization Administrator

Share the following with the new organization administrator:

- The SCO console URL for their organization
- That they have received login credentials by email
- Links to the [Cloud Consumer Guide](../../cloud-user-guide/getting-started.md)

---

## Managing Multiple Organizations

Each organization is completely isolated: no shared user database and no cross-organization credential. As a platform provider, you can:

```bash
# List all organizations
kubectl get organizations

# Inspect a specific organization
kubectl describe organization acme-corp
```

!!! warning
    Deleting an organization removes all projects, provisioned services, users, and data within it. This action is irreversible. Notify the customer and ensure data has been exported before proceeding.

---

## What's Next?

- [Keycloak Realms](keycloak-realms.md) — Configure SSO and identity federation for the organization
- [Project Architecture](../projects/project-architecture.md) — How projects are structured within an organization
- [Create Project](../../how-to-guides/user/create-project.md) — Create projects for organization users
