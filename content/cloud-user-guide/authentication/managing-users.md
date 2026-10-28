# Managing Users

Organisation administrators can manage users and groups through the SCO IAM API. This controls who can log in to the organisation and what projects they can access.

---

## Creating Users

Create a user in your organisation with a `iam.cloud.stakater.com/v1 User` claim. The platform provisions an organisation user in your organisation's IdP. The user's **email address is their login name**: they log in with it, and you use it to add them to groups and grant them project access.

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: User
metadata:
  name: alice
spec:
  parameters:
    email: alice@acmecorp.example.com
    firstName: Alice
    lastName: Smith
    emailVerified: true
    enabled: true
```

```bash
kubectl apply -f alice.yaml
```

The platform generates an initial password and publishes it, base64-encoded, in the claim's status. Read it and share it with the user securely:

```bash
kubectl get user alice -o jsonpath='{.status.user.initialPassword}' | base64 -d
```

!!! note
    The `username` parameter is deprecated and ignored. The user cannot log in with it, and it cannot be used in group `members` or project `access` entries. Always use the email address.

See the [Create IAM User](../../how-to-guides/user/create-iam-user.md) how-to guide for the full parameter reference.

!!! note
    If your organisation has connected a company identity provider, do not create a `User` claim for an email address in its domains. That user gets a password and signs in without the company identity provider. See [Users from Your Company Identity Provider](#users-from-your-company-identity-provider).

---

## Users from Your Company Identity Provider

When your organisation has a [company identity provider](../../how-to-guides/user/connect-identity-provider.md), users of its email domains need no `User` claim:

- The platform creates their organisation user at their first sign-in. It has no password.
- They do not appear in the console's user list, because there is no `User` claim for them.
- You give them access by email address, as for other users: in the `members` of a group, or in the `users` of a project's `access` list.
- You can add someone to a group before their first sign-in. The membership applies after their first sign-in, within about 15 minutes. Until then, the group already lists them, but they do not have the group's access yet.
- To stop someone signing in, disable them in your company identity provider. Sessions that are already open stay valid until they expire.

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
      - alice@acmecorp.example.com
      - bob@acmecorp.example.com
```

List members by their email address.

```bash
kubectl apply -f developers-group.yaml
```

See [Create IAM Group](../../how-to-guides/user/create-iam-group.md) for the full guide.

---

## Granting Project Access

Project access is configured in the `Project` claim's `access` field. List individual users by their **email address**, and groups by name:

```yaml
spec:
  parameters:
    access:
      - role: platform-services-admin
        users:
          - alice@acmecorp.example.com
      - role: compute-user
        groups:
          - developers
      - role: platform-services-view
        groups:
          - stakeholders
```

!!! warning
    An entry in `users` that is not the user's email address (for example the `username` from their `User` claim) grants nothing, and the project still reports `Ready`. The user then sees no projects in the console.

| Role | Permissions |
|------|-------------|
| `platform-services-admin` | Full control of every platform service in the project. Can also read the project's Secrets |
| `platform-services-view` | Read-only access to every platform service in the project. Can also read the project's Secrets |
| `<service>-user` | Full control of one service (`compute`, `database`, `kubernetes`, `mesh`, `network`, `secrets` or `storage`). Can also read the project's Secrets |
| `<service>-viewer` | Read-only access to one service. Cannot read Secrets |

None of these roles lets a user change the project's `access` list; only organisation administrators can. See [Project Roles](../projects/creating-projects.md#project-roles) for what each role covers.

!!! warning
    Use only the roles in this table. Any other role name is accepted without an error. If it matches a built-in Kubernetes role, such as `edit` or `cluster-admin`, it grants that role in the project, with far broader rights than any SCO role, including creating and deleting Secrets.

---

## Disabling or Removing a User

To disable a user without deleting them, set `enabled: false` in their `User` claim and reapply it:

```yaml
spec:
  parameters:
    enabled: false
```

To permanently remove a user, first remove them from every group (see [Removing a User from a Group](#removing-a-user-from-a-group)) and from the `access` list of every project, then delete the claim:

```bash
kubectl delete user alice
```

This removes the user from your organisation's IdP. They can no longer log in. Past audit log entries are retained.

!!! warning "Remove group memberships before deleting a user"
    Always take a user out of their groups (or delete those groups) **before** deleting the user. If you delete the user first, a group they were in can no longer be deleted cleanly: it keeps trying to remove a member who no longer exists. If that has already happened, contact your platform provider.

!!! warning "Disabling or deleting a user does not end their mesh session"
    Disabling or deleting a user blocks new logins to the console. It does **not** disconnect devices the user has already enrolled in your organisation mesh: a connected device keeps its mesh access until its own mesh login expires. Until this is fixed, an organisation administrator must also remove the user's devices from the mesh: open the Mesh dashboard (its URL is on the Mesh detail page in the console, see [Create a Mesh](../../how-to-guides/user/create-mesh.md#step-4-open-the-dashboard)), find the user's devices in the list of peers, and remove them.

<!-- TODO(SA-8708): replace the mesh warning once SA-9375 (disable/delete should expire the user's mesh peers) is fixed; confirm the dashboard's control for removing a peer -->

---

## Removing a User from a Group

Remove the user's email address from the `members` list in the group claim and reapply it. Removing a user from a group revokes any project access granted via that group.

---

## What's Next?

- [Create IAM User](../../how-to-guides/user/create-iam-user.md) — Full user creation guide
- [Create IAM Group](../../how-to-guides/user/create-iam-group.md) — Full group management guide
- [Creating Projects](../projects/creating-projects.md) — Create projects and configure access
- [One Identity Across Your Organisation](organisation-identity.md) — Where the account works and how first sign-in behaves
