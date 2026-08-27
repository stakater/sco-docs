# Prerequisites

Requirements for installing Stakater Cloud Orchestrator on OpenShift.

## Cluster Requirements

- **Platform**: Red Hat OpenShift 4.14+ (`ocp` is the only currently supported platform)
- **Deployment**: Bare metal (production-supported)
- **Access**: Cluster administrator privileges
- **Nodes**: Minimum 6 worker nodes recommended for production
- **Storage**: Depends on the variant — see [Which variant are you installing?](#which-variant-are-you-installing) below

### Which variant are you installing?

The two supported variants make **opposite assumptions about storage and load balancing**, and getting this backwards is the most common cause of a failed install.

| | `hosting` | `scobasic` |
|---|---|---|
| Intended for | A cluster you dedicate to SCO, installed from scratch | An existing cluster of yours, which SCO joins |
| Storage | **SCO installs it** (ODF). Provide worker nodes with unused raw disks. | **You provide it.** SCO installs no storage layer — an RWO StorageClass must already work. |
| Load balancing | Provided by the platform layer SCO installs | **You provide it.** On bare metal, install and configure MetalLB *before* installing SCO. |
| Cluster management, Hypershift | Installed | Not installed |

!!! warning "`scobasic` does not install storage or load balancing"
    If you are installing `scobasic`, the requirements below that describe SCO
    deploying ODF do **not** apply to you. Your cluster must already provide a
    working RWO StorageClass and working `LoadBalancer` Services. See
    [`scobasic` Installation](scobasic.md) for the full requirements.

### Compute Resources

Recommended minimum capacity for the SCO platform on the **`hosting`** variant
(for `scobasic`, see [its own sizing](scobasic.md#capacity) — it is
considerably smaller):

| Role | Count | vCPU | RAM |
|------|-------|------|-----|
| Control plane nodes | 3 | 4 | 16 GB |
| Worker nodes | 6+ | 16 | 64 GB |

Storage: 500 GB+ available across workers.

### What the `hosting` variant installs

`hosting` is the **full greenfield deployment**. Starting from a base OpenShift cluster, `ksp up` brings up the **entire stack** — you do **not** pre-install these components yourself:

- **Platform foundation** — GitOps (OpenShift GitOps / Argo CD), Crossplane (operator, providers, functions), storage (ODF), cluster management (ACM), Hypershift, and the supporting identity and secrets services.
- **SCO layer** — the Stakater Cloud control plane and all the user-facing cloud APIs (`*.cloud.stakater.com`) your tenants consume.

The only things you provide up front are a base cluster with enough capacity (see above), wildcard DNS/TLS, and the `ksp` CLI plus registry credentials. `ksp up` installs and wires everything else.

## Tool Requirements

### KubeStack+ CLI (`ksp`)

Stakater provides the `ksp` CLI together with your registry credentials when you
engage — request both from `sales@stakater.com` (see
[Registry Access](#registry-access) below). Builds are available for
**Linux x86_64**, **macOS arm64** (Apple Silicon), and **Windows x86_64**.

Once you have the release archive for your platform, extract the `ksp` binary and put
it on your `PATH`:

```bash
# Linux (x86_64)
tar -xzf ksp_linux_x86_64.tar.gz
sudo mv ksp_linux_x86_64/bin/linux_amd64/ksp /usr/local/bin/ksp

# macOS (Apple Silicon)
tar -xzf ksp_darwin_arm64.tar.gz
sudo mv ksp_darwin_arm64/bin/darwin_arm64/ksp /usr/local/bin/ksp
xattr -d com.apple.quarantine /usr/local/bin/ksp   # clear the Gatekeeper quarantine flag

# Verify
ksp version
```

On Windows, extract the `ksp_windows_x86_64.zip` archive and add the folder containing
`ksp.exe` to your `PATH`.

### oc / kubectl

```bash
# Verify oc is installed and authenticated
oc version
oc whoami
```

## Network Requirements

- **DNS**: Wildcard DNS configured for cluster ingress (e.g., `*.apps.cluster.example.com`)
- **TLS**: Wildcard TLS certificate for ingress routes
- **Connectivity**: Outbound access to container registries (docker.io, Quay.io, ghcr.io)

## Registry Access

SCO platform components — packages, functions, Helm charts, and container images — are published to **Stakater's customer distribution registry** (`ghcr.io/stakater/registry`). It carries only released versions blessed for customer use. Installing SCO therefore **requires Stakater registry credentials**.

!!! important "Request your registry credentials"
    Email `sales@stakater.com` to request access. You will receive a username and a token with read access to the distribution registry. You supply these to `ksp up` through a registry-secret file with `profile: distribution` set (`--registry-secret`) — see [OpenShift Installation](openshift.md).

The cluster also needs outbound connectivity to the public registries SCO depends on: docker.io, Quay.io, ghcr.io, and the Red Hat registry (for OpenShift platform components).

## Configuration Claim Files

Before running `ksp up` you need two claim files prepared:

1. **`KubeStackConfig`** — Platform configuration (name, location, domain)
1. **`KubeStackPlus`** — SCO platform deployment (variant, platform)

See [OpenShift Installation](openshift.md) for example claim files.

## Pre-Installation Checklist

- [ ] OpenShift 4.14+ cluster on bare metal
- [ ] Cluster administrator access
- [ ] `ksp` CLI installed and on PATH
- [ ] `oc` authenticated to the cluster
- [ ] Wildcard DNS configured
- [ ] Wildcard TLS certificate ready
- [ ] Stakater registry credentials obtained (from `sales@stakater.com`)
- [ ] `KubeStackConfig` claim file prepared
- [ ] `KubeStackPlus` claim file prepared
- [ ] Minimum compute and storage capacity available

## What's Next?

- [OpenShift Installation](openshift.md) - Run `ksp up` to install SCO
