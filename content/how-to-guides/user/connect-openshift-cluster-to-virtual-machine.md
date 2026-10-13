# How to Connect an OpenShift Cluster to a Virtual Machine

Let workloads on your OpenShift cluster reach a private virtual machine in the same project, on the ports you choose.

Sam, a platform engineer at ACME Corp, runs the team's applications on a private OpenShift cluster and keeps their SQL Server database on a Windows virtual machine. The applications need to reach the database on port 1433, and nothing else should.

## Prerequisites

- The `project.tenant.cloud.stakater.com` api available
- The `openshiftcluster.kubernetes.cloud.stakater.com` api available
- The `windowsvirtualmachine.compute.cloud.stakater.com` or `virtualmachine.compute.cloud.stakater.com` api available
- `kubectl` configured with your organisation project kubeconfig

!!! note
    The cluster and the virtual machine must be in the **same project**, and that project must use `network.mode: native`. An existing project cannot switch to `native` from the default mode. Create a new project for this.

## What Gets Created

When you add a peer to a virtual machine, the platform provisions:

- **Access from the named OpenShift cluster** to the virtual machine, on the listed ports only
- A **stable address** for the virtual machine, shown in `status.peering.address`, which stays the same when the virtual machine restarts or moves

Everything else stays blocked: other ports, other clusters, and other projects.

## Step 1: Create a Native Project

Create `project.yaml`:

```yaml
apiVersion: tenant.cloud.stakater.com/v1
kind: Project
metadata:
  name: app-platform
spec:
  parameters:
    name: app-platform
    network:
      name: app-platform
      mode: native
```

```bash
kubectl apply -f project.yaml
```

A `native` project needs no `network.cidr`. Its resources are closed to traffic from outside the project until you grant access.

## Step 2: Provision the OpenShift Cluster

In the new project, provision the cluster as described in [Provision an OpenShift Cluster](provision-openshift-cluster.md). For example:

```yaml
apiVersion: kubernetes.cloud.stakater.com/v1
kind: OpenShiftCluster
metadata:
  name: app-cluster
spec:
  parameters:
    version: "4.21"
    networking:
      mode: private
```

## Step 3: Create the Virtual Machine with a Peer

Create `sql-vm.yaml`, naming the cluster as a peer and listing the ports it may use:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: WindowsVirtualMachine
metadata:
  name: sql-vm
spec:
  parameters:
    flavour: win2k25
    instanceType: o1.small
    storageSize: medium
    connection: private
    peers:
      - kind: OpenShiftCluster
        name: app-cluster
        ports:
          - port: 1433
```

```bash
kubectl apply -f sql-vm.yaml
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `peers[].kind` | — | `OpenShiftCluster` |
| `peers[].name` | — | Name of an OpenShift cluster in the same project |
| `peers[].ports[].port` | — | Port the cluster may reach on the virtual machine |
| `peers[].ports[].protocol` | `TCP` | `TCP` or `UDP` |

A `VirtualMachine` (Linux) takes the same `peers` field. You can list up to 16 peers, each with its own ports.

!!! tip
    You can create the virtual machine before the cluster exists. The peer shows `Pending` until the cluster is there, then turns `Ready`.

## Step 4: Verify

Check the peer state and the address:

```bash
kubectl get windowsvirtualmachine sql-vm -o jsonpath='{.status.peering}'
```

```json
{"address":"172.30.155.59","peers":[{"kind":"OpenShiftCluster","name":"app-cluster","state":"Ready"}]}
```

| State | Meaning |
|-------|---------|
| `Ready` | The cluster can reach the virtual machine on its ports |
| `Pending` | Being set up, or the cluster does not exist yet |
| `Rejected` | Not allowed; `message` explains why, for example the cluster is in another project |

Then, from a pod on the OpenShift cluster, connect to the address on the granted port:

```bash
oc run conn-test --rm -it --restart=Never --image=registry.access.redhat.com/ubi9/ubi-minimal -- \
  bash -c 'timeout 5 bash -c "</dev/tcp/172.30.155.59/1433" && echo open || echo blocked'
```

Port 1433 prints `open`; any other port prints `blocked`.

## Step 5: Give Applications a Name for the Database

Applications should use a name rather than the address. In the OpenShift cluster, create a Service without a selector and point it at `status.peering.address`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: sql-vm
  namespace: my-app
spec:
  ports:
    - name: mssql
      port: 1433
      protocol: TCP
---
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: sql-vm-1
  namespace: my-app
  labels:
    kubernetes.io/service-name: sql-vm
addressType: IPv4
ports:
  - name: mssql
    port: 1433
    protocol: TCP
endpoints:
  - addresses:
      - 172.30.155.59
```

Applications in `my-app` can now connect to `sql-vm:1433`.

## Keep Remote Access over the Mesh

Peering does not replace remote access. People in your organisation can still RDP or SSH to the virtual machine over your organisation mesh. Turn it on with `meshRoute` on the same virtual machine:

```yaml
spec:
  parameters:
    meshRoute:
      enabled: true
```

## Full Example

```yaml
apiVersion: tenant.cloud.stakater.com/v1
kind: Project
metadata:
  name: app-platform
spec:
  parameters:
    name: app-platform
    network:
      name: app-platform
      mode: native
---
apiVersion: kubernetes.cloud.stakater.com/v1
kind: OpenShiftCluster
metadata:
  name: app-cluster
spec:
  parameters:
    version: "4.21"
    networking:
      mode: private
---
apiVersion: compute.cloud.stakater.com/v1
kind: WindowsVirtualMachine
metadata:
  name: sql-vm
spec:
  parameters:
    flavour: win2k25
    instanceType: o1.small
    storageSize: medium
    connection: private
    meshRoute:
      enabled: true
    peers:
      - kind: OpenShiftCluster
        name: app-cluster
        ports:
          - port: 1433
```

## What's Next?

- [Create a Project](create-project.md) - More on project settings and access
- [Provision an OpenShift Cluster](provision-openshift-cluster.md) - Cluster sizing, networking and access
- [Provision a Virtual Machine](provision-virtual-machine.md) - Flavours, instance types and SSH keys
- [Create a Mesh](create-mesh.md) - Set up your organisation mesh for remote access
