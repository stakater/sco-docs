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
| `username` | `string` | Username for the organisation user |
| `email` | `string` | Email address for the user |

### Optional

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `firstName` | `string` | — | User first name |
| `lastName` | `string` | — | User last name |
| `emailVerified` | `boolean` | `false` | Whether the email is pre-verified in the organisation's IdP |
| `enabled` | `boolean` | `true` | Whether the user can log in immediately |

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.user.id` | `string` | User ID (uuid) assigned by the IdP |
| `status.user.username` | `string` | Confirmed username |
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
    username: jane.doe
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
    username: jane.doe
    email: jane.doe@acmecorp.example.com
    firstName: Jane
    lastName: Doe
    emailVerified: true
    enabled: true
```

## How-to Guide

[Create an IAM User](../../how-to-guides/user/create-iam-user.md)
