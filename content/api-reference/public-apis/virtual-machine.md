# Virtual Machine

Provisions a virtual machine using predefined OS flavours and instance types.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `compute.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `VirtualMachine` |
| **Scope** | Namespaced |

## Spec Parameters

All parameters are nested under `spec.parameters`.

### Required

| Field | Type | Description |
|-------|------|-------------|
| `flavour` | `string` | OS image to use. See [Supported Flavours](#supported-flavours). |
| `instanceType` | `string` | VM size. See [Instance Types](#instance-types). |

### Optional

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `storageSize` | `string` | `medium` | Root disk size. Allowed: `small` (10 Gi), `medium` (30 Gi), `large` (50 Gi), `xlarge` (100 Gi) |
| `connection` | `string` | `private` | Network access type. `private` = no external IP; `public` = LoadBalancer Service created |
| `sshPublicKey.data` | `string` | — | Base64-encoded (or raw) SSH public key for VM access |
| `cloudInit.userData` | `string` | — | Cloud-init `userData` script injected on first boot |

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.vm.printableStatus` | `string` | Human-readable VM status (e.g., `Running`, `Stopped`, `Provisioning`) |
| `status.vm.ready` | `boolean` | Whether the VM is running and ready |
| `status.vm.created` | `boolean` | Whether the VM has been created in the cluster |
| `status.vm.cpuCores` | `integer` | Number of CPU cores |
| `status.vm.memory` | `string` | Memory size (e.g., `4Gi`) |
| `status.vm.serviceIP` | `string` | LoadBalancer IP address (if `connection: public`) |
| `status.vm.serviceHostname` | `string` | LoadBalancer hostname (if `connection: public`) |
| `status.vm.conditions` | `array` | Conditions representing the VM state |

## Supported Flavours

| Value | OS |
|-------|----|
| `rhel7` | Red Hat Enterprise Linux 7 |
| `rhel8` | Red Hat Enterprise Linux 8 |
| `rhel9` | Red Hat Enterprise Linux 9 |
| `rhel10` | Red Hat Enterprise Linux 10 |
| `fedora` | Fedora |
| `centos-stream9` | CentOS Stream 9 |
| `centos-stream10` | CentOS Stream 10 |

## Instance Types

| Instance Type | Profile |
|---------------|---------|
| `o1.nano` | General purpose — nano |
| `o1.micro` | General purpose — micro |
| `o1.small` | General purpose — small |
| `o1.medium` | General purpose — medium |
| `o1.large` | General purpose — large |
| `o1.xlarge` | General purpose — xlarge |
| `o1.2xlarge` | General purpose — 2xlarge |
| `o1.4xlarge` | General purpose — 4xlarge |
| `o1.8xlarge` | General purpose — 8xlarge |
| `cx1.medium` | Compute optimised — medium |
| `cx1.large` | Compute optimised — large |
| `cx1.xlarge` | Compute optimised — xlarge |
| `cx1.2xlarge` | Compute optimised — 2xlarge |
| `cx1.4xlarge` | Compute optimised — 4xlarge |
| `cx1.8xlarge` | Compute optimised — 8xlarge |
| `m1.large` | Memory optimised — large |
| `m1.xlarge` | Memory optimised — xlarge |
| `m1.2xlarge` | Memory optimised — 2xlarge |
| `m1.4xlarge` | Memory optimised — 4xlarge |
| `m1.8xlarge` | Memory optimised — 8xlarge |
| `n1.medium` | Network optimised — medium |
| `n1.large` | Network optimised — large |
| `n1.xlarge` | Network optimised — xlarge |
| `n1.2xlarge` | Network optimised — 2xlarge |
| `n1.4xlarge` | Network optimised — 4xlarge |
| `n1.8xlarge` | Network optimised — 8xlarge |
| `rt1.micro` | Real-time — micro |
| `rt1.small` | Real-time — small |
| `rt1.medium` | Real-time — medium |
| `rt1.large` | Real-time — large |
| `rt1.xlarge` | Real-time — xlarge |
| `rt1.2xlarge` | Real-time — 2xlarge |
| `rt1.4xlarge` | Real-time — 4xlarge |
| `rt1.8xlarge` | Real-time — 8xlarge |
| `u1.nano` | Ultra — nano |
| `u1.micro` | Ultra — micro |
| `u1.small` | Ultra — small |
| `u1.medium` | Ultra — medium |
| `u1.2xmedium` | Ultra — 2xmedium |
| `u1.large` | Ultra — large |
| `u1.xlarge` | Ultra — xlarge |
| `u1.2xlarge` | Ultra — 2xlarge |
| `u1.4xlarge` | Ultra — 4xlarge |
| `u1.8xlarge` | Ultra — 8xlarge |

## Examples

### Minimal

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachine
metadata:
  name: my-vm
spec:
  parameters:
    flavour: rhel9
    instanceType: o1.small
```

### Private VM with SSH Key

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachine
metadata:
  name: my-vm
spec:
  parameters:
    flavour: rhel9
    instanceType: o1.medium
    storageSize: medium
    connection: private
    sshPublicKey:
      data: <base64-encoded-ssh-public-key>
```

### Public VM with Cloud-Init

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachine
metadata:
  name: my-vm
spec:
  parameters:
    flavour: rhel10
    instanceType: o1.medium
    storageSize: large
    connection: public
    sshPublicKey:
      data: <base64-encoded-ssh-public-key>
    cloudInit:
      userData: |
        #cloud-config
        packages:
          - git
          - curl
```

## How-to Guide

[Provision a Virtual Machine](../../how-to-guides/user/provision-virtual-machine.md)
