# Prerequisites

Requirements and prerequisites for installing Stakater Cloud Orchestrator.

## Infrastructure Requirements

### Kubernetes Cluster

- **Version**: Kubernetes 1.27+ (OpenShift 4.14+ recommended for production)
- **Deployment**: Any Kubernetes distribution (tested on OpenShift bare metal)
- **Access**: Cluster administrator privileges
- **Nodes**: Minimum 6 worker nodes recommended for production
- **Storage**: Persistent storage provisioner configured (any CSI driver)
- **Network**: Network plugin with ingress support (e.g., Calico, Cilium, OVN-Kubernetes)

### Virtual Machine Support (Optional)

For VM workloads (requires KubeVirt or equivalent):

- **On OpenShift**: OpenShift Virtualization operator
- **On vanilla Kubernetes**: KubeVirt installed
- Bare metal nodes with virtualization support (Intel VT-x or AMD-V)
- Sufficient CPU, memory, and storage for VM workloads

### Hosted Cluster Support (Optional)

For Kubernetes-on-Kubernetes clusters:

- **On OpenShift**: hypershift operator
- **On vanilla Kubernetes**: Alternative cluster-API providers

### Compute Resources

Recommended minimum capacity for SCO platform:

- **Control Plane**: 3 nodes, 4 vCPU, 16GB RAM each
- **Worker Nodes**: 6+ nodes, 16 vCPU, 64GB RAM each
- **Storage**: 500GB+ available across workers

## Tool Requirements

### KubeStack+ CLI

Install the `ksp` CLI tool:

```bash
# Download from GitHub releases
wget https://github.com/stakater-ab/kubestackplus-cli/releases/latest/download/ksp-linux-amd64
chmod +x ksp-linux-amd64
sudo mv ksp-linux-amd64 /usr/local/bin/ksp

# Verify installation
ksp version
```

### kubectl

```bash
# Install kubectl for your OS
# https://kubernetes.io/docs/tasks/tools/

# Verify
kubectl version
```

### oc (OpenShift users)

```bash
# Download oc CLI (OpenShift only)
# https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html

# Verify
oc version
```

## Network Requirements

- **DNS**: Wildcard DNS configured for cluster ingress
- **Certificates**: TLS certificates for ingress routes
- **Firewall**: Ports accessible for cluster communication
- **Load Balancer**: If using external load balancing

## Registry Access

SCO requires access to container registries:

- **Public Registries**: docker.io, Quay.io, ghcr.io for open-source components
- **Stakater Registry**: For SCO proprietary components
- **Platform-Specific**: Red Hat registry if using OpenShift features
- **Private Registry**: Optional for custom images

Prepare registry credentials if using private registries:

```bash
# Create registry secret file
cat > registry-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: regcred
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
EOF
```

## Configuration Files

Prepare your SCO configuration claim files:

1. **kubestack-config-package claim** - Platform configuration (networking, DNS, certificates)
1. **kubestack-plus-package claim** - SCO platform components (marketplace, solutions, console)

These files define your SCO deployment configuration and are required by `ksp up`. Example files are provided with the CLI.

## Access Permissions

Ensure you have:

- Cluster administrator access to OpenShift
- Ability to create namespaces and CRDs
- Permissions to install operators
- Access to create routes and ingresses

## Pre-Installation Checklist

- [ ] Kubernetes 1.27+ cluster (OpenShift 4.14+ recommended)
- [ ] VM support installed if using VM workloads (OpenShift Virtualization/KubeVirt)
- [ ] `ksp` CLI tool installed
- [ ] `kubectl` (or `oc`) configured and authenticated
- [ ] DNS wildcard configured
- [ ] TLS certificates ready
- [ ] Registry access configured
- [ ] Configuration claim files prepared
- [ ] Sufficient compute and storage capacity

## What's Next?

- [OpenShift Installation](kubernetes.md) - Install SCO using `ksp up`
- [Configuration](configuration.md) - Post-installation setup
