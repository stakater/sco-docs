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

The **OpenShiftCluster** solution provides hosted OpenShift clusters on demand.

**API Group**: `kubernetes.cloud.stakater.com`
**Kind**: `OpenShiftCluster`

Users can provision full OpenShift clusters:

```yaml
apiVersion: kubernetes.cloud.stakater.com/v1
kind: OpenShiftCluster
metadata:
  name: dev-cluster
spec:
  parameters:
    clusterName: dev-cluster
    compute:
      cpu: 8
      memory: 32Gi
    nodePool:
      replicas: 3
```

### Verify Available Solutions

Sarah can check what solutions are available:

```bash
oc get xrds
```

Expected output shows the built-in solutions:

```text
NAME                                                   ESTABLISHED   OFFERED   AGE
virtualmachines.vm.cloud.stakater.com                  True          True      10d
openshiftclusters.openshiftcluster.cloud.stakater.com  True          True      10d
```

## Step 2: Publish to the Marketplace

After installing SCO, the built-in solutions are automatically published to the marketplace. Cloud users can immediately browse and provision VMs and OpenShift clusters from their projects.

To publish additional custom solutions, see [Publishing APIs](api-publishing/publishing-apis.md) for the full workflow.

## Step 3: Onboard an Organisation

Organisations provide isolation for different customers or business units. Each organisation gets its own isolated identity realm and project namespace.

Organisations are created through the platform onboarding workflow, which provisions the virtual API workspace, identity realm, and all required configuration automatically.

To manually onboard a new organisation, apply the organisation onboarding claim:

```yaml
apiVersion: infrastructure.stakater.com/v1alpha1
kind: XOrgOnboarding
metadata:
  name: acme-corp
spec:
  providerConfigRef:
    name: kubernetes-provider
  kcpRootProviderConfigRef:
    name: kcp-root-provider
  parameters:
    organizationName: acme-corp
    adminEmail: admin@acmecorp.example.com
```

```bash
kubectl apply -f org-onboarding.yaml
```

This provisions:

- An isolated identity realm for the organisation
- A virtual API workspace hierarchy for the organisation and its projects
- Initial admin credentials sent to the specified email

Verify the organisation was created:

```bash
kubectl get organizations
```

## Step 4: Verify Cloud Users Can Access

Once the organisation is created:

1. Cloud users can log in at the organisation's console URL
1. They can request projects from their organisation administrator
1. The VirtualMachine and OpenShiftCluster solutions appear in their project marketplace
1. They can provision services using `kubectl`, the console, Terraform, or GitOps

Verify the built-in solutions are published and available:

```bash
kubectl get xrds
```

Expected output:

```text
NAME                                                          ESTABLISHED   OFFERED   AGE
virtualmachines.compute.cloud.stakater.com                    True          True      1d
openshiftclusters.kubernetes.cloud.stakater.com               True          True      1d
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
