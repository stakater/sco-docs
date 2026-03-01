# Virtual Machine (Infrastructure)

Low-level infrastructure API for provisioning a virtual machine with explicit control over CPU, memory, storage, networking, cloud-init, and SSH configuration.

!!! note
    This is a private infrastructure API intended for platform engineers. Cloud users should use the [Virtual Machine](../public-apis/virtual-machine.md) public API instead.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `infrastructure.stakater.com` |
| **Version** | `v1` |
| **Kind** | `VirtualMachine` |
| **Scope** | Namespaced |

## Spec Parameters

All parameters are nested under `spec.parameters`.

### Data Source

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `dataSource.name` | `string` | `rhel9` | OS image data source name |
| `dataSource.namespace` | `string` | `openshift-virtualization-os-images` | Namespace of the data source |

### Storage

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `storage.size` | `string` | `30Gi` | Root disk size |
| `storage.storageClassName` | `string` | — | Storage class for additional disks |

### Additional Disks

`additionalDisks` is an array. Each entry:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `string` | — | **Required.** Disk name |
| `size` | `string` | — | **Required.** Disk size (e.g., `30Gi`) |
| `storageClassName` | `string` | — | Storage class for this disk |
| `accessModes` | `string[]` | `["ReadWriteMany"]` | Access modes |
| `volumeMode` | `string` | `Block` | Volume mode (`Block`, `Filesystem`) |
| `bus` | `string` | `virtio` | Disk bus type |
| `sourceType` | `string` | `blank` | Source type (`blank`, `pvc`, `http`, `registry`) |

### CPU

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `cpu.cores` | `integer` | `1` | Number of CPU cores |
| `cpu.sockets` | `integer` | `1` | Number of CPU sockets |
| `cpu.threads` | `integer` | `1` | Threads per core |

### Memory

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `memory.guest` | `string` | `2Gi` | Guest memory size (e.g., `4Gi`) |

### Networks

`networks` is an array. Each entry:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `string` | — | **Required.** Network name |
| `type` | `string` | — | Network type (`pod`, `multus`, etc.) |
| `interfaceModel` | `string` | `virtio` | Network interface model |
| `bindingName` | `string` | `l2bridge` | Network binding name |
| `multus.networkName` | `string` | — | Name of the NetworkAttachmentDefinition (Multus only) |

### Cloud-Init

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `cloudInit.user` | `string` | `cloud-user` | Default user for cloud-init |
| `cloudInit.password` | `string` | — | Password for the default user |
| `cloudInit.passwordExpire` | `boolean` | `false` | Whether the password should expire |
| `cloudInit.userData` | `string` | — | Custom cloud-init userData (overrides `user`/`password`) |

### SSH Public Key

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `sshPublicKey.data` | `string` | — | Inline SSH public key (raw or base64). Creates a Secret. |
| `sshPublicKey.secretName` | `string` | — | Name of an existing Secret containing the SSH public key |
| `sshPublicKey.propagationMethod` | `string` | `noCloud` | Key propagation method (`noCloud`, `configDrive`, `qemuGuestAgent`) |

### Run Strategy and Behaviour

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `runStrategy` | `string` | `RerunOnFailure` | VM run strategy (`Always`, `RerunOnFailure`, `Manual`, `Halted`) |
| `terminationGracePeriodSeconds` | `integer` | `180` | Grace period for VM termination |
| `enableDynamicCredentials` | `boolean` | `false` | Enable dynamic credentials support |

### Firmware

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `firmware.efi` | `boolean` | `true` | Enable EFI boot |
| `firmware.secureBoot` | `boolean` | `true` | Enable Secure Boot (requires SMM) |

### Service (External Access)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `service.enabled` | `boolean` | `false` | Create a LoadBalancer Service for external VM access |
| `service.port` | `integer` | `22000` | External port for the Service |
| `service.targetPort` | `integer` | `22` | Target port on the VM |

### Scheduling

| Field | Type | Description |
|-------|------|-------------|
| `nodeSelector` | `object` | Key/value node selector labels for scheduling |
| `additionalLabels` | `object` | Additional labels to apply to the VM resource |
| `additionalAnnotations` | `object` | Additional annotations to apply to the VM resource |

## Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.vm.printableStatus` | `string` | Human-readable VM status (e.g., `Running`, `Stopped`, `Provisioning`) |
| `status.vm.ready` | `boolean` | Whether the VM is running and ready |
| `status.vm.created` | `boolean` | Whether the VM has been created |
| `status.vm.cpuCores` | `integer` | Number of CPU cores |
| `status.vm.memory` | `string` | Memory size |
| `status.vm.serviceIP` | `string` | LoadBalancer IP (if Service enabled) |
| `status.vm.serviceHostname` | `string` | LoadBalancer hostname (if Service enabled) |
| `status.vm.conditions` | `array` | VM conditions |

## Examples

### Minimal

```yaml
apiVersion: infrastructure.stakater.com/v1
kind: VirtualMachine
metadata:
  name: basic-vm
spec:
  parameters:
    dataSource:
      name: rhel9
      namespace: openshift-virtualization-os-images
    storage:
      size: 30Gi
      storageClassName: ocs-storagecluster-ceph-rbd
    cpu:
      cores: 2
      sockets: 1
      threads: 1
    memory:
      guest: 4Gi
    networks:
      - name: default
        type: pod
        interfaceModel: virtio
        bindingName: l2bridge
```

### Full

```yaml
apiVersion: infrastructure.stakater.com/v1
kind: VirtualMachine
metadata:
  name: advanced-vm
spec:
  parameters:
    dataSource:
      name: rhel9
      namespace: openshift-virtualization-os-images
    storage:
      size: 50Gi
      storageClassName: ocs-storagecluster-ceph-rbd
    additionalDisks:
      - name: data-disk
        size: 100Gi
        storageClassName: ocs-storagecluster-ceph-rbd
        accessModes:
          - ReadWriteMany
        volumeMode: Block
        bus: virtio
        sourceType: blank
    cpu:
      cores: 4
      sockets: 1
      threads: 2
    memory:
      guest: 16Gi
    networks:
      - name: default
        type: pod
        interfaceModel: virtio
        bindingName: l2bridge
    sshPublicKey:
      data: <base64-encoded-ssh-public-key>
      propagationMethod: noCloud
    cloudInit:
      userData: |
        #cloud-config
        packages:
          - git
    runStrategy: RerunOnFailure
    firmware:
      efi: true
      secureBoot: true
    service:
      enabled: true
      port: 22000
      targetPort: 22
    nodeSelector:
      node-role.kubernetes.io/worker: ""
```
