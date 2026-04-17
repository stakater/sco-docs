# Browsing the Marketplace

The marketplace is the catalogue of services available in your project. Services are published by your platform team and appear as native Kubernetes resource types in your project's API endpoint.

---

## Discovering Available Services

### Using kubectl

List all resource types available in your project:

```bash
kubectl api-resources | grep cloud.stakater.com
```

Example output:

```text
virtualmachines        compute.cloud.stakater.com/v1      VirtualMachine
openshiftclusters      kubernetes.cloud.stakater.com/v1   OpenShiftCluster
postgresqldatabases    databases.cloud.stakater.com/v1    PostgreSQLDatabase
```

The exact list depends on what your platform team has published.

### Using the Console

Navigate to **Marketplace** in the console sidebar. Each service card shows its name, description, and available configuration options.

---

## Getting Service Details

View the parameters a service accepts:

```bash
kubectl explain virtualmachine.spec.parameters

# Or a specific field
kubectl explain virtualmachine.spec.parameters.instanceType
```

Full API reference for built-in services:

- [Virtual Machine API](../../api-reference/public-apis/virtual-machine.md)
- [OpenShift Cluster API](../../api-reference/public-apis/openshift-cluster.md)

---

## Checking What You Have Provisioned

```bash
# List virtual machines
kubectl get virtualmachines

# List OpenShift clusters
kubectl get openshiftclusters

# List everything
kubectl get all
```

---

## Service Status

| Status | Meaning |
|--------|---------|
| `Provisioning` | Resources are being created |
| `Ready: True` | Service is healthy and available |
| `Ready: False` | Service has an issue — check `kubectl describe` |
| `Deleting` | Service is being removed |

---

## What's Next?

- [Provisioning Solutions](provisioning-solutions.md) — Apply a claim to provision a service
- [Provision a Virtual Machine](../../how-to-guides/user/provision-virtual-machine.md) — Step-by-step VM guide
- [Provision an OpenShift Cluster](../../how-to-guides/user/provision-openshift-cluster.md) — Step-by-step cluster guide
