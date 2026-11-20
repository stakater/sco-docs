# Platform Configuration

SCO uses a GitOps-native configuration model. Rather than a traditional admin control panel or config file, platform behaviour is controlled through Kubernetes `EnvironmentConfig` resources that are reconciled continuously by Crossplane.

---

## How Configuration Works

`ksp up` installs the platform packages and applies your `KubeStackConfig` and `KubeStackPlus` claims. From the `KubeStackConfig` claim, the platform generates one **default EnvironmentConfig per platform component**. Each one holds that component's chart version and its Helm values, as set by the platform release you run. See [Versioning and Upgrades](versioning.md).

Each platform component is packaged as a Helm chart in the Stakater distribution registry. Crossplane reads the EnvironmentConfigs and renders one ArgoCD `Application` per component, passing the version and values from the EnvironmentConfig. When they change, Crossplane re-renders the `Application`, and ArgoCD reconciles the component toward the new desired state automatically.

```text
ksp up (initial install)
    ↓
KubeStackConfig + KubeStackPlus claims applied
    ↓
Platform generates a default EnvironmentConfig per component (version + values)
    ↓
Your override EnvironmentConfigs are merged over the defaults
    ↓
Crossplane renders one ArgoCD Application per component
    ↓
ArgoCD deploys each component from its chart
    ↓
Platform running
```

The default EnvironmentConfigs belong to the platform. A change made directly to one of them does not last: the platform generates it again. To change a setting, add an override.

---

## Customising Platform Configuration

To change any default — for example, raising the resource limits of a component — platform operators create **override EnvironmentConfigs** in their GitOps repository.

An override EnvironmentConfig targets one component and declares only the values that differ from the defaults. When it is applied to the cluster, Crossplane merges it over the component's default EnvironmentConfig and re-renders the ArgoCD `Application` with the updated Helm values. ArgoCD then reconciles the component.

### Example: Adjusting component resource limits

This override raises the resource limits of the `crossplane` component on a `scobasic` installation:

```yaml
apiVersion: apiextensions.crossplane.io/v1beta1
kind: EnvironmentConfig
metadata:
  name: <cluster-name>-crossplane-addon-env-override
  labels:
    kubestack.stakater.com/addon-name: crossplane
    kubestack.stakater.com/config-kind: kubestack-plus-env
    kubestack.stakater.com/config-scope: addon
    kubestack.stakater.com/domain: <apps-domain>
    kubestack.stakater.com/name: <cluster-name>
data:
  SCOBASIC-OCP-VALUES: |
    crossplane:
      resourcesCrossplane:
        limits:
          cpu: "4"
          memory: 8Gi
        requests:
          cpu: 500m
          memory: 2Gi
```

Store this in your GitOps repository. When ArgoCD syncs it to the cluster, Crossplane picks up the change and the component is redeployed with the new limits.

### What an override must contain

| Part | Rule |
|---|---|
| `kubestack.stakater.com/config-scope: addon` label | Required. The platform only reads EnvironmentConfigs that carry it |
| `kubestack.stakater.com/addon-name` label | Required. The component the override applies to |
| `metadata.name` | Must sort after the default, which is named `<cluster-name>-<component>-addon-env`. Adding `-override` to that name does this |
| `<VARIANT>-OCP-VALUES` | The Helm values to change, as a YAML string. The prefix is your variant in upper case: `SCOBASIC` or `HOSTING` |
| `<VARIANT>-OCP-VERSION` | Optional. Runs the component at a chart version other than the release default. See [Control Component Versions Yourself](versioning.md#control-component-versions-yourself) |

The values in an override are merged over the defaults key by key, so state only the keys you change.

!!! note "Values for the clusters the platform provisions"
    On the `hosting` variant, components that are also installed on provisioned clusters read their values from a separate `HOSTING-OCP-SPOKE-VALUES` key. An override that sets only `HOSTING-OCP-VALUES` does not reach those clusters; repeat the values under the `SPOKE-VALUES` key when it should.

### Cluster-wide settings

The file you pass to `ksp up` with `--environment-config` becomes the EnvironmentConfig `cluster-defaults`, which holds settings shared by all components, such as the base domain and the storage class. After installation the platform keeps it up to date from your `KubeStackConfig` claim, so direct edits to it do not last either. Change the claim, or add an override for the `crossplane-environment-config` component as shown in [`scobasic` Installation](scobasic.md#organization-platform-config).

---

## Discovering Available Configuration Fields

Each component's EnvironmentConfig stores its Helm values and version under keys following the pattern `{VARIANT}-{PLATFORM}-VALUES` and `{VARIANT}-{PLATFORM}-VERSION` (e.g., `SCOBASIC-OCP-VALUES`). To discover the component names and the fields available for a component:

```bash
# List every component EnvironmentConfig, defaults and overrides
kubectl get environmentconfigs -l kubestack.stakater.com/config-scope=addon

# Inspect a component's default EnvironmentConfig to see its values
kubectl get environmentconfig <cluster-name>-<component>-addon-env -o yaml

# Example: view the cert-manager configuration
kubectl get environmentconfig <cluster-name>-cert-manager-addon-env -o yaml
```

The component name is the value of the `kubestack.stakater.com/addon-name` label. The `VALUES` key in the `data` section contains the Helm values that are passed to the component's ArgoCD Application. These values correspond to the Helm chart's `values.yaml` for that component.

---

## Viewing Current Configuration

To inspect the current configuration of a component:

```bash
# Everything that applies to one component: its default and any overrides
kubectl get environmentconfigs -l kubestack.stakater.com/addon-name=<component>

# View any overrides on the cluster
kubectl get environmentconfigs -l kubestack.stakater.com/config-scope=addon -o name | grep override

# The merged values the component actually runs with
kubectl get applications.argoproj.io <component> -n openshift-gitops -o jsonpath='{.spec.source.helm.values}'
```

If your ArgoCD instance runs in a namespace other than `openshift-gitops`, use that namespace.

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

- [Versioning and Upgrades](versioning.md) — How platform releases, upgrades and version overrides work
- [Service Provider Guide](../service-provider-guide/getting-started.md) — Start building service offerings
- [Crossplane Integration](../integrations/crossplane.md) — How Crossplane manages platform components
- [Architecture](../architecture/architecture.md) — Understanding the platform's design
