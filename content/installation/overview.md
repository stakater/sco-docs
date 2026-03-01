# Installation Overview

Learn how to install Stakater Cloud Orchestrator on your OpenShift cluster.

## Installation Method

SCO is installed using the **`ksp up`** command from the KubeStack+ CLI. Running `ksp up` locally with your kubeconfig configured bootstraps your OpenShift cluster with all required components.

The command takes two claim files:

- **`-c`** — the `KubeStackConfig` claim, applied first to generate environment configuration
- **`-f`** — the `KubeStackPlus` claim, applied second to deploy the SCO platform

```bash
ksp up -f kubestack-plus-claim.yaml -c kubestack-config-claim.yaml
```

## Installation Flow

The `ksp up` command:

1. **Validates Prerequisites** — Checks for required cluster capabilities (Crossplane, providers, functions, Argo CD)
2. **Installs Core Components** — Deploys the composition framework and required operators
3. **Applies Config Claim** — Installs the `KubeStackConfig` claim to configure the environment
4. **Deploys SCO Platform** — Installs the `KubeStackPlus` claim to bring up the SCO platform
5. **Verifies Installation** — Ensures all components are healthy and ready

## Cluster Classification

When you run `ksp up`, the command classifies your cluster and determines the appropriate action:

| Classification | Description | Behaviour |
|----------------|-------------|-----------|
| **Greenfield** | No SCO components present | Full installation from scratch |
| **Valid Brownfield** | All components present | Continues from the current state |
| **Partial Brownfield** | Some components present | Blocked — reports what is missing |

## Supported Platform

SCO is installed and supported on **Red Hat OpenShift 4.14+** on bare metal.

## What's Next?

- [Prerequisites](prerequisites.md) - Check installation requirements
- [OpenShift Installation](openshift.md) - Step-by-step installation guide
- [Configuration](configuration.md) - Post-installation configuration
