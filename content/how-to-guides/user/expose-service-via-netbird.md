# How to Expose an Internal Service via the Mesh

Learn how to make an in-cluster service reachable from laptops and VMs on your organisation's Mesh — without a public endpoint.

Emma, a developer at ACME Corp, runs an internal admin API in her project. Her team needs to reach it from their laptops, but it must not be exposed to the internet. A NetbirdRouter advertises the service's address to Mesh peers, so enrolled devices reach it directly over the encrypted mesh.

> Platform services such as a [Vault](create-vault.md) are published to Mesh peers automatically — you only need a NetbirdRouter for your **own** services.

## Prerequisites

- A [Mesh](create-mesh.md) in your organisation, already Ready
- The `netbirdrouter.netbird.cloud.stakater.com` API available
- `kubectl` configured with your project kubeconfig
- The in-cluster Service you want to expose (note its ClusterIP)

## What Gets Created

When you create a NetbirdRouter claim, the platform provisions:

- A **routing peer** joined to your organisation's Mesh that advertises your routes
- Mesh **access policy** allowing holders of the client setup key to reach the advertised routes
- A **Secret** in your project containing the client setup key, named after the claim

## Step 1: Find the Service Address

```bash
kubectl get svc my-admin-api -o jsonpath='{.spec.clusterIP}'
```

## Step 2: Define a NetbirdRouter Claim

Create a file named `router.yaml`:

```yaml
apiVersion: netbird.cloud.stakater.com/v1
kind: NetbirdRouter
metadata:
  name: my-router
spec:
  parameters:
    routes:
      - name: admin-api
        address: 172.30.52.51/32        # the Service ClusterIP, as a /32
        description: "Internal admin API"
```

A router can advertise multiple routes — CIDRs, single hosts, or domains. See the [API reference](../../api-reference/public-apis/netbird-router.md) for all fields.

## Step 3: Apply the Claim

```bash
kubectl apply -f router.yaml
```

## Step 4: Verify the Router

```bash
kubectl get netbirdrouter my-router
```

Wait for `READY: True`. The routing peer also appears in your Mesh dashboard.

## Step 5: Connect a Device with the Setup Key

The platform delivers a Secret named after the claim (`my-router`) into your project. It contains the client setup key — share it with devices that should reach the advertised routes:

```bash
netbird up \
  --management-url=$(kubectl get mesh my-mesh -o jsonpath='{.status.mesh.mgmtURL}') \
  --setup-key=$(kubectl get secret my-router -o jsonpath='{.data.setupKey}' | base64 -d)
```

The device is automatically allowed to reach the routes — no dashboard configuration needed.

## Step 6: Test

From the enrolled device:

```bash
curl http://172.30.52.51/healthz
```

The request travels over the encrypted mesh to the routing peer, which forwards it to the in-cluster Service.

## Related

- [NetbirdRouter API reference](../../api-reference/public-apis/netbird-router.md)
- [Create a Mesh](create-mesh.md)
- [Create a Vault](create-vault.md) — published over the Mesh automatically
