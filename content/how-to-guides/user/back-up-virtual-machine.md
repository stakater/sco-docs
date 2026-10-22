# How to Back Up and Snapshot a Virtual Machine

Learn when to use a snapshot, when to use a backup, and how to restore a virtual machine from either.

Emma, a developer at ACME Corp, is about to upgrade the software on her development VM. She wants a quick way to roll back if the upgrade goes wrong. She also wants nightly copies of the VM stored outside the platform so she can recover from a bigger problem.

## Snapshot or Backup?

Both capture a virtual machine and its disks, and both work for Linux and Windows virtual machines. They solve different problems.

| | Snapshot | Backup |
|---|----------|--------|
| **Claim** | `VirtualMachineSnapshot` | `VirtualMachineBackup` |
| **Use it for** | A quick restore point before a risky change, such as an upgrade or a configuration change | Regular, long-term protection and recovery |
| **When it runs** | Once, when you create the claim | On a schedule you define |
| **Where it is stored** | On the platform, with the virtual machine's storage | In an S3 bucket: one of your platform buckets or your own S3-compatible storage |
| **How long it is kept** | Until you delete the claim | For a retention period you set, then deleted automatically |
| **Survives loss of the platform storage** | No | Yes, when stored in your own external storage |
| **Restore with** | `VirtualMachineSnapshotRestore` | `VirtualMachineBackupRestore` |

!!! tip
    Use both. Take a snapshot before a change you may want to undo, and keep a backup schedule running for everything else. A snapshot is not a substitute for a backup.

## Prerequisites

- A [Project](create-project.md) already created
- A running virtual machine. See [How to Provision a Virtual Machine](provision-virtual-machine.md)
- The `virtualmachinesnapshot.compute.cloud.stakater.com` and `virtualmachinesnapshotrestore.compute.cloud.stakater.com` APIs available (for snapshots)
- The `virtualmachinebackup.compute.cloud.stakater.com` and `virtualmachinebackuprestore.compute.cloud.stakater.com` APIs available (for backups)
- `kubectl` configured with your project kubeconfig

## Snapshots

### Step 1: Create a Snapshot

Create a file named `snapshot.yaml`:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachineSnapshot
metadata:
  name: my-dev-vm-before-upgrade
spec:
  parameters:
    vmRef:
      name: my-dev-vm
```

```bash
kubectl apply -f snapshot.yaml
```

The virtual machine must be in the same project as the snapshot. For a Windows virtual machine, add `kind: WindowsVirtualMachine` under `vmRef`.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `parameters.vmRef.name` | — (required) | Name of the virtual machine to snapshot |
| `parameters.vmRef.kind` | `VirtualMachine` | `VirtualMachine` or `WindowsVirtualMachine` |
| `parameters.deletionPolicy` | `delete` | What happens to the stored snapshot data when you delete the claim: `delete` removes it, `retain` keeps it |
| `parameters.failureDeadline` | `5m` | How long to wait for the snapshot to be ready before marking it failed. Set to empty to disable the deadline |

### Step 2: Check the Snapshot

```bash
kubectl get virtualmachinesnapshot my-dev-vm-before-upgrade
```

The `status.phase` field reports one of `WaitingForVirtualMachine`, `InProgress`, `Succeeded` or `Failed`. `status.message` explains a failure. The snapshot is ready to use when `status.ready` is `true`.

### Step 3: Restore from a Snapshot

Create a file named `snapshot-restore.yaml`:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachineSnapshotRestore
metadata:
  name: my-dev-vm-rollback
spec:
  parameters:
    vmRef:
      name: my-dev-vm
    snapshotRef:
      name: my-dev-vm-before-upgrade
```

```bash
kubectl apply -f snapshot-restore.yaml
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `parameters.vmRef.name` | — (required) | Virtual machine to restore into |
| `parameters.snapshotRef.name` | — (required) | Snapshot to restore from |
| `parameters.targetReadinessPolicy` | `StopTarget` | How a running virtual machine is handled: `FailImmediate`, `WaitGracePeriod`, `WaitEventually` or `StopTarget`. The default stops the virtual machine so it can be restored |
| `parameters.volumeRestorePolicy` | `InPlace` | `InPlace` reuses the existing disk names (recommended). `RandomizeNames` creates new disk names on each restore |

!!! note
    Restoring replaces the current state of the virtual machine's disks with the state in the snapshot. Anything written since the snapshot was taken is lost.

Check progress with `kubectl get virtualmachinesnapshotrestore my-dev-vm-rollback`. `status.phase` moves through `WaitingForVirtualMachine`, `WaitingForSnapshot` and `InProgress` to `Complete`.

## Backups

A backup claim creates a schedule. Each run captures only the virtual machine you name and the disks attached to it. Other virtual machines in your project are not included.

### Step 1: Choose Where Backups Are Stored

| Destination | Use it when |
|-------------|-------------|
| `platform` | You want to store backups in one of your own [S3 buckets](create-s3-bucket.md) on the platform. You name the bucket; there are no credentials to manage |
| `external` | You want to store backups in your own S3-compatible storage. You supply its address and the location of its credentials |

### Step 2: Create a Backup Schedule

Using a platform bucket:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachineBackup
metadata:
  name: my-dev-vm-nightly
spec:
  parameters:
    vmRef:
      name: my-dev-vm
    schedule: "0 3 * * *"
    retention: "168h"
    destination:
      type: platform
      platform:
        bucketRef: my-backup-bucket
```

