# Core Concepts

Understanding the fundamental concepts in Stakater Cloud Orchestrator is essential for both service providers and cloud users.

## Organization

An **Organization** is a logical grouping of users and projects that represents a company, business unit, or customer tenant.

- Maps to a dedicated Keycloak realm for authentication isolation
- Contains one or more projects
- Has its own set of users and permissions
- Provides complete isolation from other organizations
- Created through the **organization onboarding** workflow (not self-service)

**Creation Methods**:

- **Automated**: Triggered by customer signup flow
- **Manual**: Created by hosting company to onboard new customers

**Example**: A managed service provider creates an organization for each customer through the onboarding process, which provisions a dedicated Keycloak realm and sets up initial admin users.

## Project

A **Project** is an isolated environment where cloud users deploy and manage their solutions.

- Combines a KCP workspace (virtual API) with an MTO tenant (actual resources)
- Provides network and resource isolation
- Users interact with the project through the virtual API layer
- Created by **organization admins** by applying a manifest
- Projects can be assigned to individual users with specific roles or groups with assigned permissions
- No direct access to the host Kubernetes cluster

**Example**: An organization admin creates "dev" and "prod" projects for their development team. The dev project is assigned to the developers group with full access, while the prod project is assigned to specific users with restricted permissions.

### KCP Workspace Component

Each project includes a KCP workspace that:

- Provides a virtual Kubernetes API endpoint
- Exposes available solution CRDs
- Handles API requests from kubectl, Terraform, GitOps tools
- Acts as the control plane for the project

### MTO Tenant Component

Each project includes an MTO tenant that:

- Provisions actual Kubernetes resources in the host cluster
- Enforces network isolation between projects
- Applies resource quotas and limits
- Manages namespaces and network policies

## Solution

A **Solution** is a service offering that can be provisioned by cloud users, represented as a Custom Resource Definition (CRD).

- Defines a service template (e.g., VirtualMachine-as-a-Service, OpenShift-as-a-Service)
- Created using Crossplane compositions
- Published to the KCP API layer
- Appears in the marketplace for discovery
- Has a defined API (CRD) that users interact with

**Example**: The "VirtualMachine" solution allows users to provision VMs by creating a `VirtualMachine` custom resource with configuration like instance type, SSH key, and cloud-init data.

### Flagship Solutions

SCO includes two flagship solutions out of the box:

**VirtualMachine** (`vm.cloud.stakater.com/v1`):

- User-facing marketplace API for provisioning VMs
- Provisions Linux VMs using OpenShift Virtualization (KubeVirt)
- Supports multiple instance types (cx1, m1, n1, o1, rt1, u1 series)
- Cloud-init for VM bootstrapping
- Public (LoadBalancer) or private networking
- SSH key-based authentication

**OpenShiftCluster** (`openshiftcluster.cloud.stakater.com/v1`):

- User-facing marketplace API for provisioning OpenShift clusters
- Provisions full OpenShift clusters using hypershift
- Hosted control plane architecture
- Configurable node pools and sizing
- etcd backup and disaster recovery
- Automated DNS and TLS configuration

!!! note "API Groups"
    - **`*.cloud.stakater.com`**: User-facing APIs published to the marketplace
    - **`*.infrastructure.stakater.com`**: Backend APIs for internal orchestration (not published to KCP)

### Solution Components

Solutions are composed of:

- **Composite Resource Definition (XRD)**: Defines the API schema
- **Composition**: Implements the service using underlying resources
- **Provider Resources**: Actual infrastructure resources (VMs, clusters, networking)
- **Documentation**: Usage instructions and examples

## Solution Instance

A **Solution Instance** is a running instance of a solution provisioned within a project.

- Created by cloud users through the virtual API
- Lives within a specific project
- Managed through Kubernetes custom resources
- Has a lifecycle (create, update, delete)
- Isolated from other solution instances

**Example**: A user creates a VirtualMachine solution instance named "my-app-vm" in their "prod" project, which provisions an actual virtual machine with the specified configuration.

## Marketplace

The **Marketplace** is a catalog of available solutions that cloud users can browse and provision.

- Displays all solutions published by service providers
- Provides solution discovery and documentation
- Shows solution versions and capabilities
- Accessible through the console UI
- Solutions are provisioned by creating CRs in the project

**Example**: Cloud users browse the marketplace to discover available databases, message queues, and other services they can provision.

