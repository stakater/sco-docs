# How to Access Your Organisation's Vault

Learn how to sign in to the Vault (OpenBao) of your organisation and read the secrets the platform keeps there for your virtual machines, buckets and databases.

Emma, a developer at ACME Corp, has just created a database. The platform put its password in the organisation's Vault, and she needs to read it from her laptop without anyone handing her a token.

## Prerequisites

- A [Project](create-project.md) you have access to
- `kubectl` configured with your project kubeconfig
- The [OpenBao CLI](https://openbao.org/docs/install/) (or Vault CLI) for command-line access
- If your organisation runs a [Mesh](create-mesh.md): a device enrolled on it

## One Vault per Organisation

When an organisation is set up, the platform creates one Vault for it, named `<organisation>-default-bao`. You do not create a Vault yourself, and an organisation does not get a second one: every project, virtual machine, bucket and database of the organisation keeps its secrets in this Vault.

What you get:

- **Single sign-on** against your organisation's identity provider. There is no static root token to manage
- **A folder for each project**, which only the people with access to that project can open
- **The credentials of your services**, written there by the platform (see [What Is in the Vault](#what-is-in-the-vault))
- If your organisation runs a [Mesh](create-mesh.md): a stable DNS name (`bao.<organisation>.mesh.<cluster-domain>`) with a publicly-trusted TLS certificate, reachable only from Mesh peers

If your organisation has no Vault, your platform administrator has turned it off. Ask them to enable it (see [Creating Organizations](../../service-provider-guide/organizations/creating-organizations.md)).

## Step 1: Find the Address and Your Role

The project status carries everything you need to sign in:

```bash
kubectl get project my-project -o jsonpath='{.status.openbao}'
```

```json
{"available":true,"address":"https://bao.acme.mesh.example.com","secretPath":"stakater/projects/acme-my-project/","roles":["acme-my-project-rw-users"],"message":"Log in to your organization's OpenBao with OIDC and one of the listed roles"}
```

- `address` is the URL to open or to point the CLI at
- `roles` lists the roles you can sign in with for this project
- `secretPath` is the project folder

In the console, the Vault is under **Secrets** in the sidebar:

![The Vaults list in the console, showing the default Vault of the organisation]({{ screenshot: vault-list }})

Its detail page shows the same address under **Endpoint**, below the status conditions:

![The lower part of a Vault detail page, showing the status conditions and the Endpoint block with the Mesh address]({{ screenshot: vault-detail }})

If **Address** is empty, as it is here, the Vault is published on the Mesh only. Use the **Mesh Address** from a device enrolled on the Mesh. The name resolves from anywhere but is reachable only from enrolled Mesh peers, and the certificate is publicly trusted, so clients need no custom CA bundle and no `-tls-skip-verify`.

## Step 2: Sign In with OIDC

You sign in as your organisation user and choose a **role**; the role decides what you can reach. Signing in without one succeeds but grants nothing.

**Web UI:** open the address in a browser, choose method **OIDC**, enter the role in **Role**, and sign in.

**CLI:**

```bash
export BAO_ADDR=$(kubectl get project my-project -o jsonpath='{.status.openbao.address}')
bao login -method=oidc role=acme-my-project-rw-users
```

This opens your browser, completes single sign-on, and writes a token to the local CLI. A sign-in lasts one hour; sign in again with the role when it expires.

Which roles you get follows the project's `access` entries. See [Project access](../../api-reference/public-apis/vault.md#project-access).

## Step 3: Read a Secret

The role gives you your project's folder, `stakater/projects/<organisation>-<project>/`. In the web UI, browse `stakater` → `projects/` → your project. From the CLI:

```bash
bao kv get -mount=stakater projects/acme-my-project/vms/my-windows-vm
```

With a role that can write, you can also keep secrets of your own in the folder:

```bash
bao kv put -mount=stakater projects/acme-my-project/app/config user=app password=s3cret
```

## What Is in the Vault

Each service guide names the exact path in the status of its claim:

| Service | What the platform stores | Where to find the path |
|---|---|---|
| [Windows virtual machine](provision-windows-virtual-machine.md#step-6-get-the-administrator-password) | The generated Administrator password | `status.adminCredentials.secretPath` |
| [S3 bucket](create-s3-bucket.md#step-4-read-the-credentials) | Access key, secret key and endpoint | `status.bucket.credentialsRef` |
| [Postgres database](create-postgres.md#step-4-read-the-credentials) | Username, password and connection URIs | `status.connection.credentialsRef` |

## Related

- [Vault reference](../../api-reference/public-apis/vault.md) - Roles, project folders and the organisation folder
- [Create a Mesh](create-mesh.md)
- [One Identity Across Your Organisation](../../cloud-user-guide/authentication/organisation-identity.md)
