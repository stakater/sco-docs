# Installation Overview

Learn how to install Stakater Cloud Orchestrator on your OpenShift cluster.

## Installation Method

SCO is installed using the **`ksp up`** command from the KubeStack+ CLI. Running `ksp up` locally, against the cluster your `oc`/`kubectl` context points at, bootstraps your OpenShift cluster with all required components.

!!! note "Get the CLI and credentials first"
    The `ksp` CLI and the registry credentials for SCO components are both provided by Stakater — request them from `sales@stakater.com`. Complete the [Prerequisites](prerequisites.md) before you begin.

!!! info "Which variant?"
    This guide installs the **`hosting`** variant — the full greenfield deployment that brings up the entire platform foundation (storage, GitOps, Hypershift, cluster management, …) and the SCO layer on a base OpenShift cluster.

    If you are adding SCO to a cluster you already run, you want **`scobasic`** instead — see [scobasic Installation](scobasic.md). It installs a smaller set and expects your cluster to already provide storage and load balancing.

The command takes two claim files plus your registry secret:

- **`-c`** — the `KubeStackConfig` claim, applied first to generate environment configuration
- **`-f`** — the `KubeStackPlus` claim, applied second to deploy the SCO platform
- **`--registry-secret`** — credentials for pulling SCO components from Stakater's private registry

```bash
ksp up -c kubestack-config-claim.yaml -f kubestack-plus-claim.yaml --registry-secret registry-secret.yaml
```

## Installation Flow

The `ksp up` command:

1. **Validates Prerequisites** — Checks for required cluster capabilities (Crossplane, providers, functions, Argo CD)
1. **Installs Core Components** — Deploys the composition framework and required operators
1. **Applies Config Claim** — Installs the `KubeStackConfig` claim to configure the environment
1. **Deploys SCO Platform** — Installs the `KubeStackPlus` claim to bring up the SCO platform
1. **Verifies Installation** — Ensures all components are healthy and ready

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
