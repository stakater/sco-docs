# How to Connect to an OpenShift Cluster

Learn how to reach a provisioned OpenShift cluster: join your organisation's mesh, open the cluster console, and sign in with your organisation identity.

Sam, a senior platform engineer at ACME Corp, has just provisioned a private cluster for a product team with [an OpenShiftCluster claim](provision-openshift-cluster.md). Before handing it over, Sam needs to confirm the team can reach the console and the API from their laptops.

## Prerequisites

- An [OpenShift cluster](provision-openshift-cluster.md) whose claim reports `READY=True`
- The [NetBird client](https://docs.netbird.io/how-to/installation) installed on your device
- Membership of a group listed under the cluster's `access.groups`, so you have a role once you are signed in
- For a **private** cluster, membership of the organisation group `<cluster>-mesh-access`, which your organisation administrator grants

## How Access Works

Reaching a cluster takes two independent grants, and the two failure modes look nothing alike:

| Grant | What it gives | Symptom when missing |
|-------|---------------|----------------------|
| Mesh membership (`<cluster>-mesh-access`) | A network path to the cluster's console, API and OAuth endpoints | Pages time out and nothing ever loads |
| A role via `access.groups` on the claim | Permission to see or do anything once signed in | You sign in successfully and land on an empty console that invites you to create a project |

A cluster with `networking.mode: public` needs only the second grant. A private cluster needs both, and the rest of this guide assumes a private cluster.

!!! note
    There is no local `kubeadmin` login on a cluster provisioned by the platform. The console sends you straight to your organisation's sign-in page, so a Keycloak identity in your organisation is the only way in.

## Step 1: Read the Cluster's Addresses

Open the cluster in the console. Clusters are under **Containers** in the sidebar:

![The OpenShift cluster list in the console]({{ screenshot: cluster-list }})

The detail page shows the phase, the **Console URL** and the **API endpoint** once the cluster is ready:

![A cluster detail page showing the console URL and API endpoint]({{ screenshot: cluster-detail }})

The same values are on the claim status:

```bash
kubectl get openshiftcluster my-cluster -o jsonpath="{.status.consoleUrl}"
kubectl get openshiftcluster my-cluster -o jsonpath="{.status.apiEndpoint}"
```

## Step 2: Join Your Organisation's Mesh

Every organisation has a default Mesh. Open it under **Networking** in the sidebar. Its detail page shows the **Management URL** you enrol against:

![The organisation's default Mesh detail page, showing the management URL]({{ screenshot: mesh-detail }})

Enrol your device:

```bash
netbird up --management-url=<management URL from the Mesh detail page>
```

A browser window opens for single sign-on. Leave the command running until the browser flow completes: the client owns the sign-in callback, and interrupting it makes a successful login look like a failure.

Confirm the client is connected:

```bash
netbird status
```

`Management` and `Signal` should both read `Connected`.

!!! tip
    Mesh group membership takes effect at sign-in. If your administrator added you to `<cluster>-mesh-access` after you enrolled, run `netbird down` and then `netbird up` again so your new membership is picked up.

See [Create a Mesh](create-mesh.md) for the full enrolment walkthrough and [One Identity Across Your Organisation](../../cloud-user-guide/authentication/organisation-identity.md) for multi-account caveats.

## Step 3: Open the Cluster Console

Open the **Console URL** from Step 1 in your browser. You are redirected to your organisation's sign-in page:

![The hosted cluster console sign-in page, redirected to the organisation identity provider]({{ screenshot: hosted-cluster-console-login }})

Sign in with your organisation account. The console opens on the projects you have a role in.

!!! note
    If the console loads but shows no projects and offers to create one, your network path works but you have no role on the cluster. Ask whoever owns the claim to add your group under `access.groups`.

## Step 4: Connect with the CLI

Use the API endpoint from Step 1. The hostname, not the IP, must be used so TLS validates:

```bash
oc login https://api.<cluster>.<base-domain>:6443
```

The command opens the same single sign-on flow as the console. Verify:

```bash
oc whoami
oc get projects
```

## Troubleshooting

| Symptom | Likely cause | What to do |
|---------|--------------|------------|
| Console or API times out | Not enrolled in the mesh, or not in `<cluster>-mesh-access` | Check `netbird status`; ask your administrator for the mesh group; re-run `netbird up` |
| Hostname does not resolve, or resolves to nothing | Your local resolver drops private-address answers | Point resolution for the cluster's domain at a public resolver (for example a per-domain resolver entry to `8.8.8.8`) |
| Pages hang part-way through loading | MTU too large for the tunnel | `netbird up --mtu 1200` |
| `netbird up` ignores a new management URL | A stale profile survives `netbird down` | Stop the client, move `/var/lib/netbird/default.json` aside, start it and enrol again |
| Signed in, console is empty | No role via `access.groups` | Add your group to the claim |

## What's Next?

- [Provision an OpenShift Cluster](provision-openshift-cluster.md) - Create another cluster or change its access groups
- [Create a Mesh](create-mesh.md) - Enrol more devices and manage mesh groups
- [Expose an Internal Service via the Mesh](expose-service-via-mesh.md) - Publish services running on the cluster to mesh peers
