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
| Outbound access to the Stakater registry | charts and packages are pulled during installation |

### Storage

Check before installing, not after:

```bash
oc get storageclass
oc get pvc -A | grep -v Bound     # anything here is a warning sign
```

Several components are held back until storage is confirmed healthy. A degraded
storage backend does not produce loud errors — it produces **absent**
components, which reads as "the installation did nothing".

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
1. Set `dns.type: byo`. You keep ownership of DNS records. The wildcard and `api`
   records already exist on an installed cluster.

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
S=$(oc get secret -n openshift-gitops -l argocd.argoproj.io/secret-type=repository -o name | head -1 | cut -d/ -f2)
echo "copying from: $S"
oc create secret generic ghcr-helm-repo -n crossplane-system \
  --from-literal=enableOCI=true \
  --from-literal=name=ghcr-helm-repo \
  --from-literal=type=helm \
  --from-literal=url="$(oc get secret "$S" -n openshift-gitops -o jsonpath='{.data.url}' | base64 -d)" \
  --from-literal=username="$(oc get secret "$S" -n openshift-gitops -o jsonpath='{.data.username}' | base64 -d)" \
  --from-literal=password="$(oc get secret "$S" -n openshift-gitops -o jsonpath='{.data.password}' | base64 -d)"
oc label secret ghcr-helm-repo -n crossplane-system \
  app.kubernetes.io/component=ghcr-helm-repo app.kubernetes.io/name=crossplane-system
```

Check that `copying from:` names a single secret before you continue. If you
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

## What's Next?

- [Configuration](configuration.md) - Post-installation configuration
- [Choosing the Platform Secret Store Unseal Method](openbao-unseal.md)
