# How to Create an IAM User

Learn how to create a user identity in your organisation's identity provider with a User claim.

Maria, an organisation administrator at ACME Corp, needs to provision a new team member's account so they can log in to the SCO console and access their project.

## Prerequisites

- Access to your organisation's project
- The `user.iam.cloud.stakater.com` API available
- `kubectl` configured with your organisation project kubeconfig
- Sufficient permissions to create `User` resources in your project

## What Gets Created

When you create a User claim, the platform provisions:

- An **organisation user** in your organisation's IdP whose login name is the specified email address
- An **auto-generated initial password** (base64 encoded, available in the resource status)

## In the Console

Users live under **Identity & Access** in the sidebar. The list shows every user in your organisation:

![The Users list in the console]({{ screenshot: iam-users-list }})

**Create** opens a form with the same fields as the claim below — it is generated from the same API schema, so the two are never out of step:

![The Create User form]({{ screenshot: iam-user-create }})

The rest of this guide uses `kubectl`, which is the path to take when the user should live in version control alongside the rest of your configuration.

## Step 1: Define Your User Claim

Create a file named `user.yaml`:

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: User
metadata:
  name: jane-doe
spec:
  parameters:
    email: jane.doe@acmecorp.example.com
```

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `parameters.email` | Email address for the user. It is also their login name, and the identifier you use for them in group `members` and project `access` entries |

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `parameters.firstName` | — | User's first name |
| `parameters.lastName` | — | User's last name |
| `parameters.emailVerified` | `false` | Whether the email is pre-verified in your organisation's IdP |
| `parameters.enabled` | `true` | Whether the user can log in immediately |

!!! note
    `parameters.username` is deprecated and ignored. Do not use it: the user cannot log in with it, and it does not work in group `members` or project `access` entries.

## Step 2: Add Full Profile (Optional)

For a complete user profile, include first and last name:

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: User
metadata:
  name: jane-doe
spec:
  parameters:
    email: jane.doe@acmecorp.example.com
    firstName: Jane
    lastName: Doe
    emailVerified: true
    enabled: true
```

## Step 3: Apply the Claim

```bash
kubectl apply -f user.yaml
```

## Step 4: Verify the User

Check that the user claim was accepted:

```bash
kubectl get user jane-doe
```

Expected output once ready:

```text
NAME       READY   SYNCED   AGE
jane-doe   True    True     1m
```

Retrieve the initial password from the status:

```bash
kubectl get user jane-doe \
  -o jsonpath='{.status.user.initialPassword}' | base64 -d
```

!!! note
    Share the initial password securely with the new user. They log in with their **email address** (`jane.doe@acmecorp.example.com`) and this password, and are asked to set a new password at first login. <!-- TODO(SA-8708): in ST-06 one of two test users was not asked to change the password at first console login; confirm the forced change is reliable -->

## Step 5: Give the User Access

A new user has no project access yet. Grant it by their email address, either directly in a project's `access` list or by adding them to a group:

- [Granting Project Access](../../cloud-user-guide/authentication/managing-users.md#granting-project-access)
- [Create an IAM Group](create-iam-group.md)

## Full Example

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: User
metadata:
  name: tenant-user
spec:
  parameters:
    email: admin@org.example.com
    firstName: Tenant
    lastName: Admin
    enabled: true
```

## What's Next?

- [Create an IAM Group](create-iam-group.md) - Organise users into groups and assign roles
- [Create a Project](create-project.md) - Create a project and grant group access
- [Provision a Virtual Machine](provision-virtual-machine.md) - Give the user resources to work with
