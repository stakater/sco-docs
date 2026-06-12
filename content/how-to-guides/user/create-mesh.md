# How to Create a Mesh

Learn how to provision a private mesh network for your organisation and enrol your first device.

Emma, a developer at ACME Corp, wants her team's laptops to reach internal services — a Vault, staging APIs, databases — without VPN appliances or public endpoints. A Mesh gives every enrolled device an encrypted, peer-to-peer network governed by her organisation's single sign-on.

## Prerequisites

- A [Project](create-project.md) already created
- The `mesh.network.cloud.stakater.com` API available
- `kubectl` configured with your project kubeconfig
- The [NetBird client](https://docs.netbird.io/how-to/installation) on any device you want to enrol

> Your organisation may already include a Mesh by default — check with your organisation administrator before creating one.

## What Gets Created

When you create a Mesh claim, the platform provisions:

- A private **mesh network** for your organisation — management, signalling, and relay infrastructure
- A **web dashboard** for managing peers, groups, and access policies, behind your organisation's single sign-on
- Automatic publishing of platform services (such as a [Vault](create-vault.md)) to Mesh peers, with publicly-trusted TLS

## Step 1: Define a Mesh Claim

Create a file named `mesh.yaml`:

```yaml
apiVersion: network.cloud.stakater.com/v1
kind: Mesh
metadata:
  name: my-mesh
spec:
  parameters: {}
```

That's the entire claim — the Mesh takes no user-tunable fields.

## Step 2: Apply the Claim

```bash
kubectl apply -f mesh.yaml
```

## Step 3: Verify the Mesh

```bash
kubectl get mesh my-mesh
```

Wait for `READY: True`, then read the endpoints:

```bash
kubectl get mesh my-mesh -o jsonpath='{.status.mesh.dashboardURL}'
kubectl get mesh my-mesh -o jsonpath='{.status.mesh.mgmtURL}'
```

## Step 4: Open the Dashboard

Open `dashboardURL` in a browser and sign in with your organisation account. From here you manage peers, define groups, write access policies, and generate setup keys.

## Step 5: Enrol a Device

Install the NetBird client on a laptop, then:

```bash
netbird up \
  --management-url=$(kubectl get mesh my-mesh -o jsonpath='{.status.mesh.mgmtURL}')
```

This opens a browser for single sign-on — leave the command running until the browser flow completes, and use a private window if you need to enrol as a different user than your current browser session. See [One Identity Across Your Organisation](../../cloud-user-guide/authentication/organisation-identity.md) for enrolment caveats and multi-account profiles. After registration the device appears in the dashboard and can be assigned to groups.

## Step 6: Reach Services over the Mesh

- **Platform services** are published automatically. With a [Vault](create-vault.md) in your organisation, an enrolled laptop reaches it at `https://bao.<organisation>.mesh.<cluster-domain>` with a publicly-trusted certificate.
- **Your own services** can be advertised to Mesh peers with a [NetbirdRouter](expose-service-via-netbird.md).

## Related

- [Mesh API reference](../../api-reference/public-apis/mesh.md)
- [Expose an internal service via the Mesh](expose-service-via-netbird.md)
- [Create a Vault](create-vault.md)
