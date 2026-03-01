# Keycloak

Keycloak is the identity platform embedded in SCO. It provides each organisation with a fully isolated, production-grade identity provider (IDP) — supporting SSO, OIDC, SAML, LDAP federation, and fine-grained role management — without any shared identity pool between tenants.

---

## Role in SCO

Every organisation on the platform gets its own Keycloak **realm**. A realm is a completely isolated identity namespace: users, groups, clients, roles, and authentication flows within one realm have no visibility into any other realm. An organisation's administrators manage their realm independently; platform operators manage the Keycloak instance itself.

```text
Keycloak instance (platform-managed)
├── realm: org-acme        ← Organisation A's isolated IDP
│   ├── Users (Alice, Bob, Carol)
│   ├── Groups (developers, admins)
│   ├── Clients (SCO console, kubectl OIDC)
│   └── Identity providers (corporate LDAP, Google SSO)
└── realm: org-globex      ← Organisation B's isolated IDP
    ├── Users (different set)
    └── ...
```

From a consumer's perspective, their organisation simply has an IDP they authenticate against. Keycloak is the engine behind it, but consumers interact only with the standard OIDC/SAML flows they already know.

---

## Multi-Tenancy Model

Keycloak's realm-per-organisation model gives SCO strong multi-tenancy guarantees at the identity layer:

- **No shared user database** — each realm maintains its own users and credentials
- **No cross-realm token validity** — a token issued in one realm cannot authenticate against another
- **Independent authentication flows** — each organisation can configure its own MFA, password policy, and session settings
- **Isolated client registrations** — OIDC clients (e.g., the web console, ArgoCD integrations) are registered per realm, scoped to that organisation
- **Independent federation** — each organisation can connect its own LDAP directory or enterprise SSO without affecting others

---

## Realm Lifecycle

Realms are provisioned and managed automatically by SCO. When a platform operator creates an `Organization`, SCO:

1. Creates a new Keycloak realm with the organisation's name
1. Configures default client scopes and role mappings
1. Sets up the OIDC client for the web console
1. Optionally configures an identity provider federation if the organisation has a corporate SSO

When an organisation is deleted, its realm and all associated users, groups, and clients are removed.

Platform operators do not need to manually create or configure realms in most cases. The automation handles the full lifecycle.

---

## Organisation Identity Provider Federation

Organisations with an existing corporate directory (LDAP, Active Directory, Google Workspace, Azure AD, Okta) can federate that identity provider into their Keycloak realm. Users then log in with their existing corporate credentials; Keycloak handles the federation transparently.

### Configuring LDAP federation

In the Keycloak admin console for the organisation's realm, navigate to **User Federation** and add an LDAP provider:

| Field | Value |
|-------|-------|
| Vendor | Active Directory / Other |
| Connection URL | `ldap://ldap.example.com:389` |
| Bind DN | `cn=svc-keycloak,ou=service,dc=example,dc=com` |
| Bind Credential | Service account password |
| Users DN | `ou=users,dc=example,dc=com` |
| UUID LDAP Attribute | `objectGUID` (AD) or `entryUUID` |
| User Object Classes | `person, organizationalPerson, user` |

After saving, trigger a **Sync all users** to import the directory. Users can then log in with their LDAP credentials.

### Configuring an OIDC identity provider (e.g., Azure AD, Google)

In the realm, navigate to **Identity Providers** and add an OIDC provider:

```text
Authorization URL: https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/authorize
Token URL:         https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token
Client ID:         <application-id-from-azure>
Client Secret:     <client-secret-from-azure>
Default Scopes:    openid email profile
```

Configure **First Broker Login** flow to control how new users are handled on first login (auto-create, require email verification, link to existing account, etc.).

---

## Managing Users and Groups via SCO APIs

Platform operators and organisation administrators can manage users and groups through the SCO public APIs, without accessing Keycloak directly:

```yaml
# Create a user (provisions a Keycloak user in the organisation's realm)
apiVersion: iam.cloud.stakater.com/v1
kind: User
metadata:
  name: alice
spec:
  parameters:
    username: alice
    email: alice@example.com
    firstName: Alice
    lastName: Smith
```

```yaml
# Create a group and assign members
apiVersion: iam.cloud.stakater.com/v1
kind: Group
metadata:
  name: platform-admins
spec:
  parameters:
    name: platform-admins
    members:
      - alice
      - bob
```

These claims trigger Crossplane compositions that reconcile the corresponding Keycloak realm users and groups. Direct Keycloak API access is not required for routine IAM management.

See [Create IAM User](../how-to-guides/user/create-iam-user.md) and [Create IAM Group](../how-to-guides/user/create-iam-group.md) for full guides.

---

## OIDC Integration with Project Access

When a consumer authenticates to their project's Kubernetes API endpoint, the request is validated against their organisation's Keycloak realm. The project workspace trusts the realm's OIDC token and maps Keycloak groups to Kubernetes RBAC roles within the project.

This means:

- Adding a user to the `developers` group in Keycloak automatically grants them developer-level access to all projects that have bound that group
- Removing a user from a group or disabling their account in Keycloak immediately revokes access — no separate Kubernetes RBAC update required
- Group membership from an LDAP federation is honoured: a user in an AD group gets the corresponding project access without any manual mapping

---

## Platform Operator Access

Platform operators access the Keycloak admin console through the management interface. The admin console allows:

- Inspecting and troubleshooting any realm
- Configuring instance-level settings (email, brute force protection, event logging)
- Managing the master realm and administrative service accounts
- Reviewing audit events across all realms

!!! note
    Organisation-level administrators have access only to their own realm through a delegated admin configuration. They cannot see other organisations' realms or the master realm.

---

## What's Next?

- [Keycloak Realms](../service-provider-guide/organizations/keycloak-realms.md) — Detailed realm configuration for providers
- [Managing Users](../cloud-user-guide/authentication/managing-users.md) — User management guide
- [Create IAM User](../how-to-guides/user/create-iam-user.md) — How-to guide
- [Create IAM Group](../how-to-guides/user/create-iam-group.md) — How-to guide
