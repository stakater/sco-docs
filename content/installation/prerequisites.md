# Prerequisites

Requirements for installing Stakater Cloud Orchestrator on OpenShift.

## Cluster Requirements

- **Platform**: Red Hat OpenShift 4.14+ (`ocp` is the only currently supported platform)
- **Deployment**: Bare metal (production-supported)
- **Access**: Cluster administrator privileges
- **Nodes**: Minimum 6 worker nodes recommended for production
- **Storage**: Depends on the variant — see [Which variant are you installing?](#which-variant-are-you-installing) below

### Which variant are you installing?

The two supported variants make **opposite assumptions about storage and load balancing**, and getting this backwards is the most common cause of a failed installation.

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

Stakater provides the `ksp` CLI release archives when you engage — request them
from `sales@stakater.com` (see [Registry Access](#registry-access) below). Builds
are available for **Linux x86_64**, **macOS arm64** (Apple Silicon), and
**Windows x86_64**.

On Linux x86_64 you can also copy the binary out of the public CLI image, without
waiting for the archive:

```bash
podman create --name ksp ghcr.io/stakater/kubestackplus-cli:v2.8.1
podman cp ksp:/usr/local/bin/ksp ./ksp
podman rm ksp
sudo mv ./ksp /usr/local/bin/ksp
```

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

#### Supported CLI versions

Each `ksp` release installs one specific platform release, and only some of those are
available from the customer distribution registry. Use a supported version:

| `ksp` version | Customer install |
|---|---|
| **v2.8.1** (recommended), v2.8.0, v2.7.1 | Supported for the brownfield (`scobasic`) variant |
| v2.6.0, v2.7.0 | **Not supported** — the platform release they install is not in the distribution registry, and `ksp up` fails partway through |
| v2.5.0 and earlier | Install an older platform release. Use v2.8.1 for new installs |

A newer `ksp` is not automatically supported: check this table, or ask Stakater, before
you upgrade the CLI.

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

Access is tied to a GitHub account. You log in with your **own** GitHub username and a token you create yourself — Stakater does not issue a shared username or password.

1. Email `sales@stakater.com` (or your Stakater contact) to request access, and include the **GitHub username** that will pull the platform.
1. Accept the GitHub invitation you receive. Pull access starts once it is accepted.
1. On that GitHub account, create a **classic** personal access token with only the `read:packages` scope (**Settings → Developer settings → Personal access tokens → Tokens (classic)**). Fine-grained tokens do not work for this registry.
1. Check that it works before you install:

    ```bash
    echo "$TOKEN" | helm registry login ghcr.io -u <your-github-username> --password-stdin
    helm pull oci://ghcr.io/stakater/registry/charts/crossplane-package-ksp-system --version <version>
    ```

You supply the username and token to `ksp up` through a registry-secret file with `profile: distribution` set (`--registry-secret`) — see [OpenShift Installation](openshift.md). The token is yours: rotate or revoke it on GitHub whenever you need to.

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
- [ ] Registry access granted to your GitHub account, and a `read:packages` token created
- [ ] `KubeStackConfig` claim file prepared
- [ ] `KubeStackPlus` claim file prepared
- [ ] Minimum compute and storage capacity available

## What's Next?

- [OpenShift Installation](openshift.md) - Run `ksp up` to install SCO
