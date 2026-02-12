# Kubernetes Installation

Install Stakater Cloud Orchestrator on Kubernetes using the `ksp up` CLI command.

## Overview

The `ksp up` command provides an automated installation process that bootstraps your Kubernetes cluster with all required SCO components. It handles both greenfield (new) installations and brownfield (existing) cluster scenarios.

**Tested Platform**: Red Hat OpenShift 4.14+ on bare metal (production-ready)
**Compatibility**: Any Kubernetes 1.27+ distribution

## Prerequisites

Before starting, ensure you have completed the [prerequisites](prerequisites.md) checklist, including:

- Kubernetes 1.27+ cluster (OpenShift 4.14+ recommended)
- `ksp` CLI tool installed
- `kubectl` authenticated to your cluster
- Configuration claim files prepared
- Registry credentials (if using private registries)

## Installation Steps

### Step 1: Authenticate to Kubernetes

```bash
# Configure kubectl with your cluster credentials
kubectl config use-context your-cluster

# Verify access
kubectl cluster-info
kubectl get nodes

# OpenShift users can use oc
oc login https://api.your-cluster.example.com:6443
```

### Step 2: Prepare Claim Files

Create or obtain your SCO configuration claim files:

`kubestack-config-claim.yaml` - Platform configuration:

```YAML
apiVersion: pkg.kubestack.com/v1
kind: KubeStackConfig
metadata:
  name: platform-config
  namespace: ksp-system
spec:
  parameters:
    # Configuration parameters for your platform
    platform:
      domain: cloud.example.com
      ingress:
        tlsSecretName: wildcard-cert
    keycloak:
      realm: master
      adminCredentials:
        secretRef: keycloak-admin
```

`kubestack-plus-claim.yaml` - SCO platform:

```YAML
apiVersion: pkg.kubestack.com/v1
kind: KubeStackPlus
metadata:
  name: sco-platform
  namespace: ksp-system
spec:
  parameters:
    # SCO configuration
    marketplace:
      enabled: true
      solutions:

        - virtualmachine
        - openshift-cluster
    kcp:
      enabled: true
      workspaceSharding: true
    mto:
      enabled: true
      distributedMode: true
```

!!! note
    Example claim files are provided in the `ksp` CLI repository under `examples/`.

### Step 3: Prepare Registry Secret (Optional)

If using private registries:

```bash
ksp up -f kubestack-plus-claim.yaml \
       -c kubestack-config-claim.yaml \
       --registry-secret ./registry-secret.yaml
```

### Step 4: Run Installation

Execute the `ksp up` command:

```bash
# Interactive installation (will prompt for confirmation)
ksp up -f kubestack-plus-claim.yaml -c kubestack-config-claim.yaml

# Non-interactive installation
ksp up -f kubestack-plus-claim.yaml -c kubestack-config-claim.yaml --no-prompt

# Development mode (install prerequisites only, no claims)
ksp up --dev-mode
```

### Step 5: Monitor Installation

The installation process will:

1. Check cluster capabilities
1. Install Crossplane and required providers
1. Install Crossplane functions (`kcl`, `auto-ready`, `extra-resources`)
1. Create the `ksp-system` namespace
1. Apply the kubestack-config-package claim
1. Apply the kubestack-plus-package claim
1. Wait for all components to be healthy

**Expected Output:**

```text
✓ Checking cluster capabilities...
✓ Installing Crossplane...
✓ Installing provider-kubernetes...
✓ Installing Crossplane functions...
✓ Creating ksp-system namespace...
✓ Applying kubestack-config claim...
✓ Applying kubestack-plus claim...
✓ Waiting for components to be ready...

Installation complete! 🎉

SCO is now installed on your cluster.
```

### Step 6: Verify Installation

```bash
# Check ksp-system namespace
kubectl get pods -n ksp-system

# Verify core components are running
kubectl get pods -n crossplane-system

# Check for installed XRDs (solution definitions)
kubectl get xrds

# Verify virtual API layer
kubectl get pods -n kcp-system

# Check MTO is deployed
kubectl get pods -n multi-tenant-operator

# Verify Keycloak
kubectl get pods -n keycloak
```

Expected XRDs:

```text
NAME                                                   ESTABLISHED   OFFERED
virtualmachines.compute.cloud.stakater.com            True          True
xopenshiftclusters.infrastructure.stakater.com        True          True
```

## Installation Scenarios

### Greenfield Installation

For a fresh OpenShift cluster with no SCO components:

```bash
ksp up -f kubestack-plus-claim.yaml -c kubestack-config-claim.yaml
```

The command will install everything from scratch.

### Brownfield Installation

For clusters with some components already installed:

**Valid Brownfield** - All capabilities present:

- The command continues from where it left off
- Determines next action based on existing state

**Partial Brownfield** - Some capabilities missing:

- Command reports the partial state
- Recommends cleanup or manual intervention

### Development Installation

For development and testing without applying claims:

```bash
ksp up --dev-mode --registry-secret ./registry-secret.yaml
```

Installs only the prerequisites (Crossplane, providers, functions).

## Troubleshooting Installation

### Check Capabilities

```bash
# Manually check what's installed
oc get crds | grep crossplane
oc get pods -n crossplane-system
oc get providers.pkg.crossplane.io
```

### View Installation Logs

```bash
# Crossplane logs
oc logs -n crossplane-system -l app=crossplane

# Check claim status
oc get kubestackconfig -n ksp-system
oc describe kubestackconfig platform-config -n ksp-system

oc get kubestackplus -n ksp-system
oc describe kubestackplus sco-platform -n ksp-system
```

### Common Issues

**Issue**: Crossplane installation fails

**Solution**: Check cluster has sufficient resources and storage provisioner is working:

```bash
oc get pvc -n crossplane-system
oc get sc  # storage classes
```

**Issue**: Provider installation timeout

**Solution**: Check image pull permissions and network connectivity:

```bash
oc get providers.pkg.crossplane.io
oc describe provider provider-kubernetes
```

**Issue**: Claim not progressing

**Solution**: Check Crossplane composition logs:

```bash
oc logs -n crossplane-system -l app.kubernetes.io/component=crossplane
```

## Post-Installation

After successful installation:

1. [Configure SCO](configuration.md) - Set up DNS, certificates, and admin access
1. [Verify Components](#verify-installation) - Ensure all services are healthy
1. [Create First Organization](../service-provider-guide/organizations/creating-organizations.md) - Set up cloud users
1. [Access Console](../console/overview.md) - Log in to the web interface

## Removing SCO

To remove SCO from your cluster (use with caution):

```bash
# Delete the claims
oc delete kubestackplus sco-platform -n ksp-system
oc delete kubestackconfig platform-config -n ksp-system

# Remove SCO components
oc delete namespace ksp-system
oc delete namespace kcp-system
oc delete namespace multi-tenant-operator

# Optionally remove Crossplane
oc delete namespace crossplane-system
```

!!! warning
    Uninstalling SCO will remove all projects, organizations, and provisioned resources. Ensure you have backups before proceeding.

## What's Next?

- [Configuration](configuration.md) - Configure SCO for your environment
- [Console Overview](../console/overview.md) - Access the SCO console
- [Service Provider Guide](../service-provider-guide/getting-started.md) - Start creating solutions
