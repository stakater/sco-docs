# OpenShift Installation

Install Stakater Cloud Orchestrator on OpenShift using the `ksp up` command.

## Prerequisites

Ensure you have completed the [prerequisites](prerequisites.md) checklist before starting.

## Step 1: Authenticate to OpenShift

Configure your local kubeconfig to point to the target cluster:

```bash
oc login https://api.your-cluster.example.com:6443

# Verify access
oc whoami
oc get nodes
```

## Step 2: Prepare Claim Files

This guide targets **`variant: hosting`** — the full greenfield deployment that installs the entire platform foundation plus the SCO layer on a base OpenShift cluster. You author two claim files and an environment configuration file, and adjust every `<...>` placeholder for your environment.

### KubeStackConfig Claim (`kubestack-config-claim.yaml`)

Applied first. Carries cluster identity, networking, reserved namespaces, and per-cluster knobs.

```yaml
apiVersion: cloud.stakater.com/v1alpha1
kind: KubeStackConfig
metadata:
  name: <cluster-slug>-config              # convention: <cluster-slug>-config
  labels:
    crossplane.io/composite: <cluster-slug>-config
spec:
  managementPolicies:
    - '*'
  parameters:
    # Cluster identity
    platform: ocp
    variant: hosting
    name: <cluster-slug>                   # short identifier, e.g. eu-1-ndskuue5
    domain: apps.<cluster-domain>          # wildcard apps domain, e.g. apps.eu-1.ndskuue5.example.com

    # Reserved namespaces (keep the defaults unless you have a reason to change them)
    namespaces:
      logging: logging
      monitoring: monitoring
      platform: platform-system

    # Network — mirror `oc get network cluster -o yaml`
    network:
      clusterDomain: cluster.local
      podCIDR: 10.128.0.0/14
      serviceCIDR: 172.30.0.0/16

    # Hosted-cluster public DNS / routing — environment-specific (see note below)
    openshiftCluster:
      public:
        baseUrl: "public.<cluster-domain>"
        dnsSplit:
          enabled: true
          zones:
            - "public.<cluster-domain>"
          upstreams:
            - "<upstream-dns-1>"
            - "<upstream-dns-2>"
        openbsdUnbound:
          enabled: true
          openbsdHosts:
            - "<router-host-1>"
            - "<router-host-2>"
          routerPodIPs:
            - "<router-pod-ip>"
        azuread:                           # omit this block if you do not use Azure AD
          pimEligibleMembers:
            - objectId: <azure-object-id>
              assignmentType: member
              justification: <justification>
  providerConfigRef:
    name: kubernetes-provider
```

| Field | Required | Description |
|-------|:--------:|-------------|
| `parameters.name` | ✅ | Cluster slug — short identifier; appears in resource names and labels. Use it consistently. |
| `parameters.variant` | ✅ | `hosting` for a hosting-cluster install. Set it explicitly: when omitted it defaults to `scobasic`. |
| `parameters.platform` | ✅ | `ocp` for OpenShift. |
| `parameters.domain` | ✅ | Wildcard apps domain — `apps.<cluster-name>.<domain>`. |
| `parameters.namespaces.{platform,monitoring,logging}` | — | Reserved namespace names (defaults: `platform-system` / `monitoring` / `logging`). |
| `parameters.network.{clusterDomain,podCIDR,serviceCIDR}` | — | Mirror the cluster's `Network` CR (`oc get network cluster -o yaml`). |
| `parameters.openshiftCluster.public.baseUrl` | — | DNS subdomain for hosted-cluster public access (the split-DNS source). |
| `parameters.openshiftCluster.public.dnsSplit` | — | Upstream DNS zones for hosted-cluster public resolution. |
| `parameters.openshiftCluster.public.openbsdUnbound` | — | Router hosts that proxy DNS for hosted-cluster public access. |
| `parameters.openshiftCluster.public.azuread.pimEligibleMembers` | — | Azure AD principals (object IDs) granted PIM-eligible access. Omit if not using Azure AD. |

!!! note
    The `openshiftCluster.public` block (split-DNS, OpenBSD-unbound, Azure AD) depends on your hosting cluster's networking and identity environment. Confirm the upstream DNS, router, and identity values with your platform team, and drop any sub-block that does not apply to your setup.

