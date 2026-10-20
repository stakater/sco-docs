# IAM IdentityProvider

Connects your company's OpenID Connect identity provider, such as `Okta` or Microsoft `Entra` ID, to your organisation sign-in. Users whose email domain you list sign in through it; everyone else keeps signing in as before.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `iam.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `IdentityProvider` |
| **Scope** | Namespace-scoped |

The claim name (`metadata.name`) is the identity provider's name in its redirect URIs. It cannot change. It must be 1 to 32 lower-case letters, digits or `-`, and `stakater-admins` is reserved.

## Spec Parameters

All parameters are nested under `spec.parameters`.

### Required

| Field | Type | Description |
|-------|------|-------------|
| `domains` | `string[]` | Lower-case email domains whose users sign in through this identity provider (1–20). A domain can belong to only one identity provider in your organisation. `stakater.com`, `stakater.cloud` and their subdomains are refused. |
| `issuer` | `string` | Issuer URL, exactly as in the identity provider's discovery document. Must use `https`. |
| `authorizationUrl` | `string` | Authorization endpoint. Must use `https` and the issuer's host. |
| `tokenUrl` | `string` | Token endpoint. Must use `https` and the issuer's host. |
| `jwksUrl` | `string` | JSON Web Key Set URL. Must use `https` and the issuer's host. |

### Optional

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | `boolean` | `true` | `false` stops sign-in through this identity provider. Its users and their links stay, so `true` restores sign-in. |
| `displayName` | `string` | the claim name | Name shown for the identity provider (up to 100 characters) |
| `userInfoUrl` | `string` | - | Userinfo endpoint. Must use `https` and the issuer's host. Leave it empty for Microsoft `Entra` ID. |
| `logoutUrl` | `string` | - | End-session endpoint. Must use `https` and the issuer's host. |
| `defaultScopes` | `string` | `openid profile email` | Space-separated scopes requested at sign-in. Keep `openid` and `email`: users are matched by their email address. |
| `redirectOnEmailMatch` | `boolean` | `true` | Send users of the listed domains straight to this identity provider. When `false`, the sign-in page shows a button for it instead. |

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.ready` | `boolean` | Whether the identity provider is in place and users can sign in through it |
| `status.message` | `string` | Why the identity provider is not ready, or which change was not applied. Empty when all is well. |
| `status.redirectUris` | `string[]` | Register **every** URI in your identity provider's application |
| `status.secretName` | `string` | Name under which your platform provider stores the client credentials |
| `status.organizationId` | `string` | ID that the platform gives to the set of domains of this identity provider |
| `status.conditions` | `array` | Standard Kubernetes conditions |

The console badge shows **ready**, **progressing** while the identity provider waits for its client credentials, **error** when a check fails, and **warning** when the identity provider works but its last change was not applied.

## Behaviour

- Nothing is created until your platform provider has stored the client ID, the client secret and the approved issuer. The claim's `issuer` must match the approved issuer.
- When a change to a working identity provider fails a check, nothing changes and the identity provider keeps working. `status.message` starts with `change not applied:`.
- At a user's first sign-in, the platform creates an organisation user without a password.
- Removing the claim removes every organisation user that was created through it.

## Examples

### `Okta`

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: IdentityProvider
metadata:
  name: nordwind-okta
spec:
  parameters:
    displayName: Nordwind Okta
    domains:
      - nordwind.example
    issuer: https://nordwind.okta.com
    authorizationUrl: https://nordwind.okta.com/oauth2/v1/authorize
    tokenUrl: https://nordwind.okta.com/oauth2/v1/token
    jwksUrl: https://nordwind.okta.com/oauth2/v1/keys
    userInfoUrl: https://nordwind.okta.com/oauth2/v1/userinfo
```

### Microsoft `Entra` ID

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: IdentityProvider
metadata:
  name: nordwind-entra
spec:
  parameters:
    displayName: Nordwind Entra ID
    domains:
      - nordwind.example
    issuer: https://login.microsoftonline.com/<tenant-id>/v2.0
    authorizationUrl: https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/authorize
    tokenUrl: https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token
    jwksUrl: https://login.microsoftonline.com/<tenant-id>/discovery/v2.0/keys
```

## How-to Guide

[Connect Your Company Identity Provider](../../how-to-guides/user/connect-identity-provider.md)
