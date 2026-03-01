# Creating Solutions

This guide walks through building a complete solution — from defining the API schema to making it available in consumer project workspaces.

---

## Prerequisites

- `infrastructure.stakater.com` API available
- Crossplane installed with `kubernetes-provider`, `kcp-provider`, and `helm-provider` configured
- Target operator installed on the management cluster (e.g., CloudNativePG for a PostgreSQL solution)

---

## Overview

Creating a solution involves four steps:

1. **Define the XRD** — the API schema consumers interact with
1. **Write the Composition** — the implementation that fulfils claims
1. **Test locally** — validate with a test claim before publishing
1. **Publish** — expose the API to consumer project workspaces

---

## Step 1: Define the XRD

The `CompositeResourceDefinition` declares the API your solution exposes. It defines what fields consumers configure, what validation rules apply, and what defaults are set.

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xpostgresqldatabases.databases.cloud.stakater.com
spec:
  scope: LegacyCluster
  group: databases.cloud.stakater.com
  names:
    kind: XPostgreSQLDatabase
    plural: xpostgresqldatabases
  claimNames:
    kind: PostgreSQLDatabase
    plural: postgresqldatabases
  versions:
    - name: v1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                providerConfigsRef:
                  type: object
                  properties:
                    kubernetes:
                      type: string
                      default: kubernetes-provider
                parameters:
                  type: object
                  required: [dbName]
                  properties:
                    dbName:
                      type: string
                      description: Name of the database instance
                    version:
                      type: string
                      default: "16"
                      description: PostgreSQL major version
                      enum: ["14", "15", "16"]
                    storageGb:
                      type: integer
                      default: 20
                      description: Storage size in GiB
                    instances:
                      type: integer
                      default: 1
                      description: Number of PostgreSQL instances (1 = standalone, 3 = HA)
            status:
              type: object
              properties:
                endpoint:
                  type: string
                  description: Connection endpoint for the database
                port:
                  type: integer
```

Apply the XRD to the management cluster:

```bash
kubectl apply -f xrd.yaml
```

Crossplane validates the XRD and makes the claim type available.

---

## Step 2: Write the Composition

The Composition implements the XRD — it defines what infrastructure to create when a consumer applies a `PostgreSQLDatabase` claim.

SCO supports any Crossplane pipeline function — use whichever language you are most comfortable with. The same composition is shown below in three languages. See [Crossplane Compositions](crossplane-compositions.md) for patterns and examples.

### Using `function-kcl` (KCL)

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  labels:
    crossplane.io/xrd: xpostgresqldatabases.databases.cloud.stakater.com
  name: postgresql-database
spec:
  compositeTypeRef:
    apiVersion: databases.cloud.stakater.com/v1
    kind: XPostgreSQLDatabase
  mode: Pipeline
  pipeline:
    - step: kcl
      functionRef:
        name: function-kcl
      input:
        apiVersion: krm.kcl.dev/v1alpha1
        kind: KCLInput
        spec:
          source: |
            oxr = option("params").oxr

            spec = oxr.spec
            parameters = spec.parameters
            kubernetesProvider = spec?.providerConfigsRef?.kubernetes or "kubernetes-provider"

            dbName = parameters.dbName
            instances = parameters?.instances or 1
            storageGb = parameters?.storageGb or 20
            targetNamespace = spec.claimRef.namespace

            items = [
                {
                    apiVersion: "kubernetes.crossplane.io/v1alpha2"
                    kind: "Object"
                    metadata: {
                        name: dbName
                        annotations: {
                            "krm.kcl.dev/composition-resource-name": "postgresql-cluster"
                        }
                    }
                    spec: {
                        providerConfigRef: {name: kubernetesProvider}
                        forProvider: {
                            manifest: {
                                apiVersion: "postgresql.cnpg.io/v1"
                                kind: "Cluster"
                                metadata: {name: dbName, namespace: targetNamespace}
                                spec: {
                                    instances: instances
                                    postgresql: {parameters: {max_connections: "200"}}
                                    bootstrap: {initdb: {database: dbName, owner: dbName}}
                                    storage: {size: "{}Gi".format(storageGb)}
                                }
                            }
                        }
                    }
                }
            ]

    - step: automatically-detect-ready-composed-resources
      functionRef:
        name: function-auto-ready
```

### Using `function-go-templating` (Go templates)

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  labels:
    crossplane.io/xrd: xpostgresqldatabases.databases.cloud.stakater.com
  name: postgresql-database
