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
    location: <location>
    domain: apps.<cluster-name>.example.com
```

| Parameter | Description |
|-----------|-------------|
| `parameters.name` | Unique name for this cluster instance |
| `parameters.location` | Physical or logical location of the cluster |
| `parameters.domain` | Base domain for SCO ingress routes |

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

!!! note
    Example claim files are available in the `examples/` directory of the KubeStack+ CLI repository.

## Step 3: Run Installation

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

## Step 4: Monitor Installation

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

## Step 5: Verify Installation

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
