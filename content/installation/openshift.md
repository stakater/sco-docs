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

You need two claim files. Create them based on the examples below, adjusting values for your environment.

### KubeStackConfig Claim (`kubestack-config-claim.yaml`)

This claim is applied first and configures the platform environment:

```yaml
apiVersion: cloud.stakater.com/v1alpha1
kind: KubeStackConfig
metadata:
  name: <cluster-name>
  namespace: ksp-system
spec:
  parameters:
    name: <cluster-name>
    variant: scobasic
    platform: ocp
    location: <location>
    domain: apps.<cluster-name>.example.com
    registrySecretRef:
      name: <registry-secret-name>
      namespace: <registry-secret-namespace>
    namespaces:                        # optional
      platform: platform-system
      monitoring: monitoring
      logging: logging
    network:                           # optional
      podCIDR: <pod-cidr>
      serviceCIDR: <service-cidr>
      clusterDomain: cluster.local
```

**Required parameters:**

| Parameter | Description |
|-----------|-------------|
| `parameters.name` | Unique name for this cluster instance |
| `parameters.location` | Physical or logical location of the cluster |
| `parameters.domain` | Base domain for SCO ingress routes |

**Optional parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `parameters.variant` | `scosmart` | SCO deployment variant (`scobasic`, `scosmart`) |
| `parameters.platform` | `ocp` | Target platform |
| `parameters.registrySecretRef` | — | Reference to the pull secret for the OCI registry |
| `parameters.namespaces.platform` | `platform-system` | Namespace for platform components |
| `parameters.namespaces.monitoring` | `monitoring` | Namespace for monitoring stack |
| `parameters.namespaces.logging` | `logging` | Namespace for logging stack |
| `parameters.network.podCIDR` | — | CIDR range for pod networking |
| `parameters.network.serviceCIDR` | — | CIDR range for service networking |
| `parameters.network.clusterDomain` | `cluster.local` | Internal cluster DNS domain |

### KubeStackPlus Claim (`kubestack-plus-claim.yaml`)

This claim is applied second and deploys the SCO platform:

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
```

| Parameter | Value | Description |
|-----------|-------|-------------|
| `parameters.variant` | `scobasic` | SCO deployment variant |
| `parameters.platform` | `ocp` | Target platform (OpenShift) |
| `parameters.server` | `https://kubernetes.default.svc` | (Optional) ArgoCD Application destination server. Override for multi-cluster setups. |

#### Excluding Addons

If you need to exclude specific addons from the deployment, use the `excludedAddons` field:

```yaml
spec:
  parameters:
    variant: scobasic
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

If using a private OCI registry, create a registry secrets file (`registry-secret.yaml`):

```yaml
registry:
  url: "ghcr.io"
  gitopsChartsUrl: "ghcr.io/stakater"
  username: "<your-username>"
  password: "<your-token>"
```

## Step 4: Run Installation

Execute `ksp up` with both claim files:

```bash
# Interactive (prompts for confirmation)
ksp up -f kubestack-plus-claim.yaml -c kubestack-config-claim.yaml

# Non-interactive
ksp up -f kubestack-plus-claim.yaml -c kubestack-config-claim.yaml --no-prompt
```

If using a private registry:

```bash
ksp up -f kubestack-plus-claim.yaml \
       -c kubestack-config-claim.yaml \
       --registry-secret ./registry-secret.yaml \
       --no-prompt
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
