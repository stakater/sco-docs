# IAM Group

Creates a group in your organisation's identity provider and manages its membership.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `iam.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `Group` |
| **Scope** | Namespace-scoped |

## Spec Parameters

All parameters are nested under `spec.parameters`. None is required.

The group is named after `metadata.name`, which is also its name in your organisation's identity provider. These names are reserved for platform access and are refused when you create the group: `customer-admin`, names that start with `stakater-`, and names that end with `-cluster-admin` or `-stakater-admin`.

`spec.parameters.name` is deprecated and ignored. Older claims that still set it keep working, and the group is named after `metadata.name`.

### Optional

| Field | Type | Description |
|-------|------|-------------|
| `members` | `string[]` | Email addresses of the users to add to the group. Other values, such as a `User` claim's `username`, never match |
| `attributes` | `object` | Additional key/value attributes to set on the group. Each value is a `string[]`. |

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.group.id` | `string` | Group ID (uuid) assigned by the IdP |
| `status.group.name` | `string` | Confirmed group name |
| `status.group.created` | `boolean` | Whether the group was successfully created |
| `status.group.ready` | `boolean` | Whether the group is ready and accessible |
| `status.memberships.members` | `string[]` | List of members currently in the group |
| `status.memberships.ready` | `boolean` | Whether memberships are synchronised |
| `status.conditions` | `array` | Standard Kubernetes conditions |

## Examples

### Minimal

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: Group
metadata:
  name: engineering-team
spec:
  parameters: {}
```

### With Members

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: Group
metadata:
  name: engineering-team
spec:
  parameters:
    members:
      - alice@acmecorp.example.com
      - bob@acmecorp.example.com
      - charlie@acmecorp.example.com
```

### With Attributes

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: Group
metadata:
  name: platform-team
spec:
  parameters:
    attributes:
      department:
        - engineering
      costCentre:
        - cc-1234
```

## How-to Guide

[Create an IAM Group](../../how-to-guides/user/create-iam-group.md)
