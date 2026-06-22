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

This guide targets **`variant: hosting`** — an OpenShift cluster that runs the Hypershift operator and hosts other clusters. You author two claim files and adjust every `<...>` placeholder for your environment.

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
| `parameters.variant` | ✅ | `hosting` for a hosting-cluster install. |
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
| `parameters.variant` | ✅ | `hosting` — must match the `KubeStackConfig` variant. |
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

!!! note
    Example claim files are available in the `examples/` directory of the KubeStack+ CLI repository.

## Step 3: Prepare Registry Credentials

SCO components are pulled from Stakater's private registry, so a registry-secret file is **required**. Use the username and token Stakater provided — request them from `sales@stakater.com` if you don't have them yet (see [Prerequisites](prerequisites.md#registry-access)).

Create `registry-secret.yaml`:

```yaml
registry:
  url: "ghcr.io"
  gitopsChartsUrl: "ghcr.io/stakater"
  username: "<your-username>"
  password: "<your-token>"     # use either password or token; token wins if both are set
```

`ksp up` uses this file to log in to the registry and to create the in-cluster pull secrets that Crossplane and the composition functions need. It is **not** referenced from the claim files — it is passed on the command line via `--registry-secret` (Step 4).

## Step 4: Run Installation

`ksp up` operates on your **current `oc`/`kubectl` context**, so confirm it points at the target cluster first (`oc whoami --show-server`). Then run it with both claim files and your registry secret — `-c` (KubeStackConfig) is applied first, then `-f` (KubeStackPlus):

```bash
ksp up \
  -c kubestack-config-claim.yaml \
  -f kubestack-plus-claim.yaml \
  --registry-secret ./registry-secret.yaml
```

By default `ksp up` asks you to confirm the target cluster before making changes. For non-interactive runs (e.g. CI/CD), add `--no-prompt`:

```bash
ksp up -c kubestack-config-claim.yaml -f kubestack-plus-claim.yaml \
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

# Check if the chart is accessible
helm pull oci://ghcr.io/stakater/saap-catalog/charts/crossplane-operator --version <version>
```

Ensure the token has read access to `ghcr.io/stakater/saap-catalog`. If using `--registry-secret`, verify the file format matches the expected structure (see [Step 3](#step-3-prepare-registry-credentials)).

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
- [Console Overview](../console/overview.md) - Access the SCO console
- [Service Provider Guide](../service-provider-guide/getting-started.md) - Start creating solutions
