# Organisation Identity

Each SCO organisation has a fully isolated identity space — its own users, groups, authentication flows, and SSO configuration. This isolation is enforced at the platform level: users in one organisation cannot see or access resources in another.

Identity infrastructure is provisioned automatically when an organisation is created and removed when the organisation is deleted. Platform providers do not manage identity components directly — all configuration is applied through the SCO platform.

---

## What Gets Provisioned Automatically

When an `OrgOnboarding` claim is created, the platform provisions:

- An isolated identity realm for the organisation
- An initial administrator account with credentials sent to the specified `adminEmail`
- A KCP workspace authentication configuration scoped to the organisation's realm
- Default authentication flows and session policies

Organisation administrators can then manage users and groups using the SCO IAM API.

---

## Managing Users and Groups

Routine user and group management uses the SCO IAM API — no direct access to the identity infrastructure is needed.

```bash
# Create a user
kubectl apply -f - <<EOF
apiVersion: iam.cloud.stakater.com/v1
kind: User
metadata:
  name: alice
spec:
  parameters:
    username: alice
    email: alice@acmecorp.example.com
    firstName: Alice
    lastName: Smith
EOF

# Create a group
kubectl apply -f - <<EOF
apiVersion: iam.cloud.stakater.com/v1
kind: Group
metadata:
  name: platform-engineers
spec:
  parameters:
    name: platform-engineers
    members:
      - alice
EOF
```

See [Create IAM User](../../how-to-guides/user/create-iam-user.md) and [Create IAM Group](../../how-to-guides/user/create-iam-group.md) for full guides.

---

## Corporate SSO Federation

Organisations with an existing corporate directory can authenticate using their existing credentials. The platform supports federation with:

- **Azure Active Directory** — OIDC-based federation using an Azure app registration
- **OIDC providers** — Any standards-compliant OIDC identity provider
- **SAML providers** — SAML 2.0 federation for providers that do not support OIDC

SSO federation is configured at the platform level. To enable federation for an organisation, provide the following to the platform team:

| Provider | Required information |
|----------|---------------------|
| Azure AD | Tenant ID, Application (client) ID, client secret |
| OIDC | Authorization URL, token URL, client ID, client secret |
| SAML | Metadata URL or XML, entity ID |

The platform applies the configuration and federated users can authenticate using their corporate credentials from that point on. No manual user creation is needed — accounts are provisioned on first login from the corporate directory.

!!! note
    User and group records created through the SCO IAM API remain available regardless of whether SSO is configured. SSO federation and local accounts can coexist within the same organisation.

---

## Authentication Policy

Default authentication policies applied to every organisation include:

- Password complexity and minimum length requirements
- Brute force protection with configurable lockout thresholds
- Configurable session idle and maximum lifetime
- Multi-factor authentication (can be required per group or globally)

Authentication policy customisation is handled at the platform level. Contact the platform team to adjust policies for a specific organisation.

---

## What's Next?

- [Creating Organisations](creating-organizations.md) — Provision a new organisation
- [Create IAM User](../../how-to-guides/user/create-iam-user.md) — User management how-to
- [Create IAM Group](../../how-to-guides/user/create-iam-group.md) — Group management how-to
- [Keycloak Integration](../../integrations/keycloak.md) — Architecture reference for platform operators
