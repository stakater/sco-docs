# `scobasic` Installation

Install Stakater Cloud Orchestrator onto a cluster you already run.

## When to use this variant

`scobasic` adds SCO to an **existing** OpenShift cluster. Unlike
[`hosting`](openshift.md), it does not bring up the underlying platform layer —
it expects your cluster to already provide storage and load balancing, and it
installs a smaller set of components on top.

Choose `scobasic` when the cluster is yours, already in use, and you want SCO
alongside what is there. Choose `hosting` when you are dedicating a cluster to
SCO and want it built from scratch.

!!! warning "This variant installs neither storage nor load balancing"
    The `hosting` variant deploys ODF and the platform networking layer for you.
    **`scobasic` does neither.** A working RWO StorageClass and working
    `LoadBalancer` Services must already exist before you begin. This is the
    single most common reason a `scobasic` installation fails.

## Prerequisites

In addition to the [general prerequisites](prerequisites.md):

| Requirement | Notes |
|---|---|
| OpenShift 4.18+ | 4.20 and 4.21 are the tested versions |
| `cluster-admin` | the installation creates namespaces, custom resources, operators and role bindings |
| A working RWO StorageClass | **you provide this** |
| Working `LoadBalancer` Services | **you provide this** |
| Wildcard DNS for `*.<apps-domain>` | platform routes are templated from it |
| Outbound access to the Stakater registry | charts and packages are pulled during installation |
| The single sign-on address reachable from inside the cluster | **only if you will create hosted clusters** — see below |

### Storage

Check before installing, not after:

```bash
oc get storageclass
oc get pvc -A | grep -v Bound     # anything here is a warning sign
```

Several components are held back until storage is confirmed healthy. A degraded
storage backend does not produce loud errors — it produces **absent**
components, which reads as "the installation did nothing".

### If you will create hosted clusters

A hosted cluster verifies single sign-on **from inside its own network**, not from
the cluster hosting it. So the address you publish for single sign-on has to be
reachable from the machines that make up the hosted cluster.

On most networks it already is, and there is nothing to do here. Check in advance
if any of these are true, because the failure is quiet and its error message
points somewhere unhelpful:

- the address resolves to a load balancer in front of the cluster that does not
    route traffic back into it
- the hosted cluster's machines sit on a different network from the address they
    are given
- traffic leaving the cluster addressed to the cluster's own published address is
    dropped rather than looped back

**To check it, and to find the address to use if it is not reachable**, look at
where single sign-on is actually served from inside the cluster:

```bash
# 1. find the route serving your single sign-on host name
oc get route -A | grep <sso-host-name>

# 2. find which nodes run the routers that serve it, and their addresses
oc get pods -n openshift-ingress -o wide
oc get nodes -o wide
```

The node addresses in step 2 are what the hosted cluster's machines can reach.
If they cannot reach the published address, create a DNS record that resolves
your single sign-on host name to **all** of those node addresses, visible to the
hosted cluster's machines. Where that record lives depends on what serves DNS for
them — a split view on an internal resolver and a private zone are both common.

Two things to get right:

- **Use every node address that runs a router, not just one.** If a router moves
    to another node and the record names only the node it used to be on, single
    sign-on breaks again with the same unhelpful message.
- **Do not change the published address itself.** It has to keep matching what
    the identity provider issues, or verification fails for a different reason.

Verify it before creating a hosted cluster, by resolving the name against the
resolver the hosted cluster's machines will use:

```bash
dig +short @<their-resolver> <sso-host-name>
```

