# Installation Overview

Learn how to install Stakater Cloud Orchestrator on your Kubernetes cluster.

## Installation Method

SCO is installed using the **`ksp up`** command from the KubeStack+ CLI. This command bootstraps your Kubernetes cluster with all required components and dependencies.

## Installation Flow

The `ksp up` command:

1. **Validates Prerequisites**: Checks for required cluster capabilities
2. **Installs Core Components**: Deploys composition framework and required operators
3. **Applies Configuration**: Installs the `kubestack-config-package` claim
4. **Deploys SCO Platform**: Installs the `kubestack-plus-package` claim
5. **Verifies Installation**: Ensures all components are healthy and ready

The two package claims handle the automated rollout of all SCO components including:

- Virtual API layer with multi-tenancy
- Multi-Tenant Operator for network isolation
- Keycloak for authentication
- VM management (KubeVirt on supported platforms)
- Hosted control plane support (HyperShift on OpenShift)
- Marketplace and console components

## Supported Platforms

**Production-Ready**: Red Hat OpenShift 4.14+ on bare metal (tested and supported)

**Architecture**: Kubernetes-agnostic design, compatible with standard Kubernetes distributions

**Minimum Requirements**:

- Kubernetes 1.27+ (OpenShift 4.14+ recommended)
- Sufficient cluster capacity (see prerequisites)
- Administrative access to the cluster
- Network connectivity for external services
- Storage provisioner configured

**Optional Enhancements** (on OpenShift):
- OpenShift Virtualization for VM workloads
- HyperShift for hosted cluster provisioning

## Cluster Classification

When you run `ksp up`, the command automatically classifies your cluster:

- **Greenfield**: No SCO components present → Full installation
- **Valid Brownfield**: All components present → Continuation logic
- **Partial Brownfield**: Some components present → Error with report

## What's Next?

- [Prerequisites](prerequisites.md) - Check installation prerequisites
- [OpenShift Installation](kubernetes.md) - Install SCO on OpenShift
- [Configuration](configuration.md) - Post-installation configuration
