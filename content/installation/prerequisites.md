# Prerequisites

Requirements for installing Stakater Cloud Orchestrator on OpenShift.

## Cluster Requirements

- **Platform**: Red Hat OpenShift 4.14+ (`ocp` is the only currently supported platform)
- **Deployment**: Bare metal (production-supported)
- **Access**: Cluster administrator privileges
- **Nodes**: Minimum 6 worker nodes recommended for production
- **Storage**: Persistent storage provisioner configured (any CSI driver)

### Compute Resources

Recommended minimum capacity for the SCO platform:

| Role | Count | vCPU | RAM |
|------|-------|------|-----|
| Control plane nodes | 3 | 4 | 16 GB |
| Worker nodes | 6+ | 16 | 64 GB |

Storage: 500 GB+ available across workers.

### Hosting Variant Requirements

This guide targets the **`hosting`** variant, so the cluster must be able to host other clusters and run the platform's control plane. Have these ready before you install:

| Capability | Required | Notes |
|------------|:--------:|-------|
| HyperShift operator | ✅ | The hosting cluster runs HyperShift to provision and host spoke clusters. |
| Block + object storage (e.g. ODF) | ✅ | Backs platform databases, object storage, and HostedCluster etcd; must be healthy before install. |
| Identity provider (Keycloak or Azure AD) | ✅ | Reachable from the cluster — SCO provisions realms/clients against it. |
| Secrets backend (Vault / OpenBao) | ✅ | Reachable from the cluster — used for platform and OIDC secrets. |
| OpenShift Virtualization | — | Only if you will run VM workloads on hosted clusters. |

## Tool Requirements

### KubeStack+ CLI (`ksp`)

Stakater provides the `ksp` CLI together with your registry credentials when you
engage — request both from **[sales@stakater.com](mailto:sales@stakater.com)** (see
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

SCO's platform components — Crossplane configuration packages, composition functions, and Helm charts — are published to **Stakater's private registry** (`ghcr.io/stakater`). Installing SCO therefore **requires Stakater registry credentials**.

!!! important "Request your registry credentials"
    Email **[sales@stakater.com](mailto:sales@stakater.com)** to request access. You will receive a username and a token with read access to `ghcr.io/stakater`. You supply these to `ksp up` through a registry-secret file (`--registry-secret`) — see [OpenShift Installation](openshift.md).

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
- [ ] Stakater registry credentials obtained (from sales@stakater.com)
- [ ] `KubeStackConfig` claim file prepared
- [ ] `KubeStackPlus` claim file prepared
- [ ] Minimum compute and storage capacity available

## What's Next?

- [OpenShift Installation](openshift.md) - Run `ksp up` to install SCO
