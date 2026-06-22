# How to Create a Vault

Learn how to provision a private Vault (OpenBao) instance for your organisation and log in with single sign-on.

Emma, a developer at ACME Corp, needs a secrets manager her team can reach from CI and from their laptops — without managing root tokens or exposing anything to the public internet.

## Prerequisites

- A [Project](create-project.md) already created
- The `vault.secrets.cloud.stakater.com` API available
- `kubectl` configured with your project kubeconfig
- The [OpenBao CLI](https://openbao.org/docs/install/) (or Vault CLI) for command-line access

## What Gets Created

When you create a Vault claim, the platform provisions:

- A **highly-available Vault (OpenBao) instance**, private to your organisation
- **Single sign-on** against your organisation's identity provider — there is no static root token to manage
- A web UI and API endpoint, published in the claim's status
- If your organisation runs a [Mesh](create-mesh.md): a stable DNS name (`bao.<organisation>.mesh.<cluster-domain>`) with a publicly-trusted TLS certificate, reachable only from Mesh peers

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

## Step 4: Log In

Open the endpoint URL in a browser and sign in with your organisation account, or use the CLI:

```bash
export BAO_ADDR=$(kubectl get vault my-vault -o jsonpath='{.status.endpoint.address}')
bao login -method=oidc
```

This opens your browser, completes single sign-on, and writes a token to the local CLI. Access is scoped by your organisation group membership.

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
bao login -method=oidc
```

## Related

- [Vault API reference](../../api-reference/public-apis/vault.md)
- [Create a Mesh](create-mesh.md)
