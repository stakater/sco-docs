# scobasic Installation

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
    single most common reason a `scobasic` install fails.

## Prerequisites

In addition to the [general prerequisites](prerequisites.md):

| Requirement | Notes |
|---|---|
| OpenShift 4.18+ | 4.20 and 4.21 are the tested versions |
| `cluster-admin` | the install creates namespaces, custom resources, operators and role bindings |
| A working RWO StorageClass | **you provide this** |
| Working `LoadBalancer` Services | **you provide this** |
| Wildcard DNS for `*.<apps-domain>` | platform routes are templated from it |
| Outbound access to the Stakater registry | charts and packages are pulled during installation |

### Storage

Check before installing, not after:

```bash
oc get storageclass
oc get pvc -A | grep -v Bound     # anything here is a warning sign
```

Several components are held back until storage is confirmed healthy. A degraded
storage backend does not produce loud errors — it produces **absent**
components, which reads as "the install did nothing".

### Load balancing

The platform needs `LoadBalancer` Services to be assignable. On a cloud
provider this is usually already true. **On bare metal it is not** — install and
configure MetalLB, with an address pool, before you begin:

```bash
oc get svc -A | grep -i pending          # should be empty before you start
oc get ipaddresspools.metallb.io -A      # if using MetalLB
```

### Address budget

A full install wants roughly **seven** load balancer addresses. If the platform
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
    leaves very little headroom. 3 × 24 vCPU is comfortable. Set ODF's
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

Decide this **before** the first install — the choice is recorded permanently
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
section applies here too. Two failure modes are specific to `scobasic`:

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

## What's Next?

- [Configuration](configuration.md) - Post-installation configuration
- [Choosing the Platform Secret Store Unseal Method](openbao-unseal.md)
