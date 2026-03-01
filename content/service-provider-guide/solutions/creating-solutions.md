# Creating Solutions

This guide walks through building a complete solution — from defining the API schema to making it available in consumer project workspaces.

---

## Prerequisites

- `infrastructure.stakater.com` api available
- Crossplane installed with `kubernetes-provider`, `kcp-provider`, and `helm-provider` configured
- Target operator installed on the management cluster (e.g., CloudNativePG for a PostgreSQL solution)

---

## Overview

Creating a solution involves four steps:

1. **Define the XRD** — the API schema consumers interact with
2. **Write the Composition** — the implementation that fulfils claims
3. **Test locally** — validate with a test claim before publishing
4. **Publish** — expose the API to consumer project workspaces

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

SCO compositions use `function-kcl` for the business logic. See [Crossplane Compositions](crossplane-compositions.md) for the full authoring guide. A minimal working example:

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
          dependencies: |
            stakaterCommon = { oci = "oci://ghcr.io/stakater/compositions/kcl/stakater-common", tag = "0.0.2" }
          source: |
            import stakaterCommon as sc

            oxr = option("params").oxr
            ocds = option("params").ocds
            a = sc.generateItemMethods(ocds)

            spec = oxr.spec
            parameters = spec.parameters
            kubernetesProvider = spec?.providerConfigsRef?.kubernetes or "kubernetes-provider"

            dbName = parameters.dbName
            instances = parameters?.instances or 1
            storageGb = parameters?.storageGb or 20
            version = parameters?.version or "16"

            _cluster = a.createItem({
                resourceName: "postgresql-cluster"
                content: {
                    apiVersion: "postgresql.cnpg.io/v1"
                    kind: "Cluster"
                    metadata: {name: dbName}
                    spec: {
                        instances: instances
                        postgresql: {parameters: {max_connections: "200"}}
                        bootstrap: {initdb: {database: dbName, owner: dbName}}
                        storage: {size: "{}Gi".format(storageGb)}
                    }
                }
                statusDetails: {
                    statusFunction: lambda item: sc.savedItem -> {str:any} {
                        {
                            endpoint: item.status?.writeService
                            port: 5432
                        }
                    }
                }
                conditionPropagation: a.defaultPropagation()
            })

            items = a.renderItems({})

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

Once the XRD and Composition are verified, publish the API to consumer project workspaces using an `ApiExport` claim:

```yaml
apiVersion: infrastructure.stakater.com/v1alpha1
kind: ApiExport
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
kubectl apply -f api-export.yaml
```

The `PostgreSQLDatabase` claim type is now available in all consumer project workspaces. See [Publishing APIs](../api-publishing/publishing-apis.md) for the full publishing guide.

---

## What's Next?

- [Crossplane Compositions](crossplane-compositions.md) — Advanced composition patterns and KCL functions
- [Publishing APIs](../api-publishing/publishing-apis.md) — Detailed API publishing guide
- [Create PostgreSQL Solution](../../how-to-guides/provider/create-postgresql-solution.md) — Full worked example
