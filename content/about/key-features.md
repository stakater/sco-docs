# Key Features

The core capabilities that make SCO a production-grade, self-hosted cloud platform.

## Virtual API Layer

Every organisation and project in SCO gets its own **virtual Kubernetes API endpoint**. Consumers interact with this endpoint exactly as they would a real Kubernetes cluster — running `kubectl`, connecting a GitOps pipeline, or pointing a Terraform provider at it.

Behind the scenes, this virtual API layer:

- Provides each project with a fully isolated API server surface
- Enforces tenant boundaries at the API level, not just the namespace level
- Aggregates APIs published by the platform team into a single endpoint per project
- Scales to hundreds of concurrent projects on a single management cluster

Consumers experience complete workspace autonomy. Providers retain full visibility and control of the underlying platform.

## Service Composition Engine

Platform providers define services as **Kubernetes custom resource definitions**. Each service specifies the fields consumers can configure, the defaults that apply, and the infrastructure or platform components that fulfil the request.

The composition engine handles the gap between what a consumer declares and what actually needs to be provisioned — creating cloud resources, applying operators, issuing credentials, and wiring components together — all triggered by a single Kubernetes claim.

This enables providers to:

- Expose simple, opinionated APIs for complex infrastructure (e.g., a VM claim that provisions storage, networking, and credentials automatically)
- Version and evolve service APIs without breaking consumers
- Compose services from cloud infrastructure, operators, internal APIs, or any combination
- Offer services across multiple cloud providers or infrastructure backends through a unified API surface

## Service Catalogue and Marketplace

Providers publish services to a **built-in catalogue**. Consumers browse available services, view documentation, and provision instances — all without involving the platform team after initial publication.

Out-of-the-box services include:

- **Virtual Machines** — Linux VMs with configurable OS, instance size, storage, and network connectivity
- **OpenShift Clusters** — Hosted Kubernetes clusters on demand with configurable compute and node pool settings

Custom services defined by your platform team appear alongside the built-in offerings in the same catalogue.

## Project Isolation

Each project is a **fully isolated environment** with:

- A dedicated virtual API endpoint
- Scoped network isolation — project traffic is segregated at the network level
- Resource quotas — configurable limits on CPU, memory, and storage
- Independent role-based access control — users and groups can be granted access per project without any cross-project visibility

Projects are provisioned in seconds and require no manual setup from the platform team. A developer requesting a new environment gets a working, isolated Kubernetes API endpoint immediately.

## Organisation-Level Identity

Each organisation runs with **fully isolated identity management**. Users, groups, and authentication flows are scoped per organisation — there is no shared identity pool across tenants.

This means:

- An MSP can host multiple customer organisations with zero identity bleed between them
- Each organisation can integrate its own corporate identity provider (LDAP, SAML, OIDC)
- Users in one organisation cannot see or access any resources in another

## Multi-Access Compatibility

The virtual API layer is a standard Kubernetes API — any tool that speaks Kubernetes works with SCO:

| Access Method | Experience |
|---------------|------------|
| **kubectl** | Standard commands against the project API endpoint |
| **GitOps** (ArgoCD, Flux) | Point at the project's kubeconfig; automated sync works as normal |
| **Terraform** | Kubernetes provider targets the project API endpoint |
| **Custom UIs** | Build dashboards or portals that talk to the Kubernetes API |

Consumers use whichever access method suits their workflow. The API is the same regardless.

## Role-Based Access Control

Access to projects, services, and the organisation itself is managed through Kubernetes-native RBAC. Providers can:

- Define organisation-level administrators
- Grant per-project access to specific users or groups
- Assign read-only or full-control roles per project
- Propagate group membership from the organisation identity provider into project role bindings automatically

## Self-Hosted on Your Infrastructure

SCO runs on **Red Hat OpenShift on bare metal**. It requires no external cloud accounts, no managed control planes, and no public cloud connectivity (unless your services themselves need it).

All control plane components, tenant isolation, identity management, and service orchestration run within your own cluster boundaries. You retain full ownership of the platform, the data, and the network.

## What's Next?

- [Use Cases](use-cases.md) - See how organisations apply these features in practice
- [Benefits](benefits.md) - Understand the business and operational value
- [Architecture](../architecture/architecture.md) - Explore the technical design
