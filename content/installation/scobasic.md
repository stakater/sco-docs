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
| OpenShift 4.19+ | 4.20 and 4.21 are tested. On versions other than 4.21 and 4.22, run `ksp up` with `--skip-openshift-version-check` — see [OpenShift version](prerequisites.md#openshift-version) |
| `cluster-admin` | the installation creates namespaces, custom resources, operators and role bindings |
| A working RWO StorageClass | **you provide this** |
| Working `LoadBalancer` Services | **you provide this** |
| Wildcard DNS for `*.<apps-domain>` | platform routes are templated from it |
| Wildcard DNS for `*.public.<base>` | **you create this after installing**. `<base>` is `<apps-domain>` without its leading `apps.`. The sign-in pages and the SCO console are served there. See [Certificates and DNS](#certificates-and-dns) |
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
never created. The cluster stops with no obvious cause. Set this on the
`KubeStackConfig` claim. It applies to every hosted cluster created on this
cluster, not to one:

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
    variant: scobasic          # <- the variant (also the default when omitted)
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

    certificate:
      type: byo                # <- required on your own domain
      clusterIssuer: <cluster-issuer>

    dns:
      type: byo                # <- required on your own domain
```

Keep the `certificate` and `dns` blocks. Without them the platform tries to
issue certificates and create DNS records through Stakater's own DNS, which
cannot work on your domain. See [Certificates and DNS](#certificates-and-dns).

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

### Organization platform config

Every organization reads the EnvironmentConfig `organization-platform-config`.
It is required: without it no organization can be created. It also turns the
optional organization integrations on: an AWS Organizational Unit per
organization, Azure AD SSO for organization admins, outbound email (SMTP) for the
organization realms, and audit. For `scobasic` all of them are usually off:

```yaml
apiVersion: apiextensions.crossplane.io/v1beta1
kind: EnvironmentConfig
metadata:
  name: organization-platform-config
data:
  aws:
    enabled: false
  azuread:
    enabled: false
  smtp:
    enabled: false
  audit:
    enabled: false
```

The platform creates it with every integration off; you do not apply it. To
turn an integration on, put its settings in the override for the
`crossplane-environment-config` addon (add them to that object if you already
have one). Editing `organization-platform-config` directly does not last: the
platform renders it again from these values.

```yaml
apiVersion: apiextensions.crossplane.io/v1beta1
kind: EnvironmentConfig
metadata:
  name: <cluster-name>-crossplane-environment-config-addon-env-override
  labels:
    crossplane.io/composite: <cluster-name>
    kubestack.stakater.com/addon-name: crossplane-environment-config
    kubestack.stakater.com/config-kind: kubestack-plus-env
    kubestack.stakater.com/config-scope: addon
    kubestack.stakater.com/domain: <apps-domain>
    kubestack.stakater.com/name: <cluster-name>
data:
  SCOBASIC-OCP-VALUES: |
    organizationPlatformConfig:
      data:
        smtp:
          enabled: true
          # ...the settings this integration needs
```

With a platform version that does not create it yet, save the first file above
as `organization-platform-config.yaml` and apply it yourself
(`kubectl apply -f organization-platform-config.yaml`) before you create the first
organization.

### Where each value comes from

| Value | How to obtain it |
|---|---|
| `<cluster-name>` | Yours to choose. Short and stable — it names the identity realm and appears in generated resources. |
| `<apps-domain>` | `oc get ingresses.config cluster -o jsonpath='{.spec.domain}'` |
| `<pod-cidr>` | `oc get network.config cluster -o jsonpath='{.spec.clusterNetwork[*].cidr}'` |
| `<service-cidr>` | `oc get network.config cluster -o jsonpath='{.spec.serviceNetwork[*]}'` |
| `<cluster-issuer>` | The name of the cert-manager `ClusterIssuer` you create — see [Certificates and DNS](#certificates-and-dns). With a private CA and certificate files, leave `clusterIssuer` out — see [Private Certificate Authority](private-ca.md) |
| `<your-storage-class>` | `oc get storageclass` — an RWO class |
| `<range-start>` / `<range-end>` | A free address range you own |

!!! warning "The network values must match the cluster"
    Placeholder CIDRs that look plausible are not good enough. Incorrect values
    produce components that start but cannot reach each other, and nothing
    reports an error.

## Certificates and DNS

The platform does not bring a certificate authority or DNS provider for your
domain. It uses one certificate issuer that you provide.

1. Before installing, create a cert-manager `ClusterIssuer` that can issue
   certificates for `<apps-domain>`. Use either ACME with a DNS-01 solver for
   your DNS provider, or a CA issuer backed by your own certificate authority.
   The platform's router certificate is a wildcard, so ACME HTTP-01 does not
   work.
1. Set its name in the claim as `certificate.clusterIssuer`, with
   `certificate.type: byo`. The platform then requests and renews all of its
   certificates through that issuer.
1. Set `dns.type: byo`. You keep ownership of DNS records. The `*.apps` wildcard
   and `api` records already exist on an installed cluster, but you must add one
   more: `*.public.<base>` (if `<apps-domain>` is `apps.example.com`, that is
   `*.public.example.com`), pointing to the `LoadBalancer` address of the
   platform's second router, `router-public-<cluster-name>`. The router is created during the installation, so
   add the record once `ksp up` has run:

    ```bash
    oc get svc router-public-<cluster-name> -n openshift-ingress
    ```

    Until the record exists, the SCO console
    (`https://cloud-orchestrator.public.<base>`) and the sign-in pages do not
    load. `*.public` does not mean the router faces the internet; see
    [Private Certificate Authority](private-ca.md) for the full list of names
    and records.

If your issuer is backed by a private CA that clients do not trust by default,
also set `certificate.privateCA: true` and pass the root CA to `ksp up` with
`--trusted-ca`. Decide this before installing; it cannot be turned on later.

If your private CA hands out certificates but cannot act as an issuer, you can
install one certificate as files instead and leave out `clusterIssuer`. See
[Private Certificate Authority](private-ca.md), which also covers the names the
certificate needs and the DNS records you create.

!!! note "Default router and API server certificates"
    In this mode the platform also points the default router and the API server
    at the certificates it issues. To keep the certificates they serve today,
    contact Stakater before installing.

!!! tip "Already installed without these blocks?"
    If `oc get clusterissuer letsencrypt` reports a missing `aws-dns-creds` secret,
    the claim is still on the default mode. Create your `ClusterIssuer`, add the
    `certificate` and `dns` blocks to `kubestack-config-claim.yaml`, and re-apply
    it with `oc apply -f kubestack-config-claim.yaml`. You do not need to run
    `ksp up` again, and you do not need AWS credentials.

## Choosing how the secret store unseals

Decide this **before** the first installation — the choice is recorded permanently
the first time the secret store initialises.

See [Choosing the Platform Secret Store Unseal Method](openbao-unseal.md). For a
self-hosted or disconnected installation, the `static` method requires no cloud
account.

## Preparing the install secrets

`ksp up --extra-secrets extra-secrets.yaml` creates these Kubernetes Secrets
before it installs anything. For `scobasic` the file holds two secrets:

```yaml
secrets:
  - name: "ghcr-helm-repo"
    namespace: "crossplane-system"
    type: "Opaque"
    labels:
      app.kubernetes.io/component: "ghcr-helm-repo"
      app.kubernetes.io/name: "crossplane-system"
    data:
      enableOCI: "true"
      name: "ghcr-helm-repo"
      type: "helm"
      url: "<gitopsChartsUrl from registry-secret.yaml>"
      username: "<registry username>"
      password: "<registry token>"

  - name: "openbao-unseal-key"
    namespace: "stakater-openbao"
    type: "Opaque"
    data:
      current: "<32-byte key, base64>"
```

Write every value as plain text. The installer encodes it for Kubernetes, so do
not base64-encode the values yourself.

| Secret | Purpose | Values |
|---|---|---|
| `ghcr-helm-repo` | Registry credentials the platform uses to pull the charts it installs after the initial installation | The same username and token as in `registry-secret.yaml` (see [Prepare Registry Credentials](openshift.md#step-3-prepare-registry-credentials)). Set `url` to the same value as `gitopsChartsUrl` in that file. Keep `enableOCI`, `name` and `type` exactly as shown |
| `openbao-unseal-key` | The key the platform secret store unseals with | Needed only with the `static` unseal method. Generate it and back it up as described in [Choosing the Platform Secret Store Unseal Method](openbao-unseal.md) |

!!! warning "Keep this file"
    Store `extra-secrets.yaml` somewhere safe after the installation. If one of
    these secrets is lost later, you rebuild it from the same values. See
    [An install secret is missing](#an-install-secret-is-missing).

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

### Using an existing Argo CD

By default, `ksp up` installs the OpenShift GitOps operator and an Argo CD
instance in `openshift-gitops`, and the platform delivers every component
through that instance. If the cluster already runs OpenShift GitOps and you
want the platform to use your Argo CD instead, make three changes.

**1. Make your instance cluster-scoped.** The platform installs operators,
CRDs and other cluster-scoped resources through Argo CD, which a
namespace-scoped instance cannot manage. Add your instance's namespace to the
`ARGOCD_CLUSTER_CONFIG_NAMESPACES` environment variable on the OpenShift GitOps
operator's Subscription (see the OpenShift GitOps documentation on
cluster-scoped instances). Skip this if your instance is the default one in
`openshift-gitops`, which is cluster-scoped already.

**2. Point the KubeStackPlus claim at your instance**, and stop the platform
from installing its own:

```yaml
spec:
  parameters:
    variant: scobasic
    platform: ocp
    gitopsNamespace: <your-argocd-namespace>
    excludedAddons:
      - rh-openshift-gitops-operator
```

Excluding `rh-openshift-gitops-operator` also excludes the platform's Argo CD
instance, which depends on it. `gitopsNamespace` makes the platform create its
Argo CD Applications and AppProjects in your instance's namespace.

**3. Add two flags to the `ksp up` command above:**

```bash
  --brownfield \
  --argocd-namespace <your-argocd-namespace>
```

`--argocd-namespace` tells `ksp up` where to create the repository credential
(`ksp-up-registry-auth`) your Argo CD needs to pull the platform's charts.

Current limitations:

- `ksp up` recognises an existing Argo CD instance only in `openshift-gitops`.
  If your instance is in another namespace, contact us before installing.
- The multi-tenancy component's namespace webhook trusts only the platform's
  own Argo CD by default. If your Argo CD is refused when it creates
  namespaces, contact us.

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

## Service APIs

A `scobasic` cluster serves the platform's service APIs, but a few of them depend
on infrastructure this variant does not install, and one needs a recent package.
Check this table before promising a capability to a tenant.

| API | On `scobasic` | What it needs |
|---|---|---|
| `Organization`, `Project`, `User`, `Group` | Works | Nothing extra |
| `Mesh` | Works once the platform mesh is on | `meshPlatform.enabled: true` on the `KubeStackConfig` claim. It is off by default on `scobasic` |
| `OpenShiftCluster` | Works | OpenShift Virtualization and the hosted control plane operator (multicluster engine) on the cluster. `scobasic` installs neither |
| `VirtualMachine` | Works | OpenShift Virtualization on the cluster. `scobasic` does not install it |
| `Postgres` | Works | See below |
| `S3Bucket` | Does not provision | OpenShift Data Foundation object storage. `scobasic` does not install it |
| `Vault`, `MeshRouter` | Not yet validated | — |

### `Postgres`

Current `scobasic` installs ship a working package. Older ones (before
`sco-package-database` `0.0.6`, which carries `postgres-database` `0.0.13`) accept the
claim and then silently provision nothing: an empty namespace with no database, no
credentials and no connection details. On an older install, check what the cluster
runs before filing a fault:

```bash
oc get configuration.pkg.crossplane.io package-postgres-database \
  -o jsonpath='{.spec.package}'
```

Two things to expect even on a working package:

- **A claim with `meshAccess` set stays `Ready=False` until the project's mesh
  access map exists.** It reports `Unready resources: <name>-access-map`. A claim
  without `meshAccess` becomes `Ready` on its own.
- **The managing operator cannot report instance status when the project network is
  isolated.** The cluster's status then reads as a status-extraction error even
  though the database is serving. Treat backup, failover and switchover as unproven
  in that configuration until the status probe can reach the pods.

Confirm the database directly:

```bash
oc get clusters.postgresql.cnpg.io <name> -n <namespace>
oc get pods -n <namespace>
```

The claim publishes its connection details under `status.connection` once the
database is up. The credentials are stored in the organization's Vault, and
`status.credentials` says where.

### `S3Bucket`

A bucket is requested from OpenShift Data Foundation object storage (the
`ocs-storagecluster-ceph-rgw` class for private buckets, `openshift-storage.noobaa.io`
for public ones). `scobasic` does not install OpenShift Data Foundation, so on a
cluster without it those classes do not exist. The claim may report success while no
bucket was ever created. Either run OpenShift Data Foundation with object storage on
the cluster, or do not offer this API to tenants on a `scobasic` install.

## Troubleshooting

The [OpenShift installation troubleshooting](openshift.md#troubleshooting)
section applies here too. These failure modes are specific to `scobasic`:

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

### An install secret is missing

The platform keeps a copy of the registry credentials from your install secrets
in its secret store, and reads them back from there. If both copies are lost,
for example after the secret store has been reset, Crossplane's Helm provider
can no longer pull charts. The signs are:

```bash
oc get externalsecrets.external-secrets.io ghcr-helm-repo -n crossplane-system   # SecretSyncedError
oc get pushsecrets.external-secrets.io ghcr-helm-repo -n crossplane-system       # Errored
oc describe pushsecrets.external-secrets.io ghcr-helm-repo -n crossplane-system  # "could not get source secret"
```

Re-create the secret. If you no longer have `extra-secrets.yaml`, copy the
values from the Argo CD repository credential that `ksp up` created from the
same registry credentials. The values are not printed:

```bash
NS=openshift-gitops   # or your Argo CD namespace, see "Using an existing Argo CD"
S=$(oc get secret -n "$NS" -l argocd.argoproj.io/secret-type=repository -o name | head -1 | cut -d/ -f2)
echo "copying from: $S"
oc create secret generic ghcr-helm-repo -n crossplane-system \
  --from-literal=enableOCI=true \
  --from-literal=name=ghcr-helm-repo \
  --from-literal=type=helm \
  --from-literal=url="$(oc get secret "$S" -n "$NS" -o jsonpath='{.data.url}' | base64 -d)" \
  --from-literal=username="$(oc get secret "$S" -n "$NS" -o jsonpath='{.data.username}' | base64 -d)" \
  --from-literal=password="$(oc get secret "$S" -n "$NS" -o jsonpath='{.data.password}' | base64 -d)"
oc label secret ghcr-helm-repo -n crossplane-system \
  app.kubernetes.io/component=ghcr-helm-repo app.kubernetes.io/name=crossplane-system
```

Check that `copying from:` names a single secret before you continue. If you
use your own Argo CD, its namespace may hold other repository credentials; set
`S=ksp-up-registry-auth` instead, the credential `ksp up` created there. If you
still have the file, use its values instead. If `oc create` reports that the
secret already exists, check it with `oc get secret ghcr-helm-repo -n crossplane-system -o yaml`;
delete it only if its values are wrong, then run the commands again.

After many failed attempts, the copy into the secret store can wait a long time
before it retries. Trigger it, then trigger the read-back:

```bash
oc annotate pushsecrets.external-secrets.io ghcr-helm-repo -n crossplane-system force-sync=$(date +%s) --overwrite
sleep 20
oc get pushsecrets.external-secrets.io ghcr-helm-repo -n crossplane-system       # Synced
oc annotate externalsecrets.external-secrets.io ghcr-helm-repo -n crossplane-system force-sync=$(date +%s) --overwrite
sleep 10
oc get externalsecrets.external-secrets.io ghcr-helm-repo -n crossplane-system   # SecretSynced, READY True
```

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

### You joined the private network but nothing loads

The mesh client reports that it is connected, the peer list looks healthy, and
the routes for the cluster are listed against the peer that serves them — yet the
hosted cluster's console and API time out, both in the browser and from `curl`.

Confirm the shape of the failure first:

```bash
curl -sk -o /dev/null -m 20 \
  -w 'status %{http_code}  connect %{time_connect}s  total %{time_total}s\n' \
  https://<console-host>/
```

A connection that reaches the server and then stalls, rather than one that is
refused, points at packet size rather than at access. Look at the connection
while it is hanging:

```bash
ss -tin dst <address>
```

If the connection is established, `bytes_acked` is above zero, `rcv_ooopack` is
above zero and the receive queue is empty, then your request arrived and was
acknowledged but part of the reply never did. Small packets are getting through
and large ones are being discarded silently.

This happens when the size limit on the mesh interface is larger than what the
path your traffic actually takes can carry. The connection opens, because the
handshake is small. It then stops during the security negotiation, because the
server's certificate is the first large reply. Lower the limit and reconnect:

```bash
netbird up --mtu 1180
```

Then repeat the request. It should now succeed in about a second.

**Most networks are not affected.** The default suits ordinary connections. Paths
that add their own wrapping — a relay, a corporate virtual private network, a
tunnel between sites — leave less room, and the shortfall only shows up on large
replies. If your environment differs from the one the cluster was built on, check
this before investigating access rules or single sign-on.

The platform's mesh router already limits packet size on its side (to 1200 bytes by
default), which covers replies coming back through it. The setting above applies
to the machine you are connecting from, and is still needed when the path between
you and the mesh is the narrow part.

## What's Next?

- [Configuration](configuration.md) - Post-installation configuration
- [Choosing the Platform Secret Store Unseal Method](openbao-unseal.md)
