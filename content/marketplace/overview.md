# Marketplace Overview

The SCO Marketplace is a centralized catalog where cloud users discover and provision solutions published by service providers.

## What is the Marketplace?

The marketplace serves as the service catalog for your SCO platform, providing:

- **Solution Discovery**: Browse available services and their capabilities
- **Self-Service Provisioning**: Request and deploy services without manual intervention
- **Documentation**: Access solution-specific documentation and examples
- **Version Management**: See available solution versions and updates

## How the Marketplace Works

### For Service Providers

Service providers (platform engineers) create solutions using Crossplane, KRO, or custom operators. These solutions are published to the marketplace, making them available to cloud users.

**Publishing Flow**:

1. Create a solution (XRD + Composition)
1. Define solution metadata and documentation
1. Publish to KCP as an APIExport
1. Solution appears in the marketplace

### For Cloud Users

Cloud users browse the marketplace, discover solutions they need, and provision instances into their projects.

**Consumption Flow**:

1. Browse the marketplace
1. Select a solution (e.g., PostgreSQL)
1. Configure the solution instance
1. Provision into a project
1. Manage the solution lifecycle

## Solution Types

SCO provides flagship solutions out of the box and supports custom solutions:

### Flagship Solutions (Built-in)

- **Virtual Machines**: Full Linux VMs using OpenShift Virtualization
    - Multiple instance types (compute-optimized, memory-optimized, general purpose)
    - Cloud-init support for bootstrapping
    - Public and private networking options
    - SSH access
- **OpenShift Hosted Clusters**: Full OpenShift clusters using hypershift
    - Complete Kubernetes/OpenShift cluster provisioning
    - Managed control plane and worker nodes
    - Configurable node pools and scaling
    - etcd backup and disaster recovery

### Custom Solutions (Optional)

Platform teams can add additional solutions:

- **Databases**: PostgreSQL, MySQL, Redis, MongoDB (using Crossplane compositions)
- **Message Queues**: Kafka, RabbitMQ, NATS
- **Storage**: S3-compatible storage, persistent volumes
- **Observability**: Monitoring and logging solutions
- **Custom Services**: Any service defined via Crossplane

## Marketplace Features

### Search and Filter

Quickly find solutions by:

- Name or keyword
- Category or type
- Provider (AWS, Azure, GCP, on-premises)
- Version

### Solution Details

Each solution in the marketplace includes:

- **Description**: What the solution provides
- **Configuration Options**: Available parameters and settings
- **Requirements**: Prerequisites and dependencies
- **Documentation**: Usage guides and examples
- **Versions**: Available versions and changelogs

### Solution Status

Solutions have different states:

- **Available**: Ready to provision
- **Beta**: Preview version, may have limitations
- **Deprecated**: Older version, newer alternative recommended

## Access Methods

The marketplace is accessible through multiple interfaces:

- **Console UI**: Visual interface for browsing and provisioning
- **kubectl**: List and describe solutions using `kubectl get solutions`
- **API**: Programmatic access for automation
- **Terraform**: Discover and provision using Infrastructure as Code

## Solution Lifecycle

Once provisioned from the marketplace, solution instances follow a lifecycle:

1. **Requested**: User creates a solution instance CR
1. **Provisioning**: Backend resources are being created
1. **Ready**: Solution is ready to use
1. **Updating**: Configuration changes are being applied
1. **Deleting**: Solution is being removed

## What's Next?

- [Browsing the Marketplace](browsing.md) - Learn how to navigate the marketplace
- [Solution Catalog](solution-catalog.md) - See example solutions
- [Provisioning Solutions](../cloud-user-guide/solutions/provisioning-solutions.md) - Deploy solutions from the marketplace
- [Publishing Solutions](../service-provider-guide/marketplace/publishing-solutions.md) - Publish your solutions