If that returns the node addresses rather than the public one, you are done. If
you skip this and it turns out to matter, the symptom is described under
[Troubleshooting](#a-hosted-clusters-console-has-no-single-sign-on-button).

### If your storage is node-local

Storage backed by disks on individual nodes — rather than a shared array — works,
but it constrains two things you should know about before relying on them.

**Hosted cluster control planes must be single-replica.** A three-replica control
plane database cannot be scheduled when the storage is node-local and is not
present on every node. The volumes are never all bound, the platform waits for
all of them rather than for a majority, and the hosted cluster's API server is
never created. The cluster stops with no obvious cause. Set this on the claim:

```yaml
spec:
  parameters:
    openshiftCluster:
      internal:
        controllerAvailabilityPolicy: SingleReplica
```

Check your coverage before assuming you do not need it — storage present on two
of three nodes is enough to stall the cluster and not enough to be obvious:

```bash
oc get storageclass <name> -o jsonpath='{.provisioner}{"\n"}'
oc get pvc -A | grep -v Bound        # anything pending here is the symptom
```

**Virtual machines cannot move between nodes while running.** RWO volumes are
bound to one node, so a running machine using them cannot be migrated — the
request is refused because the volume is not shared. This is a property of the
storage rather than a setting you can change. If moving running machines matters,
use a storage class that supports shared access for those volumes.

### Load balancing

The platform needs `LoadBalancer` Services to be assignable. On a cloud
provider this is usually already true. **On bare metal it is not** — install and
configure MetalLB, with an address pool, before you begin:

```bash
oc get svc -A | grep -i pending          # should be empty before you start
oc get ipaddresspools.metallb.io -A      # if using MetalLB
```

### Address budget

A full installation needs roughly **seven** load balancer addresses. If the platform
mesh is disabled it needs about **three**.

If addresses are scarce, disable the mesh in the `KubeStackPlus` claim:

```yaml
spec:
  parameters:
    meshPlatform:
      enabled: false
```

The mesh provides connectivity to clusters that are not directly reachable. If
your cluster's API and applications are already reachable by the people and
systems that need them, you do not need it.

### Capacity

Measured on a three-node OpenShift 4.21 cluster, as requested resources:

| | CPU | Memory |
|---|---|---|
| OpenShift itself | 9 | 30 GB |
| Storage layer (ODF, `lean` profile) | 18 | 43 GB |
| SCO platform | 15 | 39 GB |
| **Total** | **~42** | **~111 GB** |

Practical sizing:

- **If you run ODF on the same cluster**, 3 × 16 vCPU / 64 GB is the floor and
    leaves very little headroom. 3 × 24 vCPU is comfortable. Set the ODF
    `resourceProfile` to `lean` — the default profile requests substantially
    more and will leave pods unscheduled on a three-node cluster.
- **If your storage is provided elsewhere**, budget roughly 24 vCPU / 68 GB for
    OpenShift plus SCO.
- **Size memory from observed usage, not from requests.** Actual consumption
    runs well above the requested figure.

## Preparing the claim files

`ksp up` applies three files. The structure matches the
[hosting installation](openshift.md#step-2-prepare-claim-files); the values
below are what differ for `scobasic`.

### KubeStackConfig claim

```yaml
apiVersion: cloud.stakater.com/v1alpha1
kind: KubeStackConfig
metadata:
  name: <cluster-name>
  namespace: ksp-system
spec:
  parameters:
    name: <cluster-name>
    variant: scobasic          # <- the variant
    platform: ocp
    domain: <apps-domain>

    namespaces:
      logging: logging
      monitoring: monitoring
      platform: platform-system

    network:
      clusterDomain: cluster.local
      podCIDR: <pod-cidr>
      serviceCIDR: <service-cidr>
```

### KubeStackPlus claim

```yaml
apiVersion: cloud.stakater.com/v1alpha1
kind: KubeStackPlus
metadata:
  name: <cluster-name>-ocp-scobasic
  namespace: ksp-system
spec:
  providerConfigRef:
    name: kubernetes-provider
  parameters:
    variant: scobasic
    platform: ocp
    excludedAddons: []
```

### Environment configuration

Passed with `--environment-config`. For `scobasic` this is where you tell the
platform which storage class to use and, if applicable, your load balancer
address range:

```yaml
name: cluster-defaults

clusterDefaults:
  baseDomain: "<apps-domain>"
  variant: "scobasic"
  platform: "ocp"

  storage:
    persistentStorageClassName: "<your-storage-class>"

  metallb:
    l2Advertisement:
      enabled: true
      addressRanges:
        - "<range-start>-<range-end>"
    bgp:
      enabled: false
```

### Where each value comes from

| Value | How to obtain it |
|---|---|
| `<cluster-name>` | Yours to choose. Short and stable — it names the identity realm and appears in generated resources. |
| `<apps-domain>` | `oc get ingresses.config cluster -o jsonpath='{.spec.domain}'` |
| `<pod-cidr>` | `oc get network.config cluster -o jsonpath='{.spec.clusterNetwork[*].cidr}'` |
| `<service-cidr>` | `oc get network.config cluster -o jsonpath='{.spec.serviceNetwork[*]}'` |
| `<your-storage-class>` | `oc get storageclass` — an RWO class |
| `<range-start>` / `<range-end>` | A free address range you own |

!!! warning "The network values must match the cluster"
    Placeholder CIDRs that look plausible are not good enough. Incorrect values
    produce components that start but cannot reach each other, and nothing
    reports an error.

## Choosing how the secret store unseals

Decide this **before** the first installation — the choice is recorded permanently
the first time the secret store initialises.

See [Choosing the Platform Secret Store Unseal Method](openbao-unseal.md). For a
self-hosted or disconnected installation, the `static` method requires no cloud
account.

## Installing

```bash
ksp prerequisites --variant scobasic

ksp up \
  -c   kubestack-config-claim.yaml \
  -f   kubestack-plus-claim.yaml \
  --environment-config env-config.yaml \
  --extra-secrets      extra-secrets.yaml \
  --registry-secret    registry-secret.yaml \
  --timeout 15m
```

Add `--brownfield` if the cluster already has Argo CD or Crossplane. Without it
the command stops rather than installing over an existing partial stack — which
is the common case for `scobasic`, since the variant exists for clusters that
are already in use.

## Verifying

```bash
ksp status
oc get kubestackconfig,kubestackplus -A
oc get co | grep -v "True.*False.*False"     # any output = a degraded cluster operator
```

Installation is staged — operators, then their instances, then configuration —
so allow several minutes before drawing conclusions.

| Check | Expected |
|---|---|
| `KubeStackConfig` / `KubeStackPlus` | both ready |
| Cluster operators | none degraded |
| Secret store | unsealed |
| Platform components | the large majority healthy |

### Components that need input before they can become healthy

Some components integrate with services **you** provide, and stay unhealthy
until you supply them. This is expected, and is not a failed installation.

| Component | Needs |
|---|---|
| Source control integration | A token for your source control provider |
| Uptime monitoring | Configuration for your monitoring service |
| Backup | Object storage credentials and a bucket |

If you do not intend to use one, exclude it rather than leaving it unhealthy —
a permanently unhealthy component is indistinguishable at a glance from a broken
one:

```yaml
spec:
  parameters:
    excludedAddons:
      - <component-name>
```

Start with `excludedAddons: []` and let the installation tell you what your
cluster cannot satisfy. Copying an exclusion list from elsewhere hides real
problems.

### Verify single sign-on explicitly

Single sign-on spans several components, and a partial result is easy to miss —
the components can look healthy while logging in does not work:

```bash
oc get co authentication
oc get oauth cluster -o jsonpath='{.spec.identityProviders[*].name}{"\n"}'
```

An empty result means OpenShift has no identity provider configured, whatever
else reports healthy. Confirm you can log in to the console before considering
the installation complete.

## Troubleshooting

The [OpenShift installation troubleshooting](openshift.md#troubleshooting)
section applies here too. Three failure modes are specific to `scobasic`:

### LoadBalancer Services stay pending

```bash
oc get svc -A | grep -i pending
```

`scobasic` does not install load balancing. On bare metal this means MetalLB is
missing, has no address pool, or the pool is exhausted. Check the pool has free
addresses — the platform needs about seven, or three with the mesh disabled.

### Components are absent rather than unhealthy

If parts of the platform are missing entirely rather than showing as unhealthy,
a dependency is being withheld. The usual cause is the secret store not having
unsealed: components that depend on it are never created, and their absence is
silent.

```bash
oc get pods -n stakater-openbao
```

See [the unseal guide](openbao-unseal.md) if it has not come up.

### A hosted cluster's console has no single sign-on button

The hosted cluster is healthy and you can still reach it with the administrator
credentials, but its console offers only the built-in username and password form.
Check the cluster's own view first:

```bash
oc get hostedcluster <name> -n hypershift-<name> \
  -o jsonpath='{range .status.conditions[?(@.type=="ValidIDPConfiguration")]}{.status} {.message}{"\n"}{end}'
```

If that reports `False` with a message about a TLS handshake, **the problem is
not TLS**. The platform verifies the identity provider from inside the hosted
cluster's own network, and that message is what a blocked or misdirected
connection looks like by the time it surfaces. Verification is deliberately
fail-closed: rather than configure a provider it could not reach, the platform
configures none at all. That is why the button is missing instead of the login
failing.

The usual cause is that the hosted cluster's machines cannot reach the identity
provider at its published address, while everything else about the network works.
Test it from inside the hosted cluster, not from your own machine, by starting a
short-lived pod there and making the request from it:

```bash
curl -s -o /dev/null -m 15 -w '%{http_code}\n' https://<issuer-host>/
```

A timeout there, while the same request succeeds from elsewhere, means the
machines are being sent to an address they cannot use — most often because the
published address resolves to something in front of the cluster that cannot route
back into it.

**Most networks are not affected.** If the machines can reach the published
address, there is nothing to configure.

Where they cannot, resolve the single sign-on host name — for the hosted
cluster's machines only — to the addresses of the nodes running the routers that
serve it. [If you will create hosted clusters](#if-you-will-create-hosted-clusters)
above gives the commands to find those addresses and what to check afterwards.
The platform does not configure this for you, because what serves DNS to those
machines is part of your environment rather than part of the cluster.

## What's Next?

- [Configuration](configuration.md) - Post-installation configuration
- [Choosing the Platform Secret Store Unseal Method](openbao-unseal.md)
