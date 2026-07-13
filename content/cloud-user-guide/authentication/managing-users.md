# Managing Users

Organisation administrators can manage users and groups through the SCO IAM API. This controls who can log in to the organisation and what projects they can access.

---

## Creating Users

Create a user in your organisation with a `iam.cloud.stakater.com/v1 User` claim. The user is provisioned in your organisation's identity realm and receives a welcome email with login credentials.

```yaml
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
    emailVerified: true
    enabled: true
```

```bash
kubectl apply -f alice.yaml
```

See the [Create IAM User](../../how-to-guides/user/create-iam-user.md) how-to guide for the full parameter reference.

---

## Creating Groups

Groups let you manage access for multiple users at once. A project can grant access to a group — adding someone to the group automatically grants them the project access configured for that group.

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: Group
metadata:
  name: developers
spec:
  parameters:
    name: developers
    members:
      - alice
      - bob
```

```bash
kubectl apply -f developers-group.yaml
```

See [Create IAM Group](../../how-to-guides/user/create-iam-group.md) for the full guide.

---

## Granting Project Access

Project access is configured in the `Project` claim's `access` field:

```yaml
spec:
  parameters:
    access:
      - role: admin
        users:
          - alice
      - role: edit
        groups:
          - developers
      - role: view
        groups:
          - stakeholders
```

| Role | Permissions |
|------|-------------|
| `admin` | Full control — create, update, delete any resource in the project |
| `edit` | Create and manage resources, cannot modify access configuration |
| `view` | Read-only access to all resources in the project |

---

## Disabling or Removing a User

To disable a user without deleting them:

```yaml
spec:
  parameters:
    enabled: false
```

To permanently remove a user:

```bash
kubectl delete user alice
```

This removes the user from your organisation's identity realm. They can no longer log in. Past audit log entries are retained.

---

## Removing a User from a Group

Update the `members` list in the group claim and reapply it. Removing a user from a group immediately revokes any project access granted via that group.

---

## What's Next?

- [Create IAM User](../../how-to-guides/user/create-iam-user.md) — Full user creation guide
- [Create IAM Group](../../how-to-guides/user/create-iam-group.md) — Full group management guide
- [Creating Projects](../projects/creating-projects.md) — Create projects and configure access
- [One Identity Across Your Organisation](organisation-identity.md) — Where the account works and how first sign-in behaves
