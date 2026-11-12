# How to Expose an Internal Service via the Mesh

Learn how to make an internal service reachable from laptops and VMs on your organisation's Mesh — without a public endpoint.

Emma, a developer at ACME Corp, runs an internal admin API. Her team needs to reach it from their laptops, but it must not be exposed to the internet. A MeshRouter advertises the service's address to Mesh peers, and a MeshPolicy grants her team's group access — enrolled devices then reach it directly over the encrypted mesh.

> Platform services such as a [Vault](create-vault.md) are published to Mesh peers automatically — you only need a MeshRouter for your **own** services.

!!! warning "Current limitations — read before you start"
    This guide does **not** yet work end to end for workloads in your projects. MeshRouter and MeshPolicy claims created **inside a project** do not take effect: the router claim reports Ready, but it never joins the Mesh and its `<claim-name>-routers` group is never created, so this guide creates both claims with your **organisation** kubeconfig. A router created that way joins the Mesh and your laptop receives the route, but the router runs outside your projects' networks, so connections to a project virtual machine, or to a Service inside an OpenShift cluster you provisioned, time out. The VM's built-in Mesh Route (`meshRoute.enabled: true` on a [VirtualMachine](../../api-reference/public-apis/virtual-machine.md)) is the intended way to reach a project VM, but it opens only SSH (tcp/22), RDP (tcp/3389) and ICMP, and it does not deliver traffic yet either. Until these are fixed there is no supported way to reach your own project workloads privately over the Mesh: use the steps below only for an address the router can actually reach, and check Step 6 before relying on it.
    <!-- Tracked internally: SA-9272, SA-9273 (SA-8708). Remove this limitation when fixed. -->

## Prerequisites

- A [Mesh](create-mesh.md) in your organisation, already Ready
- The `meshrouter.mesh.cloud.stakater.com` and `meshpolicy.mesh.cloud.stakater.com` APIs available
- `kubectl` configured with your **organisation** kubeconfig, for the MeshRouter and MeshPolicy claims (Steps 2–5)
- Access to wherever the service runs, to look up its address (Step 1) — for a Service inside an OpenShift cluster you provisioned, that is the cluster's own kubeconfig, not your project or organisation kubeconfig
- A laptop enrolled on the Mesh and signed in as a member of the group you will grant access to (see [Create a Mesh](create-mesh.md))

### Which kubeconfig each step uses

| Step | What you do | kubeconfig |
|------|-------------|------------|
| 1 | Look up the service address | The cluster the service runs in |
| 2–4 | Create and check the MeshRouter | Organisation |
| 5 | Create the MeshPolicy | Organisation |
| 6 | Test | None — run from your enrolled laptop |

## What Gets Created

When you create a MeshRouter claim, the platform provisions:

- A **routing peer** joined to your organisation's Mesh that advertises your routes
- A **peer group** named `<claim-name>-routers` holding the routing peer — the destination group for your access policies

Access is granted separately with a MeshPolicy (Step 5); devices authenticate to the Mesh with your organisation's single sign-on, so there are no keys to distribute.

## Step 1: Find the Service Address

Run this against the cluster where the service runs:

```bash
kubectl --kubeconfig <cluster-kubeconfig> get svc my-admin-api -o jsonpath='{.spec.clusterIP}'
```

!!! note
    Service ClusterIP ranges (typically `172.30.0.0/16`) are the same on every OpenShift cluster, so a ClusterIP alone does not say which cluster it belongs to. The router forwards to the address from where the router itself runs, not from inside your cluster.

## Step 2: Define a MeshRouter Claim

Create a file named `router.yaml`:

```yaml
apiVersion: mesh.cloud.stakater.com/v1
kind: MeshRouter
metadata:
  name: my-router
spec:
  parameters:
    routes:
      - name: admin-api
        address: 172.30.52.51/32        # the service address from Step 1, as a /32
        description: "Internal admin API"
```

A router can advertise multiple routes — CIDRs, single hosts, or domains. See the [MeshRouter API reference](../../api-reference/public-apis/mesh-router.md) for all fields.

## Step 3: Apply the Claim

With your organisation kubeconfig:

```bash
kubectl apply -f router.yaml
```

## Step 4: Verify the Router

```bash
kubectl get meshrouter my-router
```

Wait for `READY: True`. The routing peer also appears in your Mesh dashboard, together with a group named `my-router-routers`. If that group does not appear, the router has not joined the Mesh — see the limitations above.

## Step 5: Grant Access with a MeshPolicy

Allow the groups that should reach the routes. The router's destination group is named after the claim (`my-router-routers`). Create a file named `policy.yaml`:

```yaml
apiVersion: mesh.cloud.stakater.com/v1
kind: MeshPolicy
metadata:
  name: allow-devs-to-my-router
spec:
  parameters:
    name: allow-devs-to-my-router
    rules:
      - name: devs-to-routes
        sourceGroupNames:
          - developers            # your users' group
        destinationGroupNames:
          - my-router-routers
```

Apply it with your organisation kubeconfig and check that it is Ready:

```bash
kubectl apply -f policy.yaml
kubectl get meshpolicy allow-devs-to-my-router
```

A group can only be used as a source once at least one of its members has signed in to the Mesh. See the [MeshPolicy API reference](../../api-reference/public-apis/mesh-policy.md) for ports, protocols and one-way rules.

## Step 6: Test

From a device enrolled on the Mesh and signed in as a member of an allowed group, first check that the route arrived:

```bash
netbird networks list
```

A network named after the router and the route (`my-router-admin-api`) should be listed with the address `172.30.52.51/32` and marked as selected. Then call the service:

```bash
curl http://172.30.52.51/healthz
```

The request travels over the encrypted mesh to the routing peer, which forwards it to the address you advertised. If the route is listed but the request times out, the router cannot reach that address — see the limitations above.

## What's Next?

- [MeshRouter API reference](../../api-reference/public-apis/mesh-router.md) - All router fields
- [MeshPolicy API reference](../../api-reference/public-apis/mesh-policy.md) - All policy fields
- [Create a Mesh](create-mesh.md) - Set up the Mesh and enrol devices
- [Create a Vault](create-vault.md) - Published over the Mesh automatically
