# How to Provision a Virtual Machine

Learn how to provision a virtual machine in your project.

Emma, a developer at ACME Corp, needs a Linux virtual machine for her development environment. She can provision a VM with a chosen OS, instance size, and network connectivity in minutes.

## Prerequisites

- A [Project](create-project.md) already created
- The `virtualmachine.compute.cloud.stakater.com` API available
- `kubectl` configured with your project kubeconfig
- An SSH public key for VM access

## Cloud VM

### Step 1: Prepare Your SSH Key

Encode your SSH public key as base64:

```bash
cat ~/.ssh/id_ed25519.pub | base64 -w 0
```

Copy the output — you will use it in the `sshPublicKey.data` field.

### Step 2: Define a Minimal VM Claim

Create a file named `vm.yaml` with the required parameters:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachine
metadata:
  name: my-dev-vm
spec:
  parameters:
    flavour: rhel9
    instanceType: o1.small
```

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `parameters.flavour` | OS image to use (see [Supported Flavours](#supported-flavours)) |
| `parameters.instanceType` | VM size (see [Instance Types](#instance-types)) |

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `parameters.storageSize` | `medium` (30 Gi) | Storage size: `small` (10 Gi), `medium` (30 Gi), `large` (50 Gi), `xlarge` (100 Gi) |
| `parameters.connection` | `private` | Network access: `private` (no external IP) or `public` (LoadBalancer Service) |
| `parameters.sshPublicKey.data` | — | Base64-encoded SSH public key for VM access |
| `parameters.cloudInit.userData` | — | Cloud-init `userData` script injected into the VM |

### Step 3: Add SSH Key and Network Options

A more complete example with SSH access and private networking:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachine
metadata:
  name: my-dev-vm
spec:
  parameters:
    flavour: rhel9
    instanceType: o1.small
    storageSize: medium
    connection: private
    sshPublicKey:
      data: <base64-encoded-ssh-public-key>
```

To make the VM publicly accessible via a LoadBalancer:

```yaml
spec:
  parameters:
    flavour: rhel10
    instanceType: o1.small
    storageSize: medium
    connection: public
    sshPublicKey:
      data: <base64-encoded-ssh-public-key>
```

### Step 4: Cloud-Init Customisation (Optional)

Use `cloudInit.userData` to run scripts on first boot:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachine
metadata:
  name: my-dev-vm
spec:
  parameters:
    flavour: rhel9
    instanceType: o1.medium
    connection: private
    sshPublicKey:
      data: <base64-encoded-ssh-public-key>
    cloudInit:
      userData: |
        #cloud-config
        packages:
          - git
          - curl
          - vim
        runcmd:
          - systemctl enable --now sshd
```

### Step 5: Apply the Claim

```bash
kubectl apply -f vm.yaml
```

### Step 6: Monitor the VM

Check the VM status:

```bash
kubectl get virtualmachine my-dev-vm
```

Wait for the VM to reach `Running` status:

```text
NAME         READY   SYNCED   PRINTABLE-STATUS   AGE
my-dev-vm    True    True     Running            3m
```

Retrieve the VM's connection details (for `public` VMs):

```bash
kubectl get virtualmachine my-dev-vm \
  -o jsonpath='{.status.vm.serviceHostname}'
```

SSH into the VM:

```bash
ssh cloud-user@<vm-hostname-or-ip>
```

### Supported Flavours

| Flavour | Description |
|---------|-------------|
| `rhel7` | Red Hat Enterprise Linux 7 |
| `rhel8` | Red Hat Enterprise Linux 8 |
| `rhel9` | Red Hat Enterprise Linux 9 |
| `rhel10` | Red Hat Enterprise Linux 10 |
| `fedora` | Fedora |
| `centos-stream9` | CentOS Stream 9 |
| `centos-stream10` | CentOS Stream 10 |

### Instance Types

Common instance types (contact your administrator for the full list):

| Instance Type | Profile |
|---------------|---------|
| `o1.nano` | Minimal resources |
| `o1.micro` | Very small |
| `o1.small` | Small general purpose |
| `o1.medium` | Medium general purpose |
| `o1.large` | Large general purpose |
| `o1.xlarge` | Extra large general purpose |
| `cx1.medium` | Compute optimised medium |
| `m1.medium` | Memory optimised medium |

## What's Next?

- [Create a Project](create-project.md) - Create the project where VMs are deployed
- [Create an IAM User](create-iam-user.md) - Add users who need VM access
- [Provision an OpenShift Cluster](provision-openshift-cluster.md) - Provision an OpenShift cluster
