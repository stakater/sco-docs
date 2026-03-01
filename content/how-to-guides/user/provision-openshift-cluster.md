# How to Provision an OpenShift Cluster

Learn how to provision a managed OpenShift cluster for your team via a Project claim.

Sam, a senior platform engineer at ACME Corp, needs to provide a dedicated OpenShift cluster for a product team. Sam can provision a fully managed cluster with configurable compute and node pool settings.

## Prerequisites

- Access to your organisation's project
- The `openshiftcluster.kubernetes.cloud.stakater.com` api available
- `kubectl` configured with your organisation project kubeconfig
- Sufficient permissions to create `OpenShiftCluster` resources

## What Gets Created

When you create an OpenShiftCluster claim, the platform provisions:

- A managed **OpenShift cluster** with a dedicated control plane
- A **node pool** with configurable size and replica count
- **Cluster credentials** stored securely in your organisation's secrets store

## Step 1: Minimal Configuration

Create a file named `cluster.yaml` with only the required parameters:

```yaml
apiVersion: kubernetes.cloud.stakater.com/v1
kind: OpenShiftCluster
metadata:
  name: my-cluster
spec:
  parameters:
    clusterName: my-cluster
    compute:
      cpu: 2
      memory: "8Gi"
```

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `parameters.clusterName` | Name of the OpenShift cluster (1–63 characters) |
| `parameters.compute.cpu` | Number of CPU cores per node (1–8) |
| `parameters.compute.memory` | Memory per node (e.g., `8Gi`, `16Gi`) |

## Step 2: Full Configuration

For production use, specify all parameters explicitly:

```yaml
apiVersion: kubernetes.cloud.stakater.com/v1
kind: OpenShiftCluster
metadata:
  name: prod-cluster
spec:
  parameters:
    clusterName: prod-cluster
    version: "4.19"
    compute:
      cpu: 4
      memory: "16Gi"
    storage:
      rootVolumeSize: "120Gi"
    nodePool:
      replicas: 3
      labels:
        environment: production
        team: platform
```

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `parameters.version` | `4.19` | OpenShift version (`4.18`, `4.19`, `4.20`) |
| `parameters.storage.rootVolumeSize` | `10Gi` | Root volume size per node (e.g., `120Gi`) |
| `parameters.nodePool.replicas` | `3` | Number of nodes in the pool (1–10) |
| `parameters.nodePool.labels` | — | Custom labels to apply to nodes |

## Step 3: Apply the Claim

```bash
kubectl apply -f cluster.yaml
```

## Step 4: Monitor Provisioning

Cluster provisioning takes several minutes. Monitor progress:

```bash
kubectl get openshiftcluster my-cluster
```

Check detailed status and conditions:

```bash
kubectl describe openshiftcluster my-cluster
```

Once provisioning completes, the cluster status will show `READY: True`:

```text
NAME         READY   SYNCED   AGE
my-cluster   True    True     15m
```

!!! tip
    Contact your platform administrator for the list of validated and supported OpenShift versions for your environment.

## What's Next?

- [Create a Project](create-project.md) - Create projects for teams on the new cluster
- [Create an IAM Group](create-iam-group.md) - Set up group-based access to the cluster
- [Provision a Virtual Machine](provision-virtual-machine.md) - Deploy VMs alongside your cluster
