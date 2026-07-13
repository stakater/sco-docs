# Crossplane Compositions

Crossplane compositions are the implementation layer for SCO solutions. This page covers composition authoring patterns specific to the SCO platform context.

For the full reference on Crossplane, providers, and the KCL function, see the [Crossplane Integration](../../integrations/crossplane.md) guide.

---

## Composition Patterns in SCO

SCO compositions follow consistent patterns across all built-in and custom solutions. Any Crossplane pipeline function is supported — choose the language that suits your team.

### Pipeline mode

All SCO compositions use pipeline mode with a logic function followed by `function-auto-ready` for readiness detection:

```yaml
spec:
  mode: Pipeline
  pipeline:
    - step: main
      functionRef:
        name: function-kcl   # or function-go-templating, function-pythonic, etc.
      input:
        # function-specific input here
    - step: automatically-detect-ready-composed-resources
      functionRef:
        name: function-auto-ready
```

### KCL skeleton (`function-kcl`)

```kcl
# 1. Extract context
oxr = option("params").oxr    # The composite resource being reconciled

# 2. Pull parameters
spec = oxr.spec
parameters = spec.parameters
kubernetesProvider = spec?.providerConfigsRef?.kubernetes or "kubernetes-provider"

# 3. Define resources as a list
# Each item needs a "krm.kcl.dev/composition-resource-name" annotation
# for stable identity across reconciliations
items = [
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha2"
        kind: "Object"
        metadata: {
            name: parameters.myParam
            annotations: {
                "krm.kcl.dev/composition-resource-name": "my-resource"
            }
        }
        spec: {
            providerConfigRef: {name: kubernetesProvider}
            forProvider: {
                manifest: {
                    apiVersion: "..."
                    kind: "..."
                    metadata: {name: parameters.myParam, namespace: spec.claimRef.namespace}
                    spec: {...}
                }
            }
        }
    }
]
```

### Go templates skeleton (`function-go-templating`)

```yaml
input:
  apiVersion: gotemplating.fn.crossplane.io/v1beta1
  kind: GoTemplate
  source: Inline
  inline:
    template: |
      {{- $params := .observed.composite.resource.spec.parameters }}
      {{- $spec := .observed.composite.resource.spec }}
      ---
      apiVersion: kubernetes.crossplane.io/v1alpha2
      kind: Object
      metadata:
        name: {{ $params.myParam }}
        annotations:
          gotemplating.fn.crossplane.io/composition-resource-name: my-resource
      spec:
        providerConfigRef:
          name: {{ default "kubernetes-provider" $spec.providerConfigsRef.kubernetes }}
        forProvider:
          manifest:
            apiVersion: "..."
            kind: "..."
            metadata:
              name: {{ $params.myParam }}
              namespace: {{ $spec.claimRef.namespace }}
            spec: {}
```

### Python skeleton (`function-pythonic`)

```python
from crossplane.function import resource
from crossplane.function.proto.v1 import run_function_pb2 as fnv1

def compose(req: fnv1.RunFunctionRequest, rsp: fnv1.RunFunctionResponse):
    params = req.observed.composite.resource["spec"]["parameters"]
    spec = req.observed.composite.resource["spec"]

    k8s_provider = spec.get("providerConfigsRef", {}).get(
        "kubernetes", "kubernetes-provider"
    )

    resource.update(rsp.desired.resources["my-resource"], {
        "apiVersion": "kubernetes.crossplane.io/v1alpha2",
        "kind": "Object",
        "metadata": {"name": params["myParam"]},
        "spec": {
            "providerConfigRef": {"name": k8s_provider},
            "forProvider": {
                "manifest": {
                    "apiVersion": "...",
                    "kind": "...",
                    "metadata": {
                        "name": params["myParam"],
                        "namespace": spec["claimRef"]["namespace"],
                    },
                    "spec": {},
                }
            },
        },
    })
```

---

## Key Composition Features

### Resource dependencies

Use Crossplane `Usage` resources to enforce creation and deletion ordering. Create the `Usage` alongside the dependent resource so Crossplane will not delete the dependency until all dependents are removed:

