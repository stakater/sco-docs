# Use Cases

How organisations use Stakater Cloud Orchestrator to deliver services and build modern platforms.

---

## Managed Service Providers: Multi-Tenant Cloud Delivery

A managed service provider hosts infrastructure for multiple enterprise customers, each with strict requirements around isolation, data residency, and compliance. Their challenge: delivering a modern self-service cloud experience without the cost and complexity of maintaining separate physical environments per customer.

With SCO, they run a single OpenShift cluster on their bare-metal data centre and deliver isolated environments to each customer organisation. Each customer gets:

- Their own virtual API endpoint — using familiar Kubernetes API structure
- Fully isolated identity management with their own corporate SSO integration
- A self-service catalogue of infrastructure services (VMs, hosted clusters, storage)
- Network isolation that prevents any cross-customer traffic

The platform team publishes new services once; all customers see them in their catalogue. Capacity and quota are managed centrally. Customers provision and manage their own resources through standard Kubernetes tooling without any involvement from the MSP operations team.

**Result**: The provider operates a multi-tenant cloud platform for dozens of customers with a small platform team — no ticket queues, no per-customer infrastructure silos, and full compliance with data residency requirements.

---

## Enterprise Platform Engineering: The Internal Developer Platform

A large enterprise has dozens of product teams, each needing development, staging, and production environments. Platform engineering is overwhelmed with provisioning requests, and developers are frustrated with multi-week lead times for new environments.

The platform engineering team uses SCO to build an internal developer platform on top of their existing OpenShift investment. They define a catalogue of standard services:

- **Virtual machines** for legacy application workloads that aren't containerised
- **Hosted OpenShift clusters** for teams that need full cluster-admin access to their own environment
- **Databases and message queues** composed of existing operators and cloud infrastructure
- **Developer tooling** pre-configured with CI/CD pipelines and secrets management

Each product team gets a project. They provision services from the catalogue independently. Platform engineering reviews and approves new service types, not individual provisioning requests.

**Result**: Developer environments that took weeks to provision now take minutes. The platform engineering team shifted from ticket-driven operations to platform product development. All environments are consistent, quota-bounded, and auditable.

---

## Regulated Industries: Sovereign Cloud on Private Infrastructure

A financial services firm cannot use public cloud hypervisors for core workloads due to regulatory requirements around data residency and auditability. But their teams still need self-service access to compute and Kubernetes environments to build modern applications.

SCO deployed on their own bare-metal infrastructure gives them a private cloud experience with the self-service and API-driven workflows their developers expect. The security team gains:

- All provisioning actions recorded in the Kubernetes audit log
- Service definitions reviewed and approved as code through their standard governance process
- No cross-tenant credential sharing — each team's access is scoped to their own project
- Network isolation enforced at the infrastructure level, not just through policy

Development teams get:

- On-demand virtual machines and hosted Kubernetes clusters
- Standard Kubernetes API access via their existing tooling
- Environment parity between development and production without platform team involvement

**Result**: The firm delivers a developer experience comparable to public cloud, running entirely within their own network perimeter, satisfying audit and compliance requirements without compromising developer velocity.

---

## Platform Modernisation: Replacing Ticket-Based Provisioning

An infrastructure team manages a combination of legacy VM environments and newer Kubernetes clusters. Every provisioning request — new VM, new namespace, new service account — flows through a ticketing system. The team is a bottleneck, and the average wait time for a new environment is two weeks.

They adopt SCO incrementally. They start by wrapping their existing VM infrastructure in SCO service definitions — consuming teams get self-service access to virtual machines through the SCO catalogue without the platform team changing how VMs are actually provisioned underneath. The ticket queue for VM requests drops immediately.

Over time, they add hosted Kubernetes clusters as a service, then database services, then custom tooling. Each new service is defined once by the platform team and available to all consuming teams immediately.

**Result**: The platform team eliminated the operational bottleneck without a "big bang" migration. Each service they publish to the catalogue permanently removes that category of request from the ticket queue.

---

## Telecommunications: Edge and Regional Cloud

A telecommunications provider operates infrastructure across dozens of regional data centres. They need to offer compute and Kubernetes services to internal teams and enterprise customers from a standardised platform — but managing dozens of separate cloud environments is operationally impractical.

SCO is deployed at each regional site with a common configuration. Platform teams define services centrally and publish them across regions. Customers interact with a regionally-local virtual API endpoint that provides the same service catalogue regardless of which site their workload runs on.

Consumer-facing APIs are identical across all regions. The platform team manages the fleet through standard Kubernetes tooling. Regional differences in hardware, networking, and storage classes are abstracted into service definitions — consumers never see them.

**Result**: A geographically distributed cloud platform with a consistent consumer experience, operated as a single logical platform by a central team.

---

## What's Next?

- [Key Features](key-features.md) - The capabilities that enable these use cases
- [Benefits](benefits.md) - The value delivered to providers and consumers
- [Architecture](../architecture/architecture.md) - The technical design behind SCO
- [Getting Started](../service-provider-guide/getting-started.md) - Start building your platform
