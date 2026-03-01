# Keycloak Realms

Each SCO organisation is backed by a dedicated Keycloak realm — a fully isolated identity namespace with its own users, groups, clients, and authentication flows. This page covers the realm configuration options relevant to platform providers.

For a conceptual overview of Keycloak's role in SCO, see [Keycloak Integration](../../integrations/keycloak.md).

---

## Realm Lifecycle

Realms are provisioned automatically when an organisation is onboarded and removed when an organisation is deleted. Platform operators do not need to create or delete realms manually.

After an organisation is created, the realm is immediately available. The organisation administrator can then customise it through the Keycloak admin console or through the SCO IAM API.

---

## Configuring Corporate SSO Federation

Organisations with an existing corporate directory can federate their identity provider into their realm. Users then authenticate with their existing corporate credentials.

### LDAP / Active Directory

In the Keycloak admin console for the organisation's realm, navigate to **User Federation → Add Provider → LDAP**:

| Field | Example |
|-------|---------|
| Vendor | Active Directory |
| Connection URL | `ldap://ad.example.com:389` |
| Bind DN | `cn=svc-keycloak,ou=services,dc=example,dc=com` |
| Users DN | `ou=users,dc=example,dc=com` |
| UUID LDAP attribute | `objectGUID` |

After saving, trigger **Sync all users** to import the directory.

### OIDC Provider (Azure AD, Google, Okta)

Navigate to **Identity Providers → Add Provider → OpenID Connect v1.0**:

| Field | Example (Azure AD) |
|-------|--------------------|
| Authorization URL | `https://login.microsoftonline.com/<tenant>/oauth2/v2.0/authorize` |
| Token URL | `https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token` |
| Client ID | `<azure-app-id>` |
| Client Secret | `<azure-client-secret>` |
| Default Scopes | `openid email profile` |

Configure the **First Login Flow** to control how new federated users are handled on first sign-in.

---

## Configuring Authentication Flows

Each realm can have its own authentication policy. Navigate to **Authentication** in the realm console to configure:

- **Password policy** — minimum length, complexity requirements, rotation
- **Multi-factor authentication** — OTP requirement by group, conditional MFA
- **Brute force protection** — lockout thresholds and wait times
- **Session limits** — idle and maximum session lifetimes

---

## Managing Users and Groups via the SCO API

Routine user and group management does not require Keycloak console access. Organisation administrators use the SCO IAM API:

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

## Platform Operator Access

Platform operators can access any organisation's realm through the Keycloak master admin console. Organisation administrators access only their own realm through a delegated admin configuration — they cannot view or modify other organisations' realms.

---

## What's Next?

- [Keycloak Integration](../../integrations/keycloak.md) — Architecture and multi-tenancy model reference
- [Create IAM User](../../how-to-guides/user/create-iam-user.md) — User management how-to
- [Create IAM Group](../../how-to-guides/user/create-iam-group.md) — Group management how-to
- [Managing Users](../../cloud-user-guide/authentication/managing-users.md) — Consumer-facing user management guide
