# How to Expose an Internal Service via the Mesh

Learn how to make an in-cluster service reachable from laptops and VMs on your organisation's Mesh — without a public endpoint.

Emma, a developer at ACME Corp, runs an internal admin API in her project. Her team needs to reach it from their laptops, but it must not be exposed to the internet. A MeshRouter advertises the service's address to Mesh peers, and a MeshPolicy grants her team's group access — enrolled devices then reach it directly over the encrypted mesh.

> Platform services such as a [Vault](create-vault.md) are published to Mesh peers automatically — you only need a MeshRouter for your **own** services.

## Prerequisites

- A [Mesh](create-mesh.md) in your organisation, already Ready
- The `meshrouter.network.cloud.stakater.com` API available
- `kubectl` configured with your project kubeconfig
- The in-cluster Service you want to expose (note its ClusterIP)

## What Gets Created

When you create a MeshRouter claim, the platform provisions:

- A **routing peer** joined to your organisation's Mesh that advertises your routes
- A **peer group** named `<claim-name>-routers` holding the routing peer — the destination group for your access policies

Access is granted separately with a MeshPolicy (Step 5); devices authenticate to the Mesh with your organisation's single sign-on, so there are no keys to distribute.

## Step 1: Find the Service Address

```bash
kubectl get svc my-admin-api -o jsonpath='{.spec.clusterIP}'
```

## Step 2: Define a MeshRouter Claim

Create a file named `router.yaml`:

```yaml
apiVersion: network.cloud.stakater.com/v1
kind: MeshRouter
metadata:
  name: my-router
spec:
  parameters:
    routes:
      - name: admin-api
        address: 172.30.52.51/32        # the Service ClusterIP, as a /32
        description: "Internal admin API"
```

A router can advertise multiple routes — CIDRs, single hosts, or domains. See the [API reference](../../api-reference/public-apis/mesh-router.md) for all fields.

## Step 3: Apply the Claim

```bash
kubectl apply -f router.yaml
```

## Step 4: Verify the Router

```bash
kubectl get meshrouter my-router
```

Wait for `READY: True`. The routing peer also appears in your Mesh dashboard.

## Step 5: Grant Access with a MeshPolicy

Allow the Mesh groups that should reach the routes. The router's destination group is named after the claim (`my-router-routers`):

```yaml
apiVersion: network.cloud.stakater.com/v1
kind: MeshPolicy
metadata:
  name: allow-devs-to-my-router
spec:
  parameters:
    name: allow-devs-to-my-router
    rules:
      - name: devs-to-routes
        sourceGroupNames:
          - developers            # your users' Mesh group
        destinationGroupNames:
          - my-router-routers
```

```bash
kubectl apply -f policy.yaml
```

## Step 6: Test

From a device enrolled on the Mesh (see [Create a Mesh](create-mesh.md) for enrolment) and in an allowed group:

```bash
curl http://172.30.52.51/healthz
```

The request travels over the encrypted mesh to the routing peer, which forwards it to the in-cluster Service.

## Related

- [MeshRouter API reference](../../api-reference/public-apis/mesh-router.md)
- [Create a Mesh](create-mesh.md)
- [Create a Vault](create-vault.md) — published over the Mesh automatically
