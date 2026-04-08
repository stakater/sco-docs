# How to Create an IAM User

Learn how to create a user identity in your organisation's identity provider via a Project claim.

Maria, an organisation administrator at ACME Corp, needs to provision a new team member's account so they can log in to the SCO console and access their project.

## Prerequisites

- Access to your organisation's project
- The `user.iam.cloud.stakater.com` API available
- `kubectl` configured with your organisation project kubeconfig
- Sufficient permissions to create `User` resources in your project

## What Gets Created

When you create a User claim, the platform provisions:

- An **organisation user** in your organisation's IdP with the specified username and email
- An **auto-generated initial password** (base64 encoded, available in the resource status)

## Step 1: Define Your User Claim

Create a file named `user.yaml`:

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: User
metadata:
  name: jane-doe
spec:
  parameters:
    username: jane.doe
    email: jane.doe@acmecorp.example.com
```

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `parameters.username` | Username for the organisation user |
| `parameters.email` | Email address for the user |

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `parameters.firstName` | — | User first name |
| `parameters.lastName` | — | User last name |
| `parameters.emailVerified` | `false` | Whether the email is pre-verified in your organisation's IdP |
| `parameters.enabled` | `true` | Whether the user can log in immediately |

## Step 2: Add Full Profile (Optional)

For a complete user profile, include first and last name:

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: User
metadata:
  name: jane-doe
spec:
  parameters:
    username: jane.doe
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

Expected status once ready:

```text
READY=True
SYNCED=True
```

Retrieve the initial password from the status:

```bash
kubectl get user jane-doe \
  -o jsonpath="{.status.user.initialPassword}" | base64 -d
```

!!! note
    Share the initial password securely with the new user. They should change it on first login.

## Full Example

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: User
metadata:
  name: tenant-user
spec:
  parameters:
    username: tenant-admin
    email: admin@org.example.com
    firstName: Tenant
    lastName: Admin
    enabled: true
```

## What's Next?

- [Create an IAM Group](create-iam-group.md) - Organise users into groups and assign roles
- [Create a Project](create-project.md) - Create a project and grant group access
- [Provision a Virtual Machine](provision-virtual-machine.md) - Give the user resources to work with
