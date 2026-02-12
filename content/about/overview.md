# Overview

Stakater Cloud Orchestrator (SCO) is a Kubernetes-native platform that enables MSPs, Enterprises, and Cloud Providers to deliver "anything-as-a-service" to their customers.

## What is SCO?

SCO provides a comprehensive Kubernetes-native orchestration layer built on industry-standard cloud-native technologies. While primarily tested and optimized for **Red Hat OpenShift on bare metal**, SCO's architecture is designed to run on any Kubernetes distribution. It leverages **Kubernetes CRDs**, **multi-tenant isolation**, and **virtual workspaces** to deliver complete infrastructure (VMs) and platform (hosted clusters) services. SCO abstracts away complexity while maintaining the powerful Kubernetes declarative model, allowing service providers to offer managed services and cloud users to consume them through familiar Kubernetes APIs.

## Core Value Proposition

SCO transforms infrastructure and platform teams into service providers by:

- **Enabling Service Delivery**: Create and deliver any service as a managed offering through a unified marketplace
- **Providing Complete Isolation**: Cloud users operate in isolated environments without direct cluster access
- **Supporting Multiple Access Methods**: Users can interact via kubectl, Terraform, GitOps tools, or custom UIs
- **Leveraging Kubernetes Native**: Everything is Kubernetes-native using CRDs and standard tools

## Target Audience

**Managed Service Providers (MSPs)**: Deliver cloud services to customers with complete isolation and self-service capabilities.

**Enterprises**: Create internal service catalogs and standardize service delivery across teams and business units.

**Cloud Providers**: Build and scale multi-tenant cloud platforms offering diverse services through a unified API layer.

## How It Works

SCO combines several key capabilities on a Kubernetes foundation:

- **Kubernetes Foundation**: Enterprise-grade Kubernetes (tested on OpenShift 4.14+)
- **Virtual API Layer**: Multi-tenant Kubernetes API with workspace isolation
- **CRD-Based Solutions**: Standard Kubernetes custom resources for service definitions
- **VM Management**: KubeVirt-based virtual machine orchestration
- **Hosted Control Planes**: HyperShift for Kubernetes-on-Kubernetes clusters
- **Multi-Tenant Operator (MTO)**: Network and resource isolation per project
- **Keycloak Integration**: Authentication with dedicated realms per organization
- **Composition Framework**: Support for multiple composition tools (Crossplane, KRO, custom operators)

Service providers create solutions (Kubernetes CRDs representing services) using their preferred composition tools, publish them to the marketplace, and cloud users provision them into isolated projects using standard Kubernetes APIs. Out-of-the-box solutions include **Virtual Machines** and **Hosted Kubernetes Clusters**.

## What's Next?

- [Key Features](key-features.md) - Explore SCO's core capabilities
- [Use Cases](use-cases.md) - See how organizations use SCO
- [Architecture](../architecture/architecture.md) - Understand the technical architecture
- [Getting Started for Service Providers](../service-provider-guide/getting-started.md)
- [Getting Started for Cloud Users](../cloud-user-guide/getting-started.md)
