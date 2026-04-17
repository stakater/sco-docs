# Benefits

How SCO delivers value to the teams that run it and the teams that use it.

## For Platform Engineering Teams

### Turn Infrastructure into a Product

Platform teams spend significant effort responding to ad-hoc requests: provision this cluster, create that VM, set up access for a new team. SCO changes this dynamic by letting platform teams define services once and publish them to a self-service catalogue. Requests stop arriving as tickets and start being fulfilled automatically, at the moment they're made.

The platform team retains full control over what services exist, how they're configured, and what guardrails apply — without being the bottleneck for every provisioning action.

### Enforce Standards Without Friction

Every service available in the catalogue is defined by the platform team. Consumers choose from a curated set of options; they cannot provision services in ways the platform team hasn't explicitly enabled. Quota, networking, and access policies are set once at the platform level and applied consistently across every project.

This makes compliance straightforward: the service definition is the policy.

### Reduce Operational Overhead

Provisioning, access management, quota enforcement, and network isolation are automated. Platform teams focus on improving service offerings and platform capabilities rather than executing repetitive provisioning tasks.

### Centralised Management Plane

SCO is designed as a multi-cluster platform. The management plane — KCP, Crossplane, and the service catalogue — acts as a single control point that can federate across any number of provider clusters. Additional Kubernetes clusters can be connected as provider backends, with SCO routing workloads and service requests across them transparently.

Platform teams interact with a single API surface regardless of how many clusters are running underneath. There is no need to access individual tenant environments or provider clusters to understand the state of provisioned services.

---

## For Managed Service Providers

### Multi-Tenant by Design

SCO is built for multi-tenancy from the ground up. Each customer organisation runs in complete isolation — separate API endpoints, separate identity management, separate network boundaries. One customer cannot see, reach, or affect another.

This is not namespace-level isolation with policy overlays. It is architectural separation at the API, identity, and network layers simultaneously.

### Scale Without Proportional Headcount

The self-service catalogue means customers provision their own resources. The automated composition engine means those resources are created, configured, and maintained without manual intervention. Adding a new customer does not require a proportional increase in operations staff.

### Differentiated Service Offerings

Providers can offer different service catalogues to different customer tiers. Enterprise customers might access a richer catalogue with higher-capacity instance types or additional services. Self-service customers might have access to a more constrained offering. All of this is configured in the platform without requiring separate infrastructure.

### Data Sovereignty and On-Premises Delivery

SCO runs entirely on infrastructure you control. For customers with data residency requirements, regulated industries, or air-gapped environments, SCO lets you deliver a full cloud experience without routing traffic or data through a third-party hypervisor.

---

## For Developer and Product Teams

### Self-Service, No Waiting

Developers provision the resources they need — virtual machines, clusters, custom services — without opening a ticket or waiting for approval. The catalogue shows what's available; applying a claim provisions it. Access is available within minutes.

### Familiar Tooling

Projects expose standard Kubernetes API endpoints. Developers use the same tools they already know — `kubectl`, ArgoCD, Flux, Terraform — against their SCO project. There is no proprietary SDK, no new CLI, and no unfamiliar API surface to learn.

### Isolated, Safe Environments

Every project is isolated from every other project at the API, network, and identity levels. Developers can experiment, break things, and iterate within their project without risk to other teams or shared infrastructure.

### Consistent Environments Across Teams

Because all services come from the same platform-defined catalogue with the same composition logic, a VM provisioned by one team behaves identically to a VM provisioned by another team. Environment drift and "works on my project" problems are eliminated at the source.

---

## For Security and Compliance Teams

### Least-Privilege by Default

Consumers never receive cluster-level access. They operate entirely within their project boundary. The platform team controls what actions are possible within a project through service definitions and RBAC policies.

### Audit Trail

All provisioning actions are Kubernetes API calls — they produce standard Kubernetes audit log events. Every resource creation, modification, and deletion is attributable to a specific user, at a specific time, within a specific project.

### Policy as Code

Service definitions are code, stored in version control, reviewed through standard pull request workflows. The set of permitted configurations is explicit and auditable. There are no out-of-band manual steps that could introduce non-compliant resources.

### No Shared Credentials

Identity is scoped per organisation. Users in one organisation never hold credentials that grant access to another organisation's resources. Cross-tenant access is architecturally impossible, not just policy-prohibited.

## What's Next?

- [Use Cases](use-cases.md) - See how organisations apply SCO in practice
- [Key Features](key-features.md) - Explore the capabilities that deliver these benefits
- [Getting Started](../service-provider-guide/getting-started.md) - Start building your platform