```kcl
items = [
    # 1. The primary resource
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha2"
        kind: "Object"
        metadata: {
            name: "my-namespace"
            annotations: {"krm.kcl.dev/composition-resource-name": "namespace"}
        }
        spec: {
            providerConfigRef: {name: kubernetesProvider}
            forProvider: {manifest: {apiVersion: "v1", kind: "Namespace", metadata: {name: targetNamespace}}}
        }
    }
    # 2. A dependent resource — its Usage ensures the namespace outlives it
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha2"
        kind: "Object"
        metadata: {
            name: "my-deployment"
            annotations: {"krm.kcl.dev/composition-resource-name": "deployment"}
        }
        spec: {
            providerConfigRef: {name: kubernetesProvider}
            forProvider: {manifest: {apiVersion: "apps/v1", kind: "Deployment", metadata: {name: "my-app", namespace: targetNamespace}, spec: {}}}
        }
    }
    # 3. Usage — blocks deletion of "namespace" until "deployment" is deleted
    {
        apiVersion: "apiextensions.crossplane.io/v1alpha1"
        kind: "Usage"
        metadata: {
            name: "deployment-uses-namespace"
            annotations: {"krm.kcl.dev/composition-resource-name": "deployment-uses-namespace"}
        }
        spec: {
            of: {apiVersion: "kubernetes.crossplane.io/v1alpha2", kind: "Object", resourceRef: {name: "my-namespace"}}
            by: {apiVersion: "kubernetes.crossplane.io/v1alpha2", kind: "Object", resourceRef: {name: "my-deployment"}}
        }
    }
]
```

### Propagating status to the consumer

To surface connection details on the consumer's claim status, include the composite resource itself in the `items` output with updated status fields:

```kcl
oxr = option("params").oxr
ocds = option("params").ocds

# Read status from the observed composed resource (if it already exists)
observed_db = ocds?.["postgresql-cluster"]?.Resource
endpoint = observed_db?.status?.atProvider?.manifest?.status?.writeService or ""

# Write status back to the composite
_xr_patch = {
    apiVersion: oxr.apiVersion
    kind: oxr.kind
    metadata: {name: oxr.metadata.name}
    status: {
        endpoint: endpoint
        port: 5432
    }
}

items = [_cluster, _xr_patch]
```

### Conditional resource creation

Use a conditional list comprehension to include or skip resources:

```kcl
enable_backup = parameters?.enableBackup or False

_backup = [
    {
        apiVersion: "v1"
        kind: "ConfigMap"
        metadata: {
            name: "backup-config"
            annotations: {"krm.kcl.dev/composition-resource-name": "backup-config"}
        }
        # ...
    }
] if enable_backup else []

items = [_cluster] + _backup
```

### Iterating to create multiple resources

```kcl
config_items = parameters?.configItems or []

_configMaps = [
    {
        apiVersion: "v1"
        kind: "ConfigMap"
        metadata: {
            name: "{}-{}".format(base_name, i)
            annotations: {
                "krm.kcl.dev/composition-resource-name": "config-{}".format(i)
            }
        }
        data: {key: item.value}
    }
    for i, item in config_items
]

items = _configMaps
```

---

## Using the Kubernetes Provider

The `kubernetes-provider` is the workhorse for most compositions — it manages Kubernetes resources on the service cluster through Crossplane `Object` resources:

```kcl
items = [
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha2"
        kind: "Object"
        metadata: {
            name: "app-config"
            annotations: {"krm.kcl.dev/composition-resource-name": "app-config"}
        }
        spec: {
            providerConfigRef: {name: kubernetesProvider}
            forProvider: {
                manifest: {
                    apiVersion: "v1"
                    kind: "ConfigMap"
                    metadata: {name: "app-config", namespace: targetNamespace}
                    data: {key: "value"}
                }
            }
        }
    }
]
```

Use `managementPolicies: ["Observe"]` to read an existing resource without managing it:

```kcl
{
    apiVersion: "kubernetes.crossplane.io/v1alpha2"
    kind: "Object"
    metadata: {
        name: "existing-secret"
        annotations: {"krm.kcl.dev/composition-resource-name": "existing-secret"}
    }
    spec: {
        managementPolicies: ["Observe"]
        providerConfigRef: {name: kubernetesProvider}
        forProvider: {
            manifest: {
                apiVersion: "v1"
                kind: "Secret"
                metadata: {name: "my-secret", namespace: targetNamespace}
            }
        }
    }
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

- [Modelling Subresources](modeling-subresources.md) — Model parent/child relationships between claim kinds
- [Crossplane Integration](../../integrations/crossplane.md) — Full provider setup and composition reference
- [Publishing APIs](../api-publishing/publishing-apis.md) — Expose your composition to consumer projects
- [Create PostgreSQL Solution](../../how-to-guides/provider/create-postgresql-solution.md) — Full end-to-end worked example
