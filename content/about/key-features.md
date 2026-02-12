# Key Features

This page outlines the key features and capabilities of Stakater Cloud Orchestrator.

## Core Features

### Kubernetes Foundation

Built on enterprise-grade Kubernetes with production-ready testing on OpenShift.

- Kubernetes-agnostic architecture (runs on any distribution)
- Primary platform: Red Hat OpenShift 4.14+ on bare metal
- VM management using KubeVirt (OpenShift Virtualization)
- Hosted control planes using hypershift
- Standard Kubernetes APIs throughout

### Multi-Tenant API Layer

SCO provides a virtual Kubernetes API layer with true API-level multi-tenancy that abstracts physical infrastructure. Cloud users interact with a unified API surface without needing to know about underlying clusters.

- Isolated virtual workspaces per project
- Standard Kubernetes API compatibility
- No direct cluster access required
- Seamless multi-cluster orchestration
- API-level tenant isolation

### Marketplace

Built-in marketplace with flagship infrastructure and platform offerings.

- **Virtual Machines** - Full Linux and Windows VMs using OpenShift Virtualization
- **OpenShift Clusters** - Hosted control planes using hypershift
- Self-service provisioning
- Extensible with custom solutions (databases, message queues, etc.)
- Solution discovery and documentation

### Solution Orchestration

Kubernetes-native CRD-based solution framework with flexible composition.

- Define services as Kubernetes custom resources
- Support for multiple composition tools (Crossplane, KRO, custom operators)
- Declarative configuration management
- Multi-resource orchestration
- Standard Kubernetes workflows

## Multi-Access Capabilities

### kubectl Access

Native Kubernetes command-line access through virtual API layer.

- Standard kubectl commands
- Kubeconfig generation
- Full RBAC support
- Familiar Kubernetes experience

### Terraform Integration

Use Terraform Kubernetes provider against the virtual API.

- Infrastructure as Code
- Terraform state management
- Standard Kubernetes provider
- Declarative resource management

### GitOps Integration

Connect ArgoCD, Flux, or other GitOps tools to SCO.

- Continuous deployment
- Git as source of truth
- Automated synchronization
- Standard GitOps workflows

### Custom UI

Build custom user interfaces on top of the Kubernetes API.

- Web console support
- Custom dashboards
- Clickops capabilities
- Branded experiences

## Isolation & Security

### Organization Isolation

Each organization gets a dedicated Keycloak realm for complete authentication isolation.

- Separate identity management
- Custom authentication flows
- SSO integration per organization
- User federation support

### Project Isolation

Projects combine KCP workspaces with MTO tenants for complete isolation.

- Network isolation
- Resource quotas
- No host cluster access
- Separate namespaces per project

### RBAC & Security

Fine-grained access control at all levels.

- Kubernetes-native RBAC
- Organization-level permissions
- Project-level permissions
- Solution-level access control

## Integration Features

### KCP Integration

Virtual API layer powered by KCP.

- APIExport publishing
- Workspace management
- Multi-cluster API aggregation
- Virtual control planes

### Multi-Tenant Operator (MTO)

True multi-tenancy with network and resource isolation.

- Network policies
- Resource quotas
- Tenant isolation
- Distributed mode support

### Crossplane Integration

Solution composition using Crossplane.

- Composite Resource Definitions (XRDs)
- Compositions for service templates
- Provider support (AWS, Azure, GCP, OpenStack, VMWare etc.)
- Custom resource management

### Keycloak Integration

Authentication and authorization management.

- Realm per organization
- OIDC integration
- User management
- SSO support

### Vault Integration

Secrets management for solutions.

- External Secrets Operator
- Dynamic secrets
- Secrets injection
- Centralized secret management

## What's Next?

- [Use Cases](use-cases.md) - See how organizations leverage these features
- [Architecture](../architecture/architecture.md) - Deep dive into the technical architecture
- [Service Provider Guide](../service-provider-guide/overview.md) - Start building solutions
