# How to Connect Your Company Identity Provider

Let your people sign in to your organisation with the identity provider your company already uses, such as `Okta` or Microsoft `Entra` ID.

Maria, an IT administrator at ACME Corp, wants her colleagues to sign in to SCO with their company `Okta` accounts. When she disables a leaver in `Okta`, that person must lose access to SCO too.

!!! note
    In this guide, *company identity provider* means the system your company already uses for sign-in. *Organisation sign-in* means the SCO sign-in page of your organisation.

## How It Works

- You list the email domains that your company identity provider is responsible for, for example `acme.example`.
- On the organisation sign-in page, users type their email address first. Users whose domain you listed go straight to your company identity provider. Everyone else, including your platform provider's staff, keeps signing in as before.
- You keep the client ID and client secret of your application in your organisation's Vault, in a folder that only organisation administrators can open. You never send the client secret to anyone.
- At a user's first sign-in, the platform creates an organisation user for them. This user has no password: they always sign in through your company identity provider.
- The same sign-in works everywhere your organisation reaches: the SCO console, the Mesh, Vault and cluster consoles. See [One Identity Across Your Organisation](../../cloud-user-guide/authentication/organisation-identity.md).
- Signing in does not give access. You give access by email address, in groups and projects. See [Step 7](#step-7-give-your-users-access).

## Prerequisites

- You are an administrator of your organisation
- The `identityprovider.iam.cloud.stakater.com` API available
- Your organisation has a [Vault](create-vault.md). If your organisation runs a [Mesh](create-mesh.md), the Vault is reachable only from Mesh peers, so you also need the Mesh client on your computer.
- Administrator access to your company identity provider, to create an OpenID Connect (OIDC) web application
- Every user who will sign in has an email address in one of your domains, and your company identity provider sends that address
- `kubectl` configured with your organisation project kubeconfig, if you use the command line

## What Gets Created

When you create an IdentityProvider claim, and the client credentials are in your Vault, the platform provisions:

- A copy of the client ID and client secret, kept in step with your Vault
- A connection from your organisation sign-in to your company identity provider
- Ownership of the listed email domains, so users of those domains go to your company identity provider

!!! note
    When the first identity provider of your organisation is ready, the organisation sign-in page asks **every** user for their email address first. Users of other domains then see the password field, as before. Tell your users before you start.

## Step 1: Choose a Name and Your Domains

**The name** is the claim's `metadata.name`. It appears in the redirect URIs of your application, so it cannot change later.

- Use 1 to 32 lower-case letters, digits or `-`, starting and ending with a letter or digit.
- `stakater-admins` is reserved for your platform provider's staff.
- Never give a name to a *different* company identity provider after you have removed one with that name. The platform remembers which users signed in through each name, and the new identity provider would sign in as those users. Choose a new name instead.

**The domains** are the email domains of the users who sign in through this identity provider.

- Write them in lower case, for example `acme.example`.
- A domain can belong to only one identity provider in your organisation.
- `stakater.com`, `stakater.cloud` and their subdomains are refused.

## Step 2: Find the Endpoints of Your Company Identity Provider

Open the discovery document of your company identity provider: `<issuer>/.well-known/openid-configuration`. Copy these values from it:

| Discovery field | Claim parameter |
|-----------------|-----------------|
| `issuer` | `issuer` |
| `authorization_endpoint` | `authorizationUrl` |
| `token_endpoint` | `tokenUrl` |
| `jwks_uri` | `jwksUrl` |
| `userinfo_endpoint` | `userInfoUrl` (optional) |
| `end_session_endpoint` | `logoutUrl` (optional) |

Every endpoint must use `https` and the same host as `issuer`, and that host must be a public name. The platform sends your client secret only to that host.

!!! tip "`Okta`"
    With the org authorization server, the issuer is `https://<your-okta-domain>` and the endpoints are under `https://<your-okta-domain>/oauth2/v1/`. With a custom authorization server, both include its path, for example `/oauth2/default`. Copy the values from the discovery document; do not build them by hand.

!!! tip "Microsoft `Entra` ID"
    The issuer is `https://login.microsoftonline.com/<tenant-id>/v2.0`. Leave `userInfoUrl` empty: `Entra` serves user information from `graph.microsoft.com`, which is not the issuer's host. The platform reads the user's details from the sign-in token instead.

## Step 3: Create the IdentityProvider

The claim names the Vault entry that will hold the client credentials, for example `idp/acme-okta`. You store the credentials there in [Step 5](#step-5-store-the-client-credentials-in-your-vault), after you have created the application.

### In the Console

1. Go to **All services > IAM > Identity Providers** and click **Create**.
1. Fill in the name, the domains and the endpoints from Steps 1 and 2.
1. Under **Credentials**, set **Secret Path** to the Vault entry, for example `idp/acme-okta`.
1. Tick **Enabled** and **Redirect On Email Match**.
1. Click **Create**.

!!! note
    The form shows **Enabled** and **Redirect On Email Match** as empty checkboxes, although both default to on. An empty checkbox can save `false`, so tick both yourself.

### With kubectl

Create a file named `identity-provider.yaml`:

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: IdentityProvider
metadata:
  name: acme-okta
spec:
  parameters:
    displayName: ACME Okta
    domains:
      - acme.example
    issuer: https://acme.okta.com
    authorizationUrl: https://acme.okta.com/oauth2/v1/authorize
    tokenUrl: https://acme.okta.com/oauth2/v1/token
    jwksUrl: https://acme.okta.com/oauth2/v1/keys
    userInfoUrl: https://acme.okta.com/oauth2/v1/userinfo
    credentials:
      secretPath: idp/acme-okta
```

```bash
kubectl apply -f identity-provider.yaml
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `parameters.domains` | Yes | - | Lower-case email domains routed to this identity provider (1–20) |
| `parameters.issuer` | Yes | - | Issuer URL, exactly as in the discovery document |
| `parameters.authorizationUrl` | Yes | - | Authorization endpoint, on the issuer's host |
| `parameters.tokenUrl` | Yes | - | Token endpoint, on the issuer's host |
| `parameters.jwksUrl` | Yes | - | JSON Web Key Set URL, on the issuer's host |
| `parameters.credentials.secretPath` | Yes | - | Path of the Vault entry inside the organisation folder `stakater/org/`, for example `idp/acme-okta` |
| `parameters.userInfoUrl` | No | - | User information endpoint, on the issuer's host |
| `parameters.logoutUrl` | No | - | End-session endpoint, on the issuer's host |
| `parameters.displayName` | No | the claim name | Name shown for the identity provider |
| `parameters.enabled` | No | `true` | `false` stops sign-in through this identity provider and keeps its users |
| `parameters.defaultScopes` | No | `openid profile email` | Scopes requested at sign-in; keep `openid` and `email` |
| `parameters.redirectOnEmailMatch` | No | `true` | Send users of the listed domains straight to the identity provider; when `false`, the sign-in page shows a button instead |

The claim is not ready yet. Its status says that it waits for the credentials in Vault, and it lists the redirect URIs for the next step.

## Step 4: Create the Application in Your Company Identity Provider

Read the redirect URIs from the claim's detail page in the console, or with `kubectl`:

```bash
kubectl get identityprovider acme-okta \
  -o jsonpath='{range .status.redirectUris[*]}{@}{"\n"}{end}'
```

In your company identity provider, create an OIDC web application with these settings:

| Setting | Value |
|---------|-------|
| Application type | Web application, authorization code flow, with a client secret |
| Redirect URIs | **Every** URI from the status. The platform can serve your organisation sign-in under more than one address. |
| Scopes | `openid`, `profile` and `email` |
| Email | The sign-in token must contain the user's `email` |
| Users | Assign the application to the people who will sign in |

!!! tip "Microsoft `Entra` ID"
    `Entra` sends `email` only when you add it as an optional claim of the ID token (**Token configuration > Add optional claim > ID > email**). Each user must also have their **Email** attribute set.

## Step 5: Store the Client Credentials in Your Vault

The organisation folder `stakater/org/` of your Vault holds what belongs to the whole organisation. Only organisation administrators can open it, and project roles cannot.

1. If your organisation runs a Mesh, connect to it first.
1. Open your Vault in a browser. Its address is in the status of your Vault claim.
1. Choose method **OIDC**, type `org-admins` in **Role**, and sign in.
1. Open `<vault-address>/ui/vault/secrets/stakater/create/?initialKey=org/<secretPath>`, for example `…/create/?initialKey=org/idp/acme-okta`.
1. Add two keys, spelled exactly like this, and save:

| Key | Value |
|-----|-------|
| `clientId` | The client ID of your application |
| `clientSecret` | The client secret of your application |

The platform copies only these two keys. The identity provider becomes ready within about five minutes.

!!! note
    Signing in to Vault from the command line with `bao login -method=oidc` does not work for the `org-admins` role. Sign in with the browser instead. To use the CLI, copy the token from the browser (**user menu > Copy token**) and run `bao login <token>`.

## Step 6: Verify

Check the claim:

```bash
kubectl get identityprovider acme-okta \
  -o jsonpath='{.status.ready}{" "}{.status.message}{"\n"}'
```

Expected output once ready:

```text
true
```

The console shows the same status on the claim's detail page.

Then test a sign-in:

1. Open a private browser window.
1. Open your organisation's console URL.
1. Type the email address of a user in one of your domains.
1. Make sure that the browser goes straight to your company identity provider, and back to SCO after the sign-in.

The user has no access yet, so the console can show no projects.

## Step 7: Give Your Users Access

Users from your company identity provider have no `User` claim. You give them access by their email address, the same way as other users:

- Add the email address to the `members` of a [group](create-iam-group.md), and grant the group a role in a [project](create-project.md).
- Or add the email address to the `users` of a project's `access` list.

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: Group
metadata:
  name: acme-engineers
spec:
  parameters:
    name: acme-engineers
    members:
      - maria@acme.example
      - tom@acme.example
```

!!! note
    You can add a user to a group before their first sign-in. The membership applies after their first sign-in, within about 15 minutes. Until then, the group already lists the user, but the user does not have the group's access yet.

!!! note
    Do not create a `User` claim for an email address in one of your domains. That user gets a password and signs in without your company identity provider.

## Users Who Already Have a Password

Users who had a password in your organisation before you connected your company identity provider keep signing in with that password. The platform does not move them automatically.

Ask your platform provider to move them. A moved user keeps the same organisation user, so their groups and access stay the same. Depending on your company identity provider, your platform provider either links the accounts for you, or sends the user a link to confirm once with their current password.

## Change, Rotate, Switch Off or Remove

**Change:** Edit the claim in the console or with `kubectl`. The name cannot change. If a change fails a check, the identity provider keeps working as before, and the status message starts with `change not applied:`.

**Rotate the client secret:** Create a new client secret in your company identity provider and save it as `clientSecret` in the same Vault entry. The platform uses the new secret within about 15 minutes, so keep the old secret valid until then.

**Switch off:** Set `enabled` to `false`. Sign-in through the identity provider stops, and its users and their links stay. Users of its domains cannot sign in until you set `enabled` back to `true`.

!!! warning
    **Removing** the claim removes every organisation user that was created through it. If you create it again, these people come back as new users. Use `enabled: false` to pause, and talk to your platform provider before you remove an identity provider.

## Troubleshooting

| Message or symptom | Cause | Fix |
|--------------------|-------|-----|
| `credentials is required: …` | The claim names no Vault entry | Set `credentials.secretPath`, see [Step 3](#step-3-create-the-identityprovider) |
| `your organisation has no Vault; …` | Your organisation has no Vault yet | Ask your platform provider to enable it |
| `waiting for your organisation's Vault …` | The Vault is still being set up | Wait a few minutes |
| `waiting for the credentials in Vault stakater/org/… (keys clientId and clientSecret): …` | The entry does not exist yet, or a key is missing or misspelled | Store both keys, see [Step 5](#step-5-store-the-client-credentials-in-your-vault) |
| `credentials.secretPath must be '/'-separated segments …` | The path has characters that are not allowed | Use letters, digits, `.`, `_` and `-`, for example `idp/acme-okta` |
| `credentials in Vault … cannot be read, the last copy is in use` | The Vault was unreachable at the last copy | Sign-in keeps working with the last copy; check the entry and your Vault |
| `issuer and endpoints must use a public host: …` | An endpoint uses an IP address or an internal name | Use the public names from the discovery document |
| `endpoints must use https and the issuer host …` | An endpoint is on another host | Copy the endpoints from the discovery document. For `Entra`, leave `userInfoUrl` empty. |
| `name … is reserved` or `name must be 1 to 32 …` | The claim name is not allowed | Create the claim again with another name |
| `refused the change: Domain … is already linked to another organization` | Another identity provider of your organisation owns one of the domains | Remove the domain from one of the two |
| `change not applied: …` | The last change failed the check after the colon | Correct the change; the identity provider works as before |
| Vault shows `permission denied` or an empty list | You signed in without the `org-admins` role, or you are not an organisation administrator | Sign in again with role `org-admins`, and open the entry by its link |
| Microsoft `AADSTS50011` | A redirect URI is missing in the application | Add every URI from the status |
| `Email domain does not match any domain from the organization` | The user's email address is outside the listed domains | Add the domain, or correct the user's email address |
| A user of your domain sees the password field | The user had a password before, or `redirectOnEmailMatch` is off | Ask your platform provider to move the user, or set `redirectOnEmailMatch` to `true` |

## Full Examples

### `Okta`

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: IdentityProvider
metadata:
  name: acme-okta
spec:
  parameters:
    displayName: ACME Okta
    domains:
      - acme.example
    issuer: https://acme.okta.com
    authorizationUrl: https://acme.okta.com/oauth2/v1/authorize
    tokenUrl: https://acme.okta.com/oauth2/v1/token
    jwksUrl: https://acme.okta.com/oauth2/v1/keys
    userInfoUrl: https://acme.okta.com/oauth2/v1/userinfo
    logoutUrl: https://acme.okta.com/oauth2/v1/logout
    credentials:
      secretPath: idp/acme-okta
```

### Microsoft `Entra` ID

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: IdentityProvider
metadata:
  name: acme-entra
spec:
  parameters:
    displayName: ACME Entra ID
    domains:
      - acme.example
    issuer: https://login.microsoftonline.com/<tenant-id>/v2.0
    authorizationUrl: https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/authorize
    tokenUrl: https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token
    jwksUrl: https://login.microsoftonline.com/<tenant-id>/discovery/v2.0/keys
    credentials:
      secretPath: idp/acme-entra
```

## What's Next?

- [Managing Users](../../cloud-user-guide/authentication/managing-users.md) - How users from your company identity provider fit next to other users
- [Create an IAM Group](create-iam-group.md) - Give users from your company identity provider access through groups
- [Create a Project](create-project.md) - Grant groups and users roles in a project
- [Create a Vault](create-vault.md) - Set up the Vault that holds the client credentials
- [IdentityProvider API reference](../../api-reference/public-apis/iam-identity-provider.md) - Every parameter and status field