Using your own S3-compatible storage:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachineBackup
metadata:
  name: my-dev-vm-nightly
spec:
  parameters:
    vmRef:
      name: my-dev-vm
    schedule: "0 3 * * *"
    retention: "168h"
    destination:
      type: external
      external:
        bucket: my-backup-bucket
        endpoint: https://s3.us-east-1.amazonaws.com
        region: us-east-1
        credentials:
          secretPath: my-org/backup-s3
```

```bash
kubectl apply -f backup.yaml
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `parameters.vmRef.name` | — (required) | Name of the virtual machine to back up |
| `parameters.vmRef.kind` | `VirtualMachine` | `VirtualMachine` or `WindowsVirtualMachine` |
| `parameters.schedule` | — (required) | Cron expression for when backups run, for example `0 2 * * *` for daily at 02:00 |
| `parameters.retention` | `720h` | How long each backup is kept before it is deleted automatically, in hours (`720h` is 30 days) |
| `parameters.paused` | `false` | Pause the schedule without deleting it. No new backups are taken while paused |
| `parameters.destination.type` | — (required) | `platform` or `external` |
| `parameters.destination.platform.bucketRef` | — | Name of your bucket, as you named it when you created it |
| `parameters.destination.external.bucket` | — | Bucket name |
| `parameters.destination.external.endpoint` | AWS | S3 endpoint URL. Leave empty to use AWS for the region |
| `parameters.destination.external.region` | `us-east-1` | S3 region |
| `parameters.destination.external.prefix` | — | Optional key prefix inside the bucket |
| `parameters.destination.external.caCert` | — | Optional base64-encoded certificate authority bundle, if your storage uses a private certificate |
| `parameters.destination.external.credentials.secretPath` | — (required for `external`) | Path in your organisation's secret store holding the access key and secret key |
| `parameters.destination.external.credentials.accessKeyProperty` | `aws_access_key_id` | Entry at that path holding the access key ID |
| `parameters.destination.external.credentials.secretKeyProperty` | `aws_secret_access_key` | Entry at that path holding the secret access key |

!!! note
    Store the access key and secret key in your organisation's Vault before you create an `external` backup. The Vault is created for your organisation when the Vault option (`bao.enabled`) is turned on in the organisation's settings. If your organisation has no Vault, ask your organisation administrator to enable it. Then sign in to the Vault as described in [How to Create a Vault](create-vault.md#step-4-log-in) and write the keys at the path you give in `secretPath`, using the entry names `aws_access_key_id` and `aws_secret_access_key` (or your own names via `accessKeyProperty` and `secretKeyProperty`).

### Step 3: Restore from a Backup

Create a file named `backup-restore.yaml`:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachineBackupRestore
metadata:
  name: my-dev-vm-recover
spec:
  parameters:
    backupRef:
      name: my-dev-vm-nightly
    clearMacAddress: true
```

```bash
kubectl apply -f backup-restore.yaml
```

By default the restore uses the most recent backup taken by the schedule.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `parameters.backupRef.name` | — (required) | Name of the backup schedule to restore from |
| `parameters.backupName` | latest | Name of one specific stored backup to restore |
| `parameters.existingPolicy` | `skip` | How to treat resources that already exist: `skip` or `update` |
| `parameters.clearMacAddress` | `false` | Clear the network hardware addresses while restoring. Set to `true` if the original virtual machine still exists, so the two do not clash |
| `parameters.generateNewFirmwareUUID` | `false` | Give the restored virtual machine a new hardware identity, so it is not mistaken for the original |
| `parameters.runStrategy` | as backed up | Power state of the restored virtual machine: `Halted`, `Always` or `RerunOnFailure` |

Check progress with `kubectl get virtualmachinebackuprestore my-dev-vm-recover`. `status.phase` reports `WaitingForBackup`, `New`, `InProgress`, `Completed`, `PartiallyFailed` or `Failed`.

## What's Next?

- [Provision a Virtual Machine](provision-virtual-machine.md) - Create the virtual machine you want to protect
- [Create an S3 Bucket](create-s3-bucket.md) - Create a platform bucket to store backups
- [Create a Vault](create-vault.md) - Sign in to your organisation's Vault to store credentials for your own S3-compatible storage
