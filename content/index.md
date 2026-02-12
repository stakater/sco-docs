---
head:
  - - meta
    - name: keywords
      content: cloud orchestrator, cloud management portal
---

# Welcome to Stakater Cloud Orchestrator Documentation

Welcome to the public documentation for **Stakater Cloud Orchestrator (SCO)**.

## What is SCO?

Stakater Cloud Orchestrator is a Kubernetes-native orchestration platform that enables **Managed Service Providers**, **Enterprises**, and **Cloud Providers** to deliver "anything-as-a-service" to their customers. Built on standard Kubernetes APIs and CRDs, SCO provides complete infrastructure and platform services through a unified self-service portal.

**Primary Platform**: Red Hat OpenShift on bare metal (production-ready and tested)
**Compatibility**: Kubernetes-agnostic design, supports any Kubernetes distribution

## Key Capabilities

### Kubernetes-Native API Layer

SCO provides a unified Kubernetes-native API surface with built-in multi-tenancy that abstracts physical clusters. Cloud users interact with a consistent API regardless of the underlying infrastructure.

- Standard Kubernetes API compatibility
- Isolated virtual workspaces per project
- Multi-cluster orchestration capabilities
- No direct cluster access required
- True API-level multi-tenancy

### Marketplace

Built-in marketplace for publishing and consuming service offerings using Kubernetes-native CRDs.

- **Service Providers** create solutions using standard composition tools (Crossplane, KRO, custom operators)
- **Cloud Users** browse and provision services through self-service
- Solutions appear as Kubernetes custom resources
- Flagship offerings: **Virtual Machines** and **OpenShift-on-OpenShift** (hosted clusters)
- Extensible with custom solutions for databases, storage, and more

### Multi-Access Methods

Cloud users can interact with SCO using their preferred tools:

- **kubectl**: Standard Kubernetes CLI with kubeconfig
- **Terraform**: Using the Kubernetes provider
- **GitOps**: ArgoCD, Flux, or other GitOps tools
- **Console UI**: Web interface for `clickops`

### Complete Isolation

SCO provides strong isolation at multiple levels:

- **Organizations**: Dedicated Keycloak realm per organization
- **Projects**: Combination of KCP workspace (virtual API) + MTO tenant (actual resources)
- **Network Isolation**: Complete network separation between projects
- **No Host Cluster Access**: Users never interact directly with host clusters

## Who is SCO For?

### Service Providers

Platform engineers and administrators who create and manage service offerings.

**Get Started**: [Service Provider Guide](service-provider-guide/getting-started.md)

Key Tasks:

- Create solutions using Crossplane compositions
- Publish solutions to the marketplace
- Create organizations for customers
- Manage the platform and infrastructure

### Cloud Users

Developers and teams who consume services from the marketplace.

**Get Started**: [Cloud User Guide](cloud-user-guide/getting-started.md)

Key Tasks:

- Create projects for applications
- Browse and provision solutions
- Deploy applications
- Manage resources via kubectl, Terraform, or GitOps

## How It Works

1. **SCO is installed** on your Kubernetes cluster using the `ksp up` CLI command (tested on OpenShift 4.14+)
1. **Service providers** create solutions (e.g., VirtualMachine-as-a-Service, OpenShift-as-a-Service) using composition tools
1. Solutions are published to the **marketplace** as Kubernetes custom resources
1. **Organizations** are created with dedicated Keycloak realms for authentication isolation
1. Cloud users create **projects** (isolated workspaces with dedicated tenants) within their organization
1. Users provision **solution instances** from the marketplace into their projects using standard Kubernetes APIs
1. All services run in isolated environments with network and resource separation

## Core Technologies

SCO leverages proven, cloud-native technologies:

- **Kubernetes**: Foundation for all orchestration (tested on OpenShift 4.14+)
- **Kubernetes CRDs**: Native extension mechanism for solutions and services
- **Virtual Machine Management**: KubeVirt-based (OpenShift Virtualization on OpenShift)
- **Hosted Control Planes**: hypershift for OpenShift-on-OpenShift
- **[Multi-Tenant Operator (MTO)](https://docs.stakater.com/mto/)**: Network and resource isolation
- **[Keycloak](https://www.keycloak.org/)**: Authentication and authorization with realm isolation
- **External Secrets Operator**: Centralized secrets management
- **Composition Tools**: Supports Crossplane, KRO, and custom operators for solution definitions

## Quick Links

### For Service Providers

- [Getting Started](service-provider-guide/getting-started.md) - Create your first solution
- [Solution Overview](service-provider-guide/solutions/solution-overview.md) - Learn about solutions
- [Creating Organizations](service-provider-guide/organizations/creating-organizations.md) - Set up organizations
- [Publishing Solutions](service-provider-guide/marketplace/publishing-solutions.md) - Publish to marketplace

### For Cloud Users

- [Getting Started](cloud-user-guide/getting-started.md) - Provision your first service
- [Creating Projects](cloud-user-guide/projects/creating-projects.md) - Set up your workspace
- [Browsing Marketplace](cloud-user-guide/solutions/browsing-marketplace.md) - Find services
- [Setup kubectl](cloud-user-guide/kubectl-access/setup-kubectl.md) - Configure CLI access

### Learn More

- [Overview](about/overview.md) - Deep dive into SCO
- [Key Features](about/key-features.md) - Explore capabilities
- [Architecture](architecture/architecture.md) - Understand the architecture
- [Core Concepts](architecture/concepts.md) - Learn key concepts
- [Installation](installation/overview.md) - Install SCO

## Support and Community

Need help or want to contribute?

- **Documentation**: [docs.stakater.com/stakater-cloud-orchestrator](https://docs.stakater.com/stakater-cloud-orchestrator)
- **Website**: [Stakater.com](https://stakater.com)
- **Slack**: Join our community (link coming soon)

## What's Next?

Choose your path:

**I want to provide services** → [Service Provider Guide](service-provider-guide/getting-started.md)

**I want to consume services** → [Cloud User Guide](cloud-user-guide/getting-started.md)

**I want to understand SCO** → [Overview](about/overview.md) | [Architecture](architecture/architecture.md)
