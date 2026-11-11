# How to Create a Vault

Learn how to provision a private Vault (OpenBao) instance for your organisation and log in with single sign-on.

Emma, a developer at ACME Corp, needs a secrets manager her team can reach from CI and from their laptops — without managing root tokens or exposing anything to the public internet.

## Prerequisites

- A [Project](create-project.md) already created
- The `vault.secrets.cloud.stakater.com` API available
- `kubectl` configured with your project kubeconfig
- The [OpenBao CLI](https://openbao.org/docs/install/) (or Vault CLI) for command-line access

## Your Organisation Probably Has One Already

When an organisation is set up, the platform creates a default Vault for it, named `<organisation>-default-bao`. Your platform administrator controls this with the `bao.enabled` setting on the organisation, which is on unless they turned it off (see [Creating Organizations](../../service-provider-guide/organizations/creating-organizations.md)).

An organisation is meant to have one Vault: projects, databases and buckets all keep their secrets in it. Check the Vaults list first. If the default Vault is there, do not create another: skip to [Step 3](#step-3-verify-the-vault) and use its name in place of `my-vault`. Create a Vault with the steps below only if your organisation has none.

## What Gets Created

When you create a Vault claim, the platform provisions:

- A **highly-available Vault (OpenBao) instance**, private to your organisation
- **Single sign-on** against your organisation's identity provider — there is no static root token to manage
- A web UI and API endpoint, published in the claim's status
- If your organisation runs a [Mesh](create-mesh.md): a stable DNS name (`bao.<organisation>.mesh.<cluster-domain>`) with a publicly-trusted TLS certificate, reachable only from Mesh peers

## In the Console

Vaults are under **Secrets** in the sidebar. Check the list before you create anything. Here it shows the default Vault of the `acme` organisation:

![The Vaults list in the console, showing the default Vault of the organisation]({{ screenshot: vault-list }})

The create form asks for a project and a name, the same as the minimal claim below. The storage sizes are filled in with their defaults, and **Mesh Access** takes the extra groups described in Step 1:

![The Create Vault form, with the name filled in and the default storage sizes]({{ screenshot: vault-create }})

## Step 1: Define a Vault Claim

Create a file named `vault.yaml`:

```yaml
apiVersion: secrets.cloud.stakater.com/v1
kind: Vault
metadata:
  name: my-vault
spec:
  parameters: {}
```

`spec.parameters` can stay empty. To size storage explicitly:

```yaml
spec:
  parameters:
    storage:
      dataSize: 50Gi
      auditSize: 20Gi
```

Without these, the data volume is `15Gi` and the audit volume is `10Gi`.

If your organisation runs a [Mesh](create-mesh.md), `meshAccess.groups` lists further organisation groups whose members may reach the Vault over the Mesh, on top of those your organisation already allows. It opens the network path only: signing in and the role you choose still decide which secrets you can read.

```yaml
spec:
  parameters:
    meshAccess:
      groups:
        - engineering-team
```

## Step 2: Apply the Claim

```bash
kubectl apply -f vault.yaml
```

## Step 3: Verify the Vault

```bash
kubectl get vault my-vault
```

Wait for `READY: True`, then read the endpoint:

```bash
kubectl get vault my-vault -o jsonpath='{.status.endpoint.address}'
```

The same addresses are on the Vault detail page in the console, under **Endpoint**, below the status conditions:

![The lower part of a Vault detail page, showing the status conditions and the Endpoint block with the Mesh address]({{ screenshot: vault-detail }})

If **Address** is empty, as it is here, the Vault is published on the Mesh only. Use the **Mesh Address** instead, as described in [Step 5](#step-5-optional-reach-it-over-the-mesh), from a device enrolled on the Mesh.

## Step 4: Log In

You sign in as your organisation user and choose a **role**; the role decides what you can reach. Signing in without one succeeds but grants nothing. Each project you have access to has its own roles. Look them up on the project:

```bash
kubectl get project my-project -o jsonpath='{.status.openbao.roles}'
```

```text
["acme-my-project-rw-users"]
```

Open the endpoint URL in a browser, choose method **OIDC**, enter the role in **Role**, and sign in. Or use the CLI:

```bash
export BAO_ADDR=$(kubectl get vault my-vault -o jsonpath='{.status.endpoint.address}')
bao login -method=oidc role=acme-my-project-rw-users
```

This opens your browser, completes single sign-on, and writes a token to the local CLI. The role gives you your project's folder, `stakater/projects/<organisation>-<project>/`:

```bash
bao kv put -mount=stakater projects/acme-my-project/app/config user=app password=s3cret
```

Which roles you get follows the project's `access` entries — see [Project access](../../api-reference/public-apis/vault.md#project-access).

## Step 5 (Optional): Reach It over the Mesh

If your organisation runs a [Mesh](create-mesh.md), the Vault is also published to Mesh peers automatically. The Mesh endpoint appears in the claim status once it is live:

```bash
kubectl get vault my-vault -o jsonpath='{.status.endpoint.meshAddress}'
```

```text
https://bao.<organisation>.mesh.<cluster-domain>
```

The name resolves from anywhere but is reachable only from enrolled Mesh peers, and the certificate is publicly trusted — clients need no custom CA bundle and no `-tls-skip-verify`:

```bash
export BAO_ADDR=$(kubectl get vault my-vault -o jsonpath='{.status.endpoint.meshAddress}')
bao login -method=oidc role=acme-my-project-rw-users
```

## Related

- [Vault API reference](../../api-reference/public-apis/vault.md)
- [Create a Mesh](create-mesh.md)
