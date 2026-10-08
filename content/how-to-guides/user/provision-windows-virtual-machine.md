# How to Provision a Windows Virtual Machine

Learn how to provision a Windows virtual machine in your project and connect to it with Remote Desktop (RDP) over your organisation's Mesh.

Emma, a developer at ACME Corp, needs a Windows Server machine to test a legacy .NET application. She doesn't want an RDP port on the internet, so she keeps the VM private, advertises it on her organisation's Mesh, and connects from her laptop.

## Prerequisites

- A [Project](create-project.md) already created
- The `windowsvirtualmachine.compute.cloud.stakater.com` API available
- A [Mesh](create-mesh.md) in your organisation, already Ready, with your laptop [enrolled](create-mesh.md#step-5-enrol-a-device)
- `kubectl` configured with your project kubeconfig
- A Windows installation ISO that you are licensed to use, reachable over HTTP(S) — for example a Windows Server evaluation ISO
- An RDP client (Windows App, Remmina, `xfreerdp`, or the built-in Remote Desktop Connection)
- A [Vault](create-vault.md) in your organisation, if you want the platform to generate and store the Administrator password (see [Step 3](#step-3-define-a-windowsvirtualmachine-claim))

## What Gets Created

When you create a WindowsVirtualMachine claim, the platform provisions:

- A **virtual machine** with an empty root disk, UEFI firmware with Secure Boot, and a virtual TPM
- A **copy of the installation ISO** attached as a CD-ROM for the first boot
- An **unattended Windows installation** (unless you supply your own answer file) that enables Remote Desktop and installs the guest drivers
- A **Mesh route** for the VM, so enrolled devices can reach it on its private address
- With a Vault in your organisation: a randomly generated **Administrator password**, stored in the Vault

The root disk starts empty — Windows is installed from the ISO you provide, so the VM's `flavour` records which Windows release you are installing; it does not select a ready-made image.

## Step 1: Choose a Size

Windows VMs use their own size catalogue. Ask your organisation administrator for the sizes available to you; typical values are:

| Instance Type | Profile |
|---------------|---------|
| `u1.nano` | 1 vCPU, 512 Mi |
| `u1.micro` | 1 vCPU, 1 Gi |
| `u1.small` | 1 vCPU, 2 Gi |
| `o1.small` | 2 vCPU, 4 Gi |
| `o1.medium` | 2 vCPU, 8 Gi |
| `o1.large` | 4 vCPU, 16 Gi |

!!! note
    Windows Server with Desktop Experience is slow and cramped below 2 vCPU and 4 Gi. Use `o1.small` or larger for anything you intend to log in to and work on. An instance type that is not in your catalogue is rejected with an `InvalidInstanceType` condition on the claim.

## Step 2: Choose the Installation Media

Windows is installed from an ISO, and there are two ways to give the platform one.

**Option A — an HTTP URL (simplest).** The platform downloads the ISO into a volume dedicated to this VM. Set `installationSource.type: http` and give the URL and a size at least as large as the ISO.

**Option B — a shared media volume.** Import the ISO once as a `VirtualMachineVolume` with `role: media`, then reference it from as many VMs as you like:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachineVolume
metadata:
  name: win2k25-media
spec:
  parameters:
    role: media
    storageSize: small
    source:
      type: http
      http:
        url: https://example.org/windows-server-2025.iso
```

```bash
kubectl apply -f media.yaml
kubectl get virtualmachinevolume win2k25-media
```

!!! warning
    Microsoft's installation ISOs normally show *"Press any key to boot from CD or DVD…"* for a few seconds. A VM nobody is watching times out of that prompt and sits at an idle firmware screen even though the claim reports `Running`. For a hands-off install, use media that has the prompt removed. If you use an unmodified ISO, open the VM console as soon as the VM starts and press a key (see [Troubleshooting](#troubleshooting)).

## Step 3: Define a WindowsVirtualMachine Claim

Create a file named `windows-vm.yaml`:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: WindowsVirtualMachine
metadata:
  name: my-windows-vm
spec:
  parameters:
    flavour: win2k25
    instanceType: o1.medium
    storageSize: medium
    connection: private
    meshRoute:
      enabled: true
    installationSource:
      type: volume
      name: win2k25-media
```

To download the ISO for this VM alone instead of using a shared volume, replace `installationSource` with:

```yaml
    installationSource:
      type: http
      url: https://example.org/windows-server-2025.iso
      size: 10Gi
```

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `parameters.flavour` | — (required) | Windows release being installed: `win2k19`, `win2k22` or `win2k25` |
| `parameters.instanceType` | — (required) | VM size from your organisation's Windows catalogue (see [Step 1](#step-1-choose-a-size)) |
| `parameters.storageSize` | `medium` | Root disk size from your organisation's catalogue |
| `parameters.connection` | `private` | `private` creates no external endpoint; `public` creates an external RDP endpoint on port 3389 |
| `parameters.meshRoute.enabled` | `false` | Advertise the VM on your organisation's Mesh so enrolled devices can reach it |
| `parameters.installationSource.type` | `volume` | `volume` attaches a media `VirtualMachineVolume`; `http` downloads an ISO for this VM |
| `parameters.installationSource.name` | — | Name of the media volume (`type: volume`) |
| `parameters.installationSource.url` | — | ISO URL (`type: http`) |
| `parameters.installationSource.size` | — | Storage for the downloaded ISO (`type: http`); at least the ISO's size |
| `parameters.sysprep` | — | Your own Windows answer files — see [Use Your Own Answer File](#use-your-own-answer-file) |
| `parameters.additionalDisks` | — | Extra disks to attach: persistent (an existing `VirtualMachineVolume`), ephemeral scratch, or read-only container disks |

!!! tip
    Prefer `connection: private` with `meshRoute.enabled: true`. Remote Desktop is a frequent target for attacks; `connection: public` exposes it to the internet and should only be used for short-lived machines you will harden yourself.

### The Default Installation

If you attach installation media and do not supply a `sysprep` of your own, the platform installs Windows without any prompts:

- Installs **Standard (Desktop Experience)**
- Enables **Remote Desktop** with Network Level Authentication, and opens its firewall rule
- Installs the **virtio guest drivers and guest agent** (the VM's network adapter needs them)
- Sets a **random password** for the local `Administrator` account

When your organisation has a Vault, the password is stored there and the claim tells you where (Step 6). Without a Vault the VM still installs, but nobody is given the password — in that case supply your own answer file.

## Step 4: Apply the Claim

```bash
kubectl apply -f windows-vm.yaml
```

## Step 5: Wait for the Installation

```bash
kubectl get windowsvirtualmachine my-windows-vm
```

```text
NAME             SYNCED   READY   AGE
my-windows-vm    True     True    9m
```

`READY: True` and a `Running` VM status mean only that the virtual machine has *started* — not that Windows has finished installing. Watch the disks and the guest address instead:

```bash
kubectl get windowsvirtualmachine my-windows-vm \
  -o jsonpath='{.status.vm.printableStatus}{"\n"}{.status.vm.dataVolumes}{"\n"}{.status.vm.internalIP}{"\n"}'
```

1. The ISO downloads first (the data volume phase moves through `ImportInProgress` to `Succeeded`).
2. The VM boots the installer and installs Windows. Allow roughly **10–15 minutes** on `o1.small` or larger.
3. When Windows has installed the guest tools and reports its address, `status.vm.internalIP` is populated. That is the address you connect to.

!!! note
    `status.vm.internalIP` stays empty until the guest reports an address, and it is never set when `meshRoute.enabled` is `false`. An empty value after 20 minutes means Windows has not finished installing — see [Troubleshooting](#troubleshooting).

## Step 6: Get the Administrator Password

With the default installation, the claim status names where the password is stored:

```bash
kubectl get windowsvirtualmachine my-windows-vm -o jsonpath='{.status.adminCredentials}'
```

```text
{"delivered":true,"secretPath":"projects/my-project/vms/my-windows-vm","secretStore":"…","username":"Administrator"}
```

Wait for `delivered` to be `true`, then read the `username` and `password` properties from that path in your organisation's [Vault](create-vault.md). Log in to the Vault first, then read the entry:

```bash
bao kv get -mount=stakater projects/my-project/vms/my-windows-vm
```

If `delivered` is `false`, the `message` field says why — most often, the organisation has no Vault.

## Step 7: Connect with Remote Desktop

1. Make sure your laptop is connected to the Mesh:

    ```bash
    netbird status
    ```

2. Get the VM's address:

    ```bash
    kubectl get windowsvirtualmachine my-windows-vm -o jsonpath='{.status.vm.internalIP}'
    ```

3. Check that the RDP port is reachable:

    ```bash
    nc -vz <internal-ip> 3389
    ```

4. Open your RDP client, connect to `<internal-ip>`, and sign in as `Administrator` with the password from Step 6.

!!! note
    Don't use `ping` to test the connection. Windows Firewall blocks ping by default, so it times out even when RDP works. Test port 3389 instead.

RDP over the Mesh is available to members of the organisation groups that have an administrative or compute role on the project. If `nc` cannot connect while the VM reports an address, ask your organisation administrator to check that you are in one of those groups.

## Use Your Own Answer File

To control the installation yourself — a different edition, a product key, a domain join, or a fixed password — supply Windows answer files in `sysprep` instead of relying on the default:

```yaml
spec:
  parameters:
    sysprep:
      autounattend: <base64-encoded-autounattend.xml>
```

Encode the file with:

```bash
base64 -w 0 autounattend.xml
```

Your answer file must itself enable Remote Desktop, install the [virtio-win guest drivers](https://github.com/virtio-win/virtio-win-pkg-scripts), and set the Administrator password. The platform does not add any of these for you when you supply your own.

| Field | Description |
|-------|-------------|
| `sysprep.autounattend` | Base64-encoded `autounattend.xml`, used during Windows Setup |
| `sysprep.unattend` | Base64-encoded `unattend.xml`, used after installation |
| `sysprep.secretPath` | Path to an answer file stored in your organisation's Vault, under your project's area (requires a Vault) |

`autounattend`/`unattend` and `secretPath` are mutually exclusive.

!!! warning
    Anything you put in `sysprep.autounattend` or `sysprep.unattend` is stored in the claim and is **readable by anyone who can read the claim**. Base64 is an encoding, not encryption. An answer file usually contains an Administrator password or product key — if it does, store it in your Vault and use `sysprep.secretPath` instead.

### Licensing

The claim has no licence-key field. Evaluation media needs no key (it is time-limited). For retail or volume-licensed media, put the key in your own answer file (`<ProductKey>` in the `Microsoft-Windows-Setup` component) or activate after installation with `slmgr`. Inside the VM, `slmgr /dli` shows the current licence state.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Claim `Running` for 20+ minutes, `status.vm.internalIP` empty | The VM sat at *"Press any key to boot from CD or DVD"* and never started Windows Setup | Open the VM console in the SCO console, restart the VM and press a key at the prompt — or use installation media with the prompt removed |
| `InvalidInstanceType` condition | The size is not in your organisation's Windows catalogue | Pick one of the Windows sizes in [Step 1](#step-1-choose-a-size), or ask your administrator |
| `status.adminCredentials.delivered` is `false` | Your organisation has no Vault | Create a [Vault](create-vault.md), or supply your own answer file |
| `nc` to port 3389 times out, `internalIP` is set | Your laptop is not on the Mesh, or you are not in a group with RDP access to the project | Run `netbird status`; ask your organisation administrator to check your group membership |
| RDP connects, then fails to sign in | Wrong password or user | Use `Administrator` and the password from the Vault; with your own answer file, use the one you set |
| `ping` to the VM times out | Windows Firewall blocks ping | Expected — test port 3389 instead |

## Full Example

A private Windows Server 2025 VM, reachable over the Mesh, installed unattended from a shared media volume:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachineVolume
metadata:
  name: win2k25-media
spec:
  parameters:
    role: media
    storageSize: small
    source:
      type: http
      http:
        url: https://example.org/windows-server-2025.iso
---
apiVersion: compute.cloud.stakater.com/v1
kind: WindowsVirtualMachine
metadata:
  name: my-windows-vm
spec:
  parameters:
    flavour: win2k25
    instanceType: o1.medium
    storageSize: medium
    connection: private
    meshRoute:
      enabled: true
    installationSource:
      type: volume
      name: win2k25-media
```

## What's Next?

- [Provision a Linux Virtual Machine](provision-virtual-machine.md) - Provision a Linux VM and connect over SSH
- [Create a Mesh](create-mesh.md) - Set up the private network used to reach the VM
- [Create a Vault](create-vault.md) - Store the generated Administrator password
- [One Identity Across Your Organisation](../../cloud-user-guide/authentication/organisation-identity.md) - Mesh enrolment caveats