### KubeStackPlus Claim (`kubestack-plus-claim.yaml`)

Applied second — it triggers the platform composition. For `variant: hosting` this claim is **minimal**; almost all configuration flows through `KubeStackConfig`.

```yaml
apiVersion: cloud.stakater.com/v1alpha1
kind: KubeStackPlus
metadata:
  name: <cluster-slug>-package             # convention: <cluster-slug>-package
  labels:
    crossplane.io/composite: <cluster-slug>-package
spec:
  managementPolicies:
    - '*'
  parameters:
    platform: ocp
    variant: hosting
    server: 'https://kubernetes.default.svc'   # local hosting cluster API
  providerConfigRef:
    name: kubernetes-provider
```

| Field | Required | Description |
|-------|:--------:|-------------|
| `metadata.name` | ✅ | Claim name. Convention: `<cluster-slug>-package`. |
| `parameters.variant` | ✅ | `hosting` — must match the `KubeStackConfig` variant. There is no default: a claim without it is rejected at admission. |
| `parameters.platform` | ✅ | `ocp`. |
| `parameters.server` | — | ArgoCD Application destination API server. For `hosting`, the local cluster API (default `https://kubernetes.default.svc`). |
| `parameters.excludedAddons` | — | Optional list of addon names to exclude (see below). |
| `spec.providerConfigRef.name` | ✅ | `kubernetes-provider` — the CLI installs this provider if it is missing. |

#### Excluding Addons

If you need to exclude specific addons from the deployment, use the `excludedAddons` field:

```yaml
spec:
  parameters:
    variant: hosting
    platform: ocp
    excludedAddons:
      - kcp-operator
      - kcp-operator-config
      - kcp-core-workspaces
      - kcp-services
```

!!! note
    Excluding an addon also transitively excludes any addons that depend on it.

### Environment Configuration (`hosting-env-config.yaml`)

**Required.** Passed to `ksp up` with `--environment-config` (Step 4). It
becomes the cluster's `cluster-defaults` EnvironmentConfig: the base domain,
the identity provider URL, load balancing, storage and, if you use them, the
OpenBSD DNS routers. The platform reads where to find its components from
this configuration, so `ksp up` will not start the installation without it.

```yaml
name: cluster-defaults

clusterDefaults:
  # Core
  baseDomain: "apps.<cluster-domain>"     # same value as parameters.domain
  rhbkUrl: "rhbk.apps.<cluster-domain>"   # rhbk.<baseDomain>, no https://
  variant: "hosting"
  platform: "ocp"

  # Load balancer addresses — enable ONE of the two modes
  metallb:
    l2Advertisement:                      # no router peering needed
      enabled: false
      addressRanges:
        - "<range-start>-<range-end>"
    bgp:                                  # peering with your gateway router
      enabled: true
      myASN: <cluster-asn>                # e.g. 65002
      peerASN: <gateway-asn>              # e.g. 65001
      peerAddress: "<gateway-internal-ip>"
      peerPort: 179
      addressRanges:
        - "<public-cidr>"                 # the block routed to this cluster

  # Storage (ODF)
  storage:
    localStorageNodes: []                 # node names whose spare disks ODF uses
    odfStorageClassName: "ocs-storagecluster"
    persistentStorageClassName: "ocs-storagecluster-ceph-rbd"
    odfStorageClusterCount: 3
    odfStorageClusterReplicas: 1
    odfStorageSize: "1Ti"                 # per disk; match your disks
    odfPatchStorageClassAsDefault: true

# OpenBSD routers for hosted-cluster public DNS — top level, not under
# clusterDefaults. Leave this block out if you do not use them.
openbsdUnboundConfig:
  enabled: true
  openbsdHosts:
    - "<router-host-1>"
  routerPodIPs:
    - "<router-pod-ip>"
  sshCredentialsSecretRef:
    name: openbsd-ssh-credentials
    privateKeyKey: ssh-privatekey
    namespace: crossplane-system
  sshUser: crossplane
```

