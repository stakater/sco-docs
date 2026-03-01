# Crossplane Compositions

Crossplane compositions are the implementation layer for SCO solutions. This page covers composition authoring patterns specific to the SCO platform context.

For the full reference on Crossplane, providers, and the KCL function, see the [Crossplane Integration](../../integrations/crossplane.md) guide.

---

## Composition Patterns in SCO

SCO compositions follow consistent patterns across all built-in and custom solutions:

### Pipeline mode with function-kcl

All SCO compositions use pipeline mode with `function-kcl` as the primary logic step and `function-auto-ready` for readiness detection:

```yaml
spec:
  mode: Pipeline
  pipeline:
    - step: kcl
      functionRef:
        name: function-kcl
      input:
        apiVersion: krm.kcl.dev/v1alpha1
        kind: KCLInput
        spec:
          dependencies: |
            stakaterCommon = { oci = "oci://ghcr.io/stakater/compositions/kcl/stakater-common", tag = "0.0.2" }
          source: |
            # KCL script here
    - step: automatically-detect-ready-composed-resources
      functionRef:
        name: function-auto-ready
```

### KCL script skeleton

Every KCL composition follows the same skeleton:

```kcl
import stakaterCommon as sc

# 1. Extract context
oxr = option("params").oxr    # The composite resource being reconciled
ocds = option("params").ocds  # Currently observed composed resources
a = sc.generateItemMethods(ocds)

# 2. Pull parameters
spec = oxr.spec
parameters = spec.parameters
kubernetesProvider = spec?.providerConfigsRef?.kubernetes or "kubernetes-provider"

# 3. Define resources
_myResource = a.createItem({
    resourceName: "unique-stable-name"
    content: {
        apiVersion: "..."
        kind: "..."
        metadata: {name: "..."}
        spec: {...}
    }
    conditionPropagation: a.defaultPropagation()
})

# 4. Render — must be last statement
items = a.renderItems({})
```

---

## Key Composition Features

### Resource dependencies

Use `dependsOn` to enforce creation order. The framework also generates Crossplane `Usage` resources to enforce safe deletion ordering:

```kcl
_namespace = a.createItem({
    resourceName: "namespace"
    content: {...}
})

_deployment = a.createItem({
    resourceName: "deployment"
    dependsOn: [_namespace]  # Created only after namespace is ready
    content: {...}
})
```

### Propagating status to the consumer

Use `statusDetails.statusFunction` to return fields from composed resource status back to the composite's `.status`:

```kcl
_db = a.createItem({
    resourceName: "database"
    content: {...}
    statusDetails: {
        statusFunction: lambda item: sc.savedItem -> {str:any} {
            {
                endpoint: item.status?.atProvider?.endpoint
                port: item.status?.atProvider?.port
            }
        }
    }
})
```

These fields appear on the consumer's claim status, making connection information discoverable without accessing the service cluster directly.

### Exposing connection details

Use `connectionDetails` to write secrets to the consumer's connection secret:

```kcl
_secret = a.createItem({
    resourceName: "connection-secret"
    content: {...}
    connectionDetails: {
        rawDataFunction: lambda item: sc.savedItem -> {str:str} {
            {
                "db-endpoint": item.status?.atProvider?.endpoint or ""
                "db-password": item.status?.atProvider?.password or ""
            }
        }
    }
})
```

### Conditional resource creation

Skip resources based on parameter values:

```kcl
_backup = a.createItem({
    resourceName: "backup-config"
    condition: lambda _items: {str:sc.savedItem} -> bool {
        enableBackup == True
    }
    content: {...}
})
```

### Iterating to create multiple resources

```kcl
_configMaps = [a.createItem({
    resourceName: "config-{}".format(i)
    content: {
        apiVersion: "v1"
        kind: "ConfigMap"
        metadata: {name: "{}-{}".format(baseName, i)}
        data: {key: item.value}
    }
}) for i, item in configItems]
```

---

## Using the Kubernetes Provider

The `kubernetes-provider` is the workhorse for most compositions — it manages Kubernetes resources on the service cluster through Crossplane `Object` resources:

```kcl
_configMap = a.createItem({
    resourceName: "app-config"
    content: {
        apiVersion: "kubernetes.crossplane.io/v1alpha2"
        kind: "Object"
        metadata: {name: "app-config"}
        spec: {
            providerConfigRef: {name: kubernetesProvider}
            forProvider: {
                manifest: {
                    apiVersion: "v1"
                    kind: "ConfigMap"
                    metadata: {
                        name: "app-config"
                        namespace: targetNamespace
                    }
                    data: {key: "value"}
                }
            }
        }
    }
})
```

Use `managementPolicies: ["Observe"]` to read an existing resource without managing it:

```kcl
spec: {
    managementPolicies: ["Observe"]
    ...
}
```

---

## EnvironmentConfigs in Compositions

Compositions can consume platform-level `EnvironmentConfig` resources through the `function-environment-configs` step, injecting platform defaults or configuration into the composition context:

```yaml
- step: environmentConfigs
  functionRef:
    name: function-environment-configs
  input:
    apiVersion: environmentconfigs.fn.crossplane.io/v1beta1
    kind: Input
    spec:
      environmentConfigs:
        - type: Reference
          ref:
            name: platform-defaults
```

In the KCL script, access injected values:

```kcl
env = option("params")?.ctx?.["apiextensions.crossplane.io/environment-configs"] or {}
platformDefaults = env?.platformDefaults or {}
```

---

## Testing Compositions

Use `crossplane render` to test a composition locally without applying it to the cluster:

```bash
crossplane render claim.yaml composition.yaml functions.yaml
```

This renders the expected composed resources to stdout, making it easy to validate composition logic before deployment.

See the [Crossplane Integration](../../integrations/crossplane.md) guide for a full worked example of a composition with provider setup.

---

## What's Next?

- [Crossplane Integration](../../integrations/crossplane.md) — Full provider setup and composition reference
- [Publishing APIs](../api-publishing/publishing-apis.md) — Expose your composition to consumer projects
- [Create PostgreSQL Solution](../../how-to-guides/provider/create-postgresql-solution.md) — Full end-to-end worked example
