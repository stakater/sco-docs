# Prerequisites

Requirements for installing Stakater Cloud Orchestrator on OpenShift.

## Cluster Requirements

- **Platform**: Red Hat OpenShift 4.14+
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

### Optional OpenShift Capabilities

| Capability | Required for |
|------------|-------------|
| OpenShift Virtualization | VM workloads |
| Hypershift operator | Hosted OpenShift cluster provisioning |

## Tool Requirements

### KubeStack+ CLI (`ksp`)

Download the latest release from GitHub:

```bash
wget https://github.com/stakater-ab/kubestackplus-cli/releases/latest/download/ksp-linux-amd64
chmod +x ksp-linux-amd64
sudo mv ksp-linux-amd64 /usr/local/bin/ksp

ksp version
```

On macOS, remove the quarantine attribute after downloading:

```bash
xattr -d com.apple.quarantine ~/Downloads/ksp
```

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

SCO components are pulled from:

- **Public registries**: docker.io, Quay.io, ghcr.io
- **Red Hat registry**: For OpenShift platform components
- **Stakater registry**: For SCO proprietary components (credentials provided by Stakater)

If using a private registry mirror, prepare a registry secret file for the `--registry-secret` flag (see [Installation](openshift.md)).

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
- [ ] Registry credentials available (if using private registry)
- [ ] `KubeStackConfig` claim file prepared
- [ ] `KubeStackPlus` claim file prepared
- [ ] Minimum compute and storage capacity available

## What's Next?

- [OpenShift Installation](openshift.md) - Run `ksp up` to install SCO