## Virtual API Layer

The **Virtual API Layer** provides a unified Kubernetes API surface with multi-tenancy that abstracts physical clusters.

- Users interact with a Kubernetes-compatible API
- Solutions publish CRDs to isolated workspaces
- Standard Kubernetes client tools work seamlessly
- No direct cluster access required
- Enables transparent multi-cluster orchestration

**Example**: A user runs `kubectl get virtualmachine` against their project's kubeconfig, which connects to their isolated virtual workspace, not directly to a physical cluster.

## Service Provider

A **Service Provider** is a platform team or administrator who creates and manages the SCO platform.

- Creates solutions using composition tools (Crossplane, KRO, or custom operators)
- Publishes solutions to the marketplace
- Creates organizations for cloud users
- Manages the underlying infrastructure
- Defines quotas and policies

**Example**: Sarah, a platform engineer, creates custom database solutions and publishes them to the marketplace for her organization's developers.

## Cloud User

A **Cloud User** is an end user who consumes services from the marketplace.

- Authenticates to their organization via Keycloak
- Creates and manages projects
- Browses the marketplace
- Provisions solution instances
- Interacts via kubectl, Terraform, GitOps, or UI
- No access to host cluster or other organizations

**Example**: Emma, a developer, logs in to her organization, creates a project, and provisions a virtual machine for her application.

## User Management

**Users** are individual accounts within an organization that authenticate via Keycloak.

- Created using the **iam-user-package** in the organization's Keycloak realm
- Each user belongs to a single organization
- Can be assigned to one or more groups
- Have specific roles and permissions for projects
- Authenticate using organization-specific credentials

**Example**: An organization admin creates user accounts for new team members. Each user is added to the organization's Keycloak realm and assigned to appropriate groups like "developers" or "operators".

## Group Management

**Groups** provide a way to organize users and assign permissions collectively within an organization.

- Created using the **iam-group-package** in the organization's Keycloak realm
- Can contain multiple users from the same organization
- Simplify permission management by assigning access at the group level
- Projects can be assigned to groups rather than individual users
- Enable role-based access control (RBAC) patterns

**Example**: An organization admin creates a "frontend-team" group and assigns it full access to the "dev-frontend" project. All users added to this group automatically inherit the project permissions.

## API Publishing

Solutions are published to make their APIs available across isolated workspaces.

- Solutions expose their CRDs to the virtual API layer
- Projects can access published solution APIs
- Enables API sharing across isolation boundaries
- Standard Kubernetes API semantics

**Example**: The VirtualMachine solution publishes its `vm.cloud.stakater.com` API, which projects can access to create VirtualMachine resources.

## Virtual Machine Management

SCO provides VM-as-a-Service using **KubeVirt** technology for virtual machine orchestration.

- Runs VMs alongside containers in the same cluster
- VMs are managed as Kubernetes custom resources
- Provides live migration, snapshots, and cloning
- Supports various Linux distributions
- Integrates with Kubernetes networking and storage

**Platform Support**:

- **On OpenShift**: Uses OpenShift Virtualization (enterprise KubeVirt)
- **On vanilla Kubernetes**: Uses community KubeVirt

**How It Works**: When a user creates a VirtualMachine CR, SCO composition logic provisions the underlying VM infrastructure using the cluster's virtualization capabilities.

## Hosted Control Planes

SCO provides Kubernetes-as-a-Service using **hosted control plane** architecture.

- Control plane runs in pods on the management cluster
- Worker nodes run separately on available infrastructure
- Reduces resource overhead (no dedicated control plane nodes)
- Faster cluster provisioning and scaling
- Simplified control plane upgrades

**Platform Support**:

- **On OpenShift**: Uses hypershift for hosted OpenShift clusters
- **On vanilla Kubernetes**: Uses cluster-API or alternative providers

**How It Works**: Users can provision complete Kubernetes/OpenShift clusters through a simple CRD. The control plane runs in the SCO management cluster while worker nodes are provisioned on the underlying infrastructure.

## What's Next?

- [Components](components.md) - Learn about the individual components that make up SCO
- [Architecture](architecture.md) - See how these concepts fit into the overall architecture
- [Service Provider Guide](../service-provider-guide/overview.md) - Start building solutions
- [Cloud User Guide](../cloud-user-guide/overview.md) - Start using solutions
