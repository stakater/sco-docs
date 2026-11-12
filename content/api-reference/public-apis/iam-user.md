# IAM User

Creates a user identity in your organisation's identity provider.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `iam.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `User` |
| **Scope** | Namespace-scoped |

## Spec Parameters

All parameters are nested under `spec.parameters`.

### Required

| Field | Type | Description |
|-------|------|-------------|
| `email` | `string` | Email address for the user. It is also the user's login name, and the value to use in group `members` and project `access` entries |

### Optional

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `firstName` | `string` | — | User's first name |
| `lastName` | `string` | — | User's last name |
| `emailVerified` | `boolean` | `false` | Whether the email is pre-verified in the organisation's IdP |
| `enabled` | `boolean` | `true` | Whether the user can log in immediately |
| `username` | `string` | — | Deprecated and ignored. The email address is used as the login name |

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.user.id` | `string` | User ID (uuid) assigned by the IdP |
| `status.user.username` | `string` | Login name (the same as the email address) |
| `status.user.email` | `string` | Confirmed email address |
| `status.user.created` | `boolean` | Whether the user was successfully created |
| `status.user.ready` | `boolean` | Whether the user is ready and accessible |
| `status.user.initialPassword` | `string` | Auto-generated initial password (base64 encoded) |
| `status.conditions` | `array` | Standard Kubernetes conditions |

## Examples

### Minimal

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: User
metadata:
  name: jane-doe
spec:
  parameters:
    email: jane.doe@acmecorp.example.com
```

### Full

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

## How-to Guide

[Create an IAM User](../../how-to-guides/user/create-iam-user.md)
