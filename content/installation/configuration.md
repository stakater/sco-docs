# Platform Configuration

SCO uses a GitOps-native configuration model. Rather than a traditional admin control panel or config file, platform behaviour is controlled through Kubernetes `EnvironmentConfig` resources that are reconciled continuously by Crossplane.

---

## How Configuration Works

When `ksp up` bootstraps the platform, it generates an initial set of `EnvironmentConfig` resources — one per platform component. These EnvironmentConfigs encode the default values for every configurable aspect of each component: resource limits, feature flags, version pins, networking settings, storage configuration, and integration parameters.

Each platform component is backed by an OCI-packaged Helm chart. Crossplane watches the EnvironmentConfigs for that component and, when values change, re-renders the Helm release with the updated configuration. The component reconciles toward the new desired state automatically.

```text
ksp up (initial install)
    ↓
KubeStackConfig + KubeStackPlus claims applied
    ↓
Crossplane generates EnvironmentConfigs (one per component)
    ↓
EnvironmentConfigs hold default values from ksp up inputs
    ↓
Crossplane renders each component from its OCI Helm chart + EnvironmentConfig
    ↓
Platform running with defaults
```

---

## Customising Platform Configuration

To change any default — for example, increasing the replica count for the KCP workspace service, or adjusting default resource quotas for new projects — platform operators create **override EnvironmentConfigs** in their GitOps repository.

An override EnvironmentConfig targets a specific component and declares only the values that differ from the defaults. When the GitOps engine syncs this resource to the cluster, Crossplane merges it with the component's default EnvironmentConfig and re-renders the component.

### Example: Adjusting default project quota

```yaml
apiVersion: apiextensions.crossplane.io/v1beta1
kind: EnvironmentConfig
metadata:
  name: mto-quota-override
  labels:
    kcp/component: mto
    platform/override: "true"
data:
  defaultQuota:
    small:
      requests.cpu: "4"
      requests.memory: 8Gi
      limits.cpu: "8"
      limits.memory: 16Gi
    medium:
      requests.cpu: "8"
      requests.memory: 16Gi
      limits.cpu: "16"
      limits.memory: 32Gi
```

Store this in your GitOps repository. When ArgoCD syncs it to the cluster, Crossplane picks up the change and updates the Multi-Tenant Operator's quota configuration.

### Example: Adjusting component resource limits

```yaml
apiVersion: apiextensions.crossplane.io/v1beta1
kind: EnvironmentConfig
metadata:
  name: kcp-resources-override
  labels:
    kcp/component: kcp
    platform/override: "true"
data:
  resources:
    requests:
      cpu: "2"
      memory: 4Gi
    limits:
      cpu: "4"
      memory: 8Gi
  replicas: 3
```

---

## Component Configuration Reference

Each platform component has a corresponding EnvironmentConfig namespace. The labels identify which component a config applies to.

| Component label | Component |
|-----------------|-----------|
| `kcp/component: kcp` | KCP workspace service |
| `kcp/component: mto` | Multi-Tenant Operator |
| `kcp/component: keycloak` | Keycloak identity platform |
| `kcp/component: openbao` | OpenBao secrets engine |
| `kcp/component: crossplane` | Crossplane and providers |
| `kcp/component: hypershift` | HyperShift operator |
| `kcp/component: openshift-virt` | OpenShift Virtualization |
| `kcp/component: platform-services` | api-syncagent and API publishing |

---

## Viewing Current Configuration

To inspect the current EnvironmentConfig for a component:

```bash
# List all platform EnvironmentConfigs
kubectl get environmentconfigs -l kcp/component

# View the default config for a component
kubectl get environmentconfig kcp-defaults -o yaml

# View any overrides
kubectl get environmentconfigs -l platform/override=true
```

---

## Configuration Workflow

The recommended workflow for platform configuration changes:

1. **Identify the setting** — inspect the default EnvironmentConfig for the target component to find the correct key
1. **Create an override** — write a new EnvironmentConfig in your GitOps repository targeting only the keys you need to change
1. **Raise a pull request** — review and approve the change through your standard code review process
1. **Merge and sync** — ArgoCD syncs the override to the cluster; Crossplane reconciles the component
1. **Verify** — check the component's status and confirm the new configuration is in effect

This workflow ensures all configuration changes are auditable, reversible (via Git revert), and applied through the same review process as application changes.

---

## What's Next?

- [Service Provider Guide](../service-provider-guide/getting-started.md) — Start building service offerings
- [Crossplane Integration](../integrations/crossplane.md) — How Crossplane manages platform components
- [Architecture](../architecture/architecture.md) — Understanding the platform's design
