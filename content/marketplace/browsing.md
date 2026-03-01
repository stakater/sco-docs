# Browsing the Marketplace

The marketplace catalogue is accessed through your project's Kubernetes API endpoint. Every service available in the marketplace appears as a native Kubernetes resource type — no separate marketplace API or portal is required.

---

## Discovering Available Services

### List all available services

```bash
kubectl api-resources | grep cloud.stakater.com
```

This shows every service type your platform team has published. Example output:

```text
NAME                  APIVERSION                          NAMESPACED   KIND
virtualmachines       compute.cloud.stakater.com/v1       true         VirtualMachine
openshiftclusters     kubernetes.cloud.stakater.com/v1    true         OpenShiftCluster
projects              tenant.cloud.stakater.com/v1        true         Project
users                 iam.cloud.stakater.com/v1           true         User
groups                iam.cloud.stakater.com/v1           true         Group
postgresqldatabases   databases.cloud.stakater.com/v1     true         PostgreSQLDatabase
```

### Inspect a service's parameters

```bash
kubectl explain virtualmachine.spec.parameters
kubectl explain virtualmachine.spec.parameters.instanceType
```

Full API documentation for built-in services:

- [Virtual Machine](../api-reference/public-apis/virtual-machine.md)
- [OpenShift Cluster](../api-reference/public-apis/openshift-cluster.md)
- [Project](../api-reference/public-apis/project.md)
- [IAM User](../api-reference/public-apis/iam-user.md)
- [IAM Group](../api-reference/public-apis/iam-group.md)

---

## The Built-in Catalogue

SCO ships with the following services out of the box:

| Service | API | Description |
|---------|-----|-------------|
| Virtual Machine | `compute.cloud.stakater.com/v1 VirtualMachine` | Linux VMs with configurable OS, instance type, storage, and networking |
| OpenShift Cluster | `kubernetes.cloud.stakater.com/v1 OpenShiftCluster` | Hosted OpenShift clusters with configurable compute and node pools |
| Project | `tenant.cloud.stakater.com/v1 Project` | Isolated project environments |
| IAM User | `iam.cloud.stakater.com/v1 User` | Organisation user accounts |
| IAM Group | `iam.cloud.stakater.com/v1 Group` | Organisation groups for access management |

Platform teams can extend this catalogue with any additional services — databases, message queues, AI/ML platforms, and more. Custom services appear alongside the built-in offerings in the same `kubectl api-resources` output.

---

## Checking What You Have Provisioned

```bash
# All virtual machines
kubectl get virtualmachines

# All OpenShift clusters
kubectl get openshiftclusters

# Everything in your project
kubectl get all
```

---

## What's Next?

- [Solution Catalog](solution-catalog.md) — Detailed catalogue of available service types
- [Provisioning Solutions](../cloud-user-guide/solutions/provisioning-solutions.md) — Apply a claim to provision a service
- [API Reference](../api-reference/overview.md) — Full technical parameter reference