| Field | Required | Description |
|-------|:--------:|-------------|
| `name` | ✅ | Always `cluster-defaults`. |
| `clusterDefaults.baseDomain` | ✅ | Wildcard apps domain, without a leading `*.`. Must equal `parameters.domain` in the `KubeStackConfig` claim. |
| `clusterDefaults.rhbkUrl` | ✅ | Host name of the platform identity provider, without a scheme: `rhbk.<baseDomain>`. |
| `clusterDefaults.variant` / `platform` | ✅ | `hosting` and `ocp` — must match both claims. |
| `clusterDefaults.metallb` | ✅ | The IP addresses the cluster hands out to `LoadBalancer` Services, and how it announces them to your network. Enable exactly one mode: `l2Advertisement` or `bgp`. The addresses must be unused and reach this cluster. See [MetalLB](#metallb-clusterdefaultsmetallb). |
| `clusterDefaults.storage` | — | How the platform builds ODF from the nodes' spare disks. Every field has a default; in most installs you change only `odfStorageSize` and `odfStorageClusterCount`. See [Storage](#storage-clusterdefaultsstorage). |
| `openbsdUnboundConfig` | — | Only if OpenBSD routers serve DNS for hosted-cluster public access. Off by default; leave the block out if you do not use them. See [OpenBSD DNS routers](#openbsd-dns-routers-openbsdunboundconfig). |

!!! warning "Keep `baseDomain` and `rhbkUrl` in line with the claim"
    After installation the platform renders this configuration again from the
    `KubeStackConfig` claim on every sync. A `baseDomain` or `rhbkUrl` that
    differs from the claim is overwritten on the first sync. The `metallb`,
    `storage` and `openbsdUnboundConfig` values you set here are kept.

!!! tip
    `ksp prerequisites --variant hosting` lists the sections this variant
    needs. Add `--generate-files <dir>` to write a skeleton of this file.

#### MetalLB `clusterDefaults.metallb`

On bare metal nothing hands out addresses to `LoadBalancer` Services, so the
platform installs MetalLB and configures it from these values. The platform
cannot obtain the addresses or configure your network for you; arrange both
before you install.

Choose one of two modes:

- **Layer 2** (`l2Advertisement`) — one node answers for each address on the
  local network, and another node takes over if it fails. It needs no router
  configuration, but the addresses must come from the nodes' own network
  segment, and all traffic for one address enters through a single node.
- **BGP** (`bgp`) — every node peers with your gateway router and announces
  each address to it. Use it when the addresses are a separate block, such as
  public IPs routed to the cluster.

Before you install, have ready:

- A block of addresses that nothing else uses and that your network delivers
  to this cluster. Plan for roughly **seven** addresses: three for the storage
  object gateway and four for the platform mesh. The three storage addresses
  all serve port 443, so each needs its own address.
- For BGP: the router configured to accept a BGP session from every node's
  internal IP, the AS numbers for both sides, and the router's internal IP.

| Field | Required | Description |
|-------|:--------:|-------------|
| `clusterDefaults.metallb.l2Advertisement.enabled` | — | `true` to announce the addresses on the nodes' own network segment. Needs no router configuration. Default: `true`. |
| `clusterDefaults.metallb.l2Advertisement.addressRanges` | ✅ (L2) | List of ranges (`<start>-<end>`) or CIDRs. The addresses must be on the same network segment as the nodes. |
| `clusterDefaults.metallb.bgp.enabled` | — | `true` to announce the addresses to your gateway router over BGP. Every node peers with the router, and each address is announced on its own (`/32`). Default: `false`. |
| `clusterDefaults.metallb.bgp.myASN` | ✅ (BGP) | The cluster's own AS number, as configured on the router for this cluster, e.g. `65002`. |
| `clusterDefaults.metallb.bgp.peerASN` | ✅ (BGP) | The router's AS number, e.g. `65001`. |
| `clusterDefaults.metallb.bgp.peerAddress` | ✅ (BGP) | The router's **internal** IP, as the nodes reach it — not its public address. |
| `clusterDefaults.metallb.bgp.peerPort` | — | The router's BGP port. Default: `179`. |
| `clusterDefaults.metallb.bgp.addressRanges` | ✅ (BGP) | The block your network routes to this cluster, usually a CIDR such as `203.0.113.128/27`. |

!!! warning "Disable the MetalLB mode you do not use"
    `l2Advertisement` is on by default. With BGP, set
    `l2Advertisement.enabled: false` explicitly: leaving the block out keeps
    layer 2 switched on, with a placeholder range, next to BGP.

After installation, check that the address pool exists and that no Service is
still waiting for an address:

```bash
oc get ipaddresspools,l2advertisements,bgppeers -n metallb-operator
oc get svc -A | grep -i pending          # should be empty
```

#### Storage `clusterDefaults.storage`

The platform builds the cluster's storage with ODF from unused disks on the
worker nodes:

1. The Local Storage Operator finds every unused disk and partition of 1 GiB or
   more on the selected nodes, and offers each one as a volume.
1. ODF claims `odfStorageClusterCount` of those volumes, of at least
   `odfStorageSize` each, and builds a storage cluster from them.
1. ODF creates the storage classes the platform and your workloads use, among
   them `ocs-storagecluster-ceph-rbd` for block volumes.

The platform also turns on cluster-wide disk encryption in ODF, with the keys
kept in the cluster. There is no setting for it here.

Before you install, make sure that:

- At least three nodes have spare disks.
- Each spare disk is empty — no filesystem and no data you want to keep.
- No other disk is left unused on those nodes. The platform takes every unused
  disk and partition of 1 GiB or more, including ones you meant for something
  else.

ODF keeps three copies of all data, so usable capacity is about a third of the
raw capacity. For example, three nodes with two 2 TiB disks each:

```yaml
  storage:
    odfStorageClusterCount: 6     # 3 nodes × 2 disks
    odfStorageSize: "2Ti"         # 12 TiB raw, about 4 TiB usable
```

| Field | Required | Description |
|-------|:--------:|-------------|
| `clusterDefaults.storage.odfStorageSize` | — | Size ODF claims from each spare disk, e.g. `"1Ti"`. Set it to the size of your spare disks — the smallest one, if they differ. A disk smaller than this value is not used. Default: `1Ti`. |
| `clusterDefaults.storage.localStorageNodes` | — | Node names (as in `oc get nodes`) whose spare disks ODF may use. Leave empty to use every worker node. List the nodes when only some of them have suitable disks, or when the disks differ in size and you want ODF on uniform disks. Default: empty. |
| `clusterDefaults.storage.odfStorageClusterCount` | — | Number of disks ODF uses. Set it to the number of spare disks across the nodes in use; it is not derived from `localStorageNodes`. Default: `3`. |
| `clusterDefaults.storage.odfStorageClusterReplicas` | — | Disks per storage set. Keep `1`: ODF is set up for flexible scaling, which expects one. Default: `1`. |
| `clusterDefaults.storage.odfPatchStorageClassAsDefault` | — | `true` makes the ODF block storage class the cluster's default storage class. Set `false` to keep a default class you already have. Default: `true`. |
| `clusterDefaults.storage.persistentStorageClassName` | — | Storage class the platform's own components use for their volumes. Keep the default, which is the ODF block storage class. Default: `ocs-storagecluster-ceph-rbd`. |
| `clusterDefaults.storage.odfStorageClassName` | — | Name of the class for the spare disks, and the prefix of the ODF storage classes. Keep the default. Default: `ocs-storagecluster`. |

After installation, check that the disks were found and the storage cluster is
ready:

```bash
oc get localvolumeset -n openshift-local-storage
oc get pv | grep ocs-storagecluster       # one volume per spare disk
oc get storagecluster -n openshift-storage   # PHASE should be Ready
```

If `odfStorageClusterCount` is higher than the number of disks found, the extra
claims stay `Pending` and the storage cluster never becomes ready.

#### OpenBSD DNS routers `openbsdUnboundConfig`

Only for networks where OpenBSD routers run the DNS resolver (Unbound) that
hosted clusters use. A hosted cluster must reach its login endpoint through
the hosting cluster's internal router, not through its public address. So
each time a hosted cluster is created, the platform logs in to every listed
router over SSH, adds a DNS record that points the cluster's login endpoint at
`routerPodIPs`, and reloads Unbound.

The feature is off by default. Leave the block out if you do not use it.

Prepare each router before you install:

1. Create the user the platform logs in as (`crossplane` by default), and add
   the public half of an SSH key pair to its `authorized_keys`:

    ```bash
    ssh-keygen -t ed25519 -f crossplane-key -N "" -C crossplane
    ```

1. Let that user write to `/var/unbound/etc/conf.d`.
1. Allow that user to reload Unbound, and nothing else, in `/etc/doas.conf`:

    ```text
    permit nopass crossplane cmd /usr/sbin/unbound-control args reload
    ```

1. Install Python 3 (`pkg_add python3`). The platform configures the router
   with Ansible, which needs it.
1. Make Unbound read the directory. Add this line to the `server:` block of
   `/var/unbound/etc/unbound.conf`:

    ```text
    include: /var/unbound/etc/conf.d/*.conf
    ```

| Field | Required | Description |
|-------|:--------:|-------------|
| `openbsdUnboundConfig.enabled` | — | `true` to manage DNS records on the routers. Default: `false`. |
| `openbsdUnboundConfig.openbsdHosts` | ✅ | Address of every router to configure. List both members of a high-availability pair. Use the same hosts as `openshiftCluster.public.openbsdUnbound.openbsdHosts` in the `KubeStackConfig` claim. |
| `openbsdUnboundConfig.routerPodIPs` | ✅ | Internal IPs of the hosting cluster's ingress router, which the DNS records point to. Find them with `oc get pods -n openshift-ingress -o wide`. Use the same IPs as in the `KubeStackConfig` claim. |
| `openbsdUnboundConfig.sshUser` | — | User the platform logs in as. Default: `crossplane`. |
| `openbsdUnboundConfig.sshCredentialsSecretRef.name` | — | Secret that holds the SSH private key. Default: `openbsd-ssh-credentials`. |
| `openbsdUnboundConfig.sshCredentialsSecretRef.namespace` | — | Namespace of that secret. Default: `crossplane-system`. |
| `openbsdUnboundConfig.sshCredentialsSecretRef.privateKeyKey` | — | Key in the secret that holds the private key. Default: `ssh-privatekey`. |

Create the secret with the private key during installation with
`--extra-secrets`, in a file such as `extra-secrets.yaml`:

```yaml
secrets:
  - name: openbsd-ssh-credentials
    namespace: crossplane-system
    type: kubernetes.io/ssh-auth
    sshAuth:
      privateKey: |
        -----BEGIN OPENSSH PRIVATE KEY-----
        <contents of crossplane-key>
        -----END OPENSSH PRIVATE KEY-----
```

After a hosted cluster is created, its record appears on each router as
`/var/unbound/etc/conf.d/<hosted-cluster-name>.conf`.

## Step 3: Prepare Registry Credentials

SCO components are pulled from Stakater's customer distribution registry, so a registry-secret file is **required**. Use your GitHub username and the `read:packages` token you created for it (see [Prerequisites](prerequisites.md#registry-access)).

Create `registry-secret.yaml`:

```yaml
registry:
  url: "ghcr.io"
  gitopsChartsUrl: "ghcr.io/stakater"
  username: "<your-github-username>"
  password: "<your-read-packages-token>"     # use either password or token; token wins if both are set
  profile: distribution
```

!!! important "profile: distribution is required for customer installs"
    Your credentials open Stakater's **customer distribution registry**, which
    carries the released versions of every platform component. The
    `profile: distribution` line points the whole installation — charts,
    packages, and images — at that registry. Without it the installer
    assumes Stakater's internal environment and every pull will be denied.

`ksp up` uses this file to log in to the registry and to create the in-cluster pull secrets the platform needs. It is **not** referenced from the claim files — it is passed on the command line via `--registry-secret` (Step 4).

!!! warning "`gitopsChartsUrl` is the registry, not the chart path"
    It must be exactly `ghcr.io/stakater`. Do not extend it towards the charts — neither `ghcr.io/stakater/registry` nor `ghcr.io/stakater/registry/charts` will work.

`ksp up` turns `gitopsChartsUrl` into an Argo CD *repository* credential, and Argo CD matches those against the repository URL an Application declares — not against the path of the chart inside it. The platform's Applications declare `ghcr.io/stakater` and locate charts below it, so a credential registered for a longer path matches no Application and authenticates nothing.

The symptom is unhelpful: every platform Application fails to sync with a `401`, which reads as though your credentials lack access to the distribution registry. The credentials are fine — nothing is using them. See [Argo CD Applications fail with 401](#argo-cd-applications-fail-with-401).

## Step 4: Run Installation

`ksp up` operates on your **current `oc`/`kubectl` context**, so confirm it points at the target cluster first (`oc whoami --show-server`). Then run it with both claim files, the environment configuration and your registry secret — `-c` (KubeStackConfig) is applied first, then `-f` (KubeStackPlus):

```bash
ksp up \
  -c kubestack-config-claim.yaml \
  -f kubestack-plus-claim.yaml \
  --environment-config ./hosting-env-config.yaml \
  --registry-secret ./registry-secret.yaml
```

If you use `openbsdUnboundConfig`, also pass `--extra-secrets ./extra-secrets.yaml`.

By default `ksp up` asks you to confirm the target cluster before making changes. For non-interactive runs (e.g. CI/CD), add `--no-prompt`:

```bash
ksp up -c kubestack-config-claim.yaml -f kubestack-plus-claim.yaml \
       --environment-config ./hosting-env-config.yaml \
       --registry-secret ./registry-secret.yaml --no-prompt
```

To install prerequisites only without applying claims (useful for validating the cluster first):

```bash
ksp up --dev-mode
```

### Useful Flags

| Flag | Description |
|------|-------------|
| `--trace` | Start an interactive trace session after applying claims to monitor progress |
| `--dry-run ./output` | Template charts to a folder instead of installing (for review) |
| `--extra-secrets secrets.yaml` | Create additional Kubernetes secrets during installation |
| `--extra-charts charts.yaml` | Path to an extra charts definition file for additional Helm charts |
| `--no-prompt` | Skip confirmation prompts (for CI/CD pipelines) |
| `--no-detection` | Skip capability detection phase entirely (assumes greenfield) |
| `--timeout 10m` | Increase the per-chart readiness timeout (default: 5m) |
| `--dev-mode` | Install prerequisites only without applying claims |
| `--kubecontext <name>` | Override the current kube context for all operations |
| `--argocd-namespace <ns>` | ArgoCD namespace for repository secret (required in brownfield when ArgoCD is pre-existing) |
| `--force` | Force installation even if KubeStackConfig claim already exists |

!!! warning "Air-gapped or no-cloud installs: decide the unseal method now"
    The platform's secret store unseals via AWS KMS by default, which requires cloud egress. If this cluster cannot reach a cloud KMS, you must select the static unseal method **on this first install** — it is fixed at initialisation and cannot be changed afterwards by editing configuration. See [Secret Store Unseal Method](openbao-unseal.md).

## Step 5: Monitor Installation

The command outputs progress as it runs:

```text
✓ Checking cluster capabilities...
✓ Installing Crossplane...
✓ Installing provider-kubernetes...
✓ Installing Crossplane functions...
✓ Creating ksp-system namespace...
✓ Applying kubestack-config claim...
✓ Applying kubestack-plus claim...
✓ Waiting for components to be ready...

Installation complete!
```

## Step 6: Verify Installation

Once the command completes, verify the platform is healthy:

```bash
# Core components
oc get pods -n ksp-system
oc get pods -n crossplane-system

# Confirm claims are ready
oc get kubestackconfig -n ksp-system
oc get kubestackplus -n ksp-system

# Check installed solution APIs are available
oc get xrds
```

## Brownfield Clusters

If your cluster already has some components installed, `ksp up` handles continuation automatically:

| ksp-system | KubeStackConfig | KubeStackPlus | Action taken |
|------------|-----------------|---------------|--------------|
| Not installed | — | — | Install ksp-system, then apply both claims |
| Installed | Not present | Not present | Apply both claims |
| Installed | Present | Not present | Apply `KubeStackPlus` only |
| Installed | Present | Present | Already complete — no action |

If the cluster is in a partial state (some prerequisites missing), the command will report what is missing and exit without making changes.

## Troubleshooting

### Check claim status

```bash
oc describe kubestackconfig <name> -n ksp-system
oc describe kubestackplus <name> -n ksp-system
```

### Check Crossplane logs

```bash
oc logs -n crossplane-system -l app=crossplane
oc logs -n crossplane-system -l app.kubernetes.io/component=crossplane
```

### Every component is reported as missing

On a cluster that already has components installed, `ksp up` reports all of
them as missing, as if the cluster were new. `ksp` uses Helm to find out what
is installed; when Helm fails, nothing is found. Check that Helm is 3.18 or
newer:

```bash
helm version --short
```

### Provider installation timeout

Check that the cluster can pull images from the required registries:

```bash
oc get providers.pkg.crossplane.io
oc describe provider provider-kubernetes
```

### Storage issues

```bash
oc get pvc -n crossplane-system
oc get sc
```

### Registry authentication failures

If Helm charts fail to pull from the OCI registry:

```bash
# Verify credentials locally
helm registry login ghcr.io -u <username> -p <token>

# Check if a chart is accessible
helm pull oci://ghcr.io/stakater/registry/charts/crossplane-operator --version <version>
```

If that pull succeeds, your credentials are working and the problem is in how they were registered in the cluster — not in your access. If using `--registry-secret`, verify the file format matches the expected structure (see [Step 3](#step-3-prepare-registry-credentials)).

### Argo CD Applications fail with 401

Many or all platform Applications fail to sync with a `401` from `ghcr.io`, while `helm pull` of the same chart succeeds from your workstation.

This is almost always the Argo CD repository credential being registered for the wrong URL. Argo CD matches repository credentials against the repository URL an Application declares, not the path of the chart inside it — so the credential has to be registered for `ghcr.io/stakater` even though the charts live further down under `/registry/charts/`. A credential registered for the chart path matches nothing, and every pull is then anonymous.

Compare the two:

```bash
# What the Applications ask for
oc get application -n openshift-gitops -o jsonpath='{.items[*].spec.source.repoURL}{"\n"}' | tr ' ' '\n' | sort -u

# What the credential covers
oc get secret -n openshift-gitops -l argocd.argoproj.io/secret-type=repository \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.data.url}{"\n"}{end}' \
  | while read -r name url; do echo "$name $(echo "$url" | base64 -d)"; done
```

The URLs must match exactly. Correct the secret's `url` if they do not — then restart the repository server. It is named after your Argo CD instance, so find it rather than assume the name:

```bash
repo_server=$(oc get deployment -n openshift-gitops -o name | grep repo-server)
echo "restarting: $repo_server"
oc rollout restart -n openshift-gitops $repo_server
```

!!! important "The restart is required, not optional"
    Argo CD's repository server caches registry credentials, so it keeps using the old ones after you fix the secret. Without the restart the `401`s continue unchanged and the fix looks like it did not work.

### Helm chart readiness timeout

If a chart times out during installation:

```bash
# Check Helm release status
helm list -n ksp-system
helm status <release-name> -n ksp-system

# Check pod status for the failing component
oc get pods -n <chart-namespace> -o wide
oc describe pod <pod-name> -n <chart-namespace>
```

Common causes include slow image pulls (especially on first install), insufficient node resources, or pending PVCs. Increase the timeout with `--timeout 10m` and retry.

### Brownfield recovery

If `ksp up` reports an invalid cluster state (e.g., KubeStackPlus exists without KubeStackConfig):

```bash
# Check what's currently installed
oc get kubestackconfig -n ksp-system
oc get kubestackplus -n ksp-system
helm list -n ksp-system

# If you need to start fresh, remove existing claims first
oc delete kubestackplus <name> -n ksp-system
oc delete kubestackconfig <name> -n ksp-system
```

Then re-run `ksp up`. Use `--force` to override an existing KubeStackConfig claim if needed.

### DNS and TLS verification

If ingress routes are not accessible after installation:

```bash
# Verify wildcard DNS resolves
dig *.apps.<cluster-name>.example.com

# Check ingress controller status
oc get ingresscontroller -n openshift-ingress-operator

# Check TLS certificate
oc get secret -n openshift-ingress
```

Wildcard DNS and TLS certificates must be configured before running `ksp up`, as several components create ingress routes during deployment.

## Uninstalling SCO

!!! warning
    Uninstalling SCO removes all organisations, projects, and provisioned resources. Ensure you have backups before proceeding.

```bash
oc delete kubestackplus <name> -n ksp-system
oc delete kubestackconfig <name> -n ksp-system
oc delete namespace ksp-system
```

## What's Next?

- [Configuration](configuration.md) - Configure SCO for your environment
- [Secret Store Unseal Method](openbao-unseal.md) - Choose how the platform secret store unseals
- [Console Overview](../console/overview.md) - Access the SCO console
- [Service Provider Guide](../service-provider-guide/getting-started.md) - Start creating solutions