spec:
  compositeTypeRef:
    apiVersion: databases.cloud.stakater.com/v1
    kind: XPostgreSQLDatabase
  mode: Pipeline
  pipeline:
    - step: go-templates
      functionRef:
        name: function-go-templating
      input:
        apiVersion: gotemplating.fn.crossplane.io/v1beta1
        kind: GoTemplate
        source: Inline
        inline:
          template: |
            {{- $params := .observed.composite.resource.spec.parameters }}
            {{- $spec := .observed.composite.resource.spec }}
            {{- $dbName := $params.dbName }}
            {{- $instances := default 1 $params.instances }}
            {{- $storageGb := default 20 $params.storageGb }}
            ---
            apiVersion: kubernetes.crossplane.io/v1alpha2
            kind: Object
            metadata:
              name: {{ $dbName }}
              annotations:
                gotemplating.fn.crossplane.io/composition-resource-name: postgresql-cluster
            spec:
              providerConfigRef:
                name: {{ default "kubernetes-provider" $spec.providerConfigsRef.kubernetes }}
              forProvider:
                manifest:
                  apiVersion: postgresql.cnpg.io/v1
                  kind: Cluster
                  metadata:
                    name: {{ $dbName }}
                    namespace: {{ $spec.claimRef.namespace }}
                  spec:
                    instances: {{ $instances }}
                    postgresql:
                      parameters:
                        max_connections: "200"
                    bootstrap:
                      initdb:
                        database: {{ $dbName }}
                        owner: {{ $dbName }}
                    storage:
                      size: {{ $storageGb }}Gi

    - step: automatically-detect-ready-composed-resources
      functionRef:
        name: function-auto-ready
```

### Using `function-pythonic` (Python)

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  labels:
    crossplane.io/xrd: xpostgresqldatabases.databases.cloud.stakater.com
  name: postgresql-database
spec:
  compositeTypeRef:
    apiVersion: databases.cloud.stakater.com/v1
    kind: XPostgreSQLDatabase
  mode: Pipeline
  pipeline:
    - step: python
      functionRef:
        name: function-pythonic
      input:
        apiVersion: pythonic.fn.crossplane.io/v1beta1
        kind: PythonInput
        spec:
          inline: |
            from crossplane.function import resource
            from crossplane.function.proto.v1 import run_function_pb2 as fnv1

            def compose(req: fnv1.RunFunctionRequest, rsp: fnv1.RunFunctionResponse):
                params = req.observed.composite.resource["spec"]["parameters"]
                spec = req.observed.composite.resource["spec"]

                db_name = params["dbName"]
                instances = params.get("instances", 1)
                storage_gb = params.get("storageGb", 20)
                target_namespace = spec["claimRef"]["namespace"]
                k8s_provider = spec.get("providerConfigsRef", {}).get(
                    "kubernetes", "kubernetes-provider"
                )

                resource.update(rsp.desired.resources["postgresql-cluster"], {
                    "apiVersion": "kubernetes.crossplane.io/v1alpha2",
                    "kind": "Object",
                    "metadata": {"name": db_name},
                    "spec": {
                        "providerConfigRef": {"name": k8s_provider},
                        "forProvider": {
                            "manifest": {
                                "apiVersion": "postgresql.cnpg.io/v1",
                                "kind": "Cluster",
                                "metadata": {
                                    "name": db_name,
                                    "namespace": target_namespace,
                                },
                                "spec": {
                                    "instances": instances,
                                    "postgresql": {
                                        "parameters": {"max_connections": "200"}
                                    },
                                    "bootstrap": {
                                        "initdb": {
                                            "database": db_name,
                                            "owner": db_name,
                                        }
                                    },
                                    "storage": {"size": f"{storage_gb}Gi"},
                                },
                            }
                        },
                    },
                })

    - step: automatically-detect-ready-composed-resources
      functionRef:
        name: function-auto-ready
```

Apply the Composition:

```bash
kubectl apply -f composition.yaml
```

---

## Step 3: Test Locally

Before publishing, validate the solution with a test claim on the management cluster:

```yaml
apiVersion: databases.cloud.stakater.com/v1
kind: PostgreSQLDatabase
metadata:
  name: test-db
spec:
  parameters:
    dbName: myapp
    version: "16"
    storageGb: 10
    instances: 1
```

```bash
kubectl apply -f test-claim.yaml
kubectl get postgresqldatabase test-db
kubectl describe postgresqldatabase test-db
```

Watch for `Ready: True` in the status conditions. If the claim gets stuck, inspect the composed resources:

```bash
kubectl get managed -l crossplane.io/claim-name=test-db
```

Remove the test claim before publishing:

```bash
kubectl delete postgresqldatabase test-db
```

---

## Step 4: Publish to Consumer Projects

Once the XRD and Composition are verified, publish the API to consumer project workspaces using a `PublishedOffering` claim:

```yaml
apiVersion: infrastructure.stakater.com/v1alpha1
kind: PublishedOffering
metadata:
  name: databases-service
spec:
  providerConfigRef:
    name: kubernetes-provider
  kcpProviderConfigRef:
    name: kcp-provider
  helmProviderConfigRef:
    name: helm-provider
  parameters:
    apiSyncagent:
      namespace: kcp-system
    exports:
      - apiGroup: databases.cloud.stakater.com
        resources:
          - resource:
              kind: PostgreSQLDatabase
              plural: postgresqldatabases
              version: v1
            namespaceSuffix: postgresql
```

```bash
kubectl apply -f published-offering.yaml
```

The `PostgreSQLDatabase` claim type is now available in all consumer project workspaces. See [Publishing APIs](../api-publishing/publishing-apis.md) for the full publishing guide.

---

## What's Next?

- [Crossplane Compositions](crossplane-compositions.md) — Advanced composition patterns and KCL functions
- [Publishing APIs](../api-publishing/publishing-apis.md) — Detailed API publishing guide
- [Create PostgreSQL Solution](../../how-to-guides/provider/create-postgresql-solution.md) — Full worked example
