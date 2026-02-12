# Getting Started for Service Providers

Quick start guide for platform engineers and administrators building solutions on SCO.

Sarah is a platform engineer at CloudCo who needs to offer managed services to her organization's development teams. SCO is deployed on their Kubernetes infrastructure, providing Virtual Machines and Hosted Kubernetes Clusters as flagship services. This guide walks through the essential steps to get started with SCO as a service provider.

## Prerequisites

Before you begin, ensure you have:

- Kubernetes cluster (tested on OpenShift 4.14+ on bare metal)
- SCO installed using `ksp up` CLI
- Access to the SCO admin console
- `kubectl` or `oc` configured with admin access to the cluster
- Basic understanding of Kubernetes and CRDs
- Familiarity with composition tools (Crossplane, KRO, or custom operators)

## Step 1: Understanding Built-in Solutions

SCO comes with flagship solutions out of the box:

### Virtual Machine Solution

The **VirtualMachine** solution leverages OpenShift Virtualization to provide VM-as-a-Service.

**API Group**: `compute.cloud.stakater.com`
**Kind**: `VirtualMachine`

Users can provision VMs by creating a custom resource:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachine
metadata:
    name: my-dev-vm
    namespace: my-project
spec:
    parameters:
        instanceType: o1.medium  # 2 vCPU, 4GB RAM
        connection: private
        sshPublicKey: "ssh-rsa AAAAB3Nza..."
        cloudInit:
            userData: |
                #cloud-config
                packages:
                  - nginx
```

### OpenShift Hosted Cluster Solution

The **OpenShiftCluster** solution uses HyperShift to provide OpenShift-on-OpenShift.

**API Group**: `infrastructure.stakater.com`
**Kind**: `OpenShiftCluster`

Users can provision full OpenShift clusters:

```yaml
apiVersion: infrastructure.stakater.com/v1
kind: OpenShiftCluster
metadata:
    name: dev-cluster
    namespace: my-project
spec:
    parameters:
        hostedCluster:
            name: dev-cluster
            namespace: clusters
            nodePool:
                replicas: 3
                instanceType: m1.large
```

### Verify Available Solutions

Sarah can check what solutions are available:

```bash
oc get xrds
```

Expected output shows the built-in solutions:

```
NAME                                                   ESTABLISHED   OFFERED   AGE
virtualmachines.compute.cloud.stakater.com            True          True      10d
openshiftclusters.kubernetes.cloud.stakater.com        True          True      10d
```

## Step 2: Publish to the Marketplace

After creating the solution, publish it to make it available to cloud users.

!!! note
    Detailed marketplace publishing workflows will be added in future updates.

## Step 3: Create an Organization

Organizations provide isolation for different customers or business units. Each organization gets its own Keycloak realm.

```yaml
apiVersion: tenancy.stakater.com/v1alpha1
kind: Organization
metadata:
    name: acme-corp
spec:
    displayName: "ACME Corporation"
    keycloak:
        realm: acme-corp
        enabled: true
```

Apply the organization:

```bash
kubectl apply -f organization.yaml
```

Sarah can verify the organization was created:

```bash
kubectl get organizations
```

## Step 4: Verify Cloud Users Can Access

Once the organization is created:

1. Cloud users can log in to their organization
2. They can create projects within the organization
3. The VirtualMachine and OpenShiftCluster solutions appear in their marketplace
4. They can provision VMs and OpenShift clusters in their projects

Verify the solutions are available:

```bash
# Check that the APIExports are created
oc get apiexports -n ksp-system

# Check workspace access
oc get workspaces
```

## What You've Accomplished

Sarah has now:

✅ Understood the built-in VM and OpenShift cluster solutions
✅ Created an organization for cloud users
✅ Verified solutions are available in the marketplace
✅ Set up cloud users to provision infrastructure and platform services

## Next Steps

Now that you have the basics, explore more advanced topics:

- [Creating Custom Solutions](solutions/creating-solutions.md) - Build additional service offerings
- [Publishing to Marketplace](marketplace/publishing-solutions.md) - Detailed marketplace configuration
- [Keycloak Integration](organizations/keycloak-realms.md) - Configure authentication
- [Project Architecture](projects/project-architecture.md) - Understand workspace and tenant mapping

## Common Tasks

**Add Custom Solutions**: Create additional service offerings like databases (PostgreSQL, Redis), message queues (Kafka), or storage solutions.

**Manage Multiple Organizations**: Create separate organizations for different customers or business units.

**Configure RBAC**: Define who can create solutions and manage organizations.

**Monitor Usage**: Track VM, cluster, and project resource usage across organizations.

**Customize VM Instance Types**: Modify available instance types and sizing options.

## What's Next?

- [Solution Overview](solutions/solution-overview.md) - Deep dive into solution concepts
- [Creating Solutions](solutions/creating-solutions.md) - Advanced solution patterns
- [Creating Organizations](organizations/creating-organizations.md) - Detailed organization setup
