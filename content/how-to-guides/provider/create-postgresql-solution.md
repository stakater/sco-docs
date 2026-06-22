# How to Create a PostgreSQL Solution

This guide walks through creating and publishing a PostgreSQL-as-a-service offering using CloudNativePG and Crossplane, making it available to consumers as a self-service catalogue entry.

---

## Prerequisites

- `infrastructure.stakater.com` API available
- CloudNativePG operator installed on the management cluster
- `kubernetes-provider`, `kcp-provider`, and `helm-provider` configured
- `kcp-api-syncagent` Helm chart installed (see [Publishing APIs](../../service-provider-guide/api-publishing/publishing-apis.md))

Install CloudNativePG:

```bash
kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/releases/cnpg-1.24.0.yaml
```

---

## Step 1: Define the XRD

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
                      enum: ["14", "15", "16"]
                      description: PostgreSQL major version
                    storageGb:
                      type: integer
                      default: 20
                      description: Storage in GiB
                    instances:
                      type: integer
                      default: 1
                      description: "1 = standalone, 3 = high availability"
            status:
              type: object
              properties:
                endpoint:
                  type: string
                port:
                  type: integer
                secretName:
                  type: string
```

```bash
kubectl apply -f xrd.yaml
```

---

## Step 2: Write the Composition

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
            ocds = option("params").ocds

            spec = oxr.spec
            parameters = spec.parameters
            kubernetesProvider = spec?.providerConfigsRef?.kubernetes or "kubernetes-provider"

            dbName = parameters.dbName
            instances = parameters?.instances or 1
            storageGb = parameters?.storageGb or 20
            pgVersion = parameters?.version or "16"
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
                                metadata: {
                                    name: dbName
                                    namespace: targetNamespace
                                }
                                spec: {
                                    instances: instances
                                    postgresql: {
                                        parameters: {
                                            max_connections: "200"
                                            shared_buffers: "256MB"
                                        }
                                    }
                                    bootstrap: {
                                        initdb: {
                                            database: dbName
                                            owner: dbName
                                        }
                                    }
                                    storage: {
                                        size: "{}Gi".format(storageGb)
                                    }
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

```bash
kubectl apply -f composition.yaml
```

---

## Step 3: Test the Composition

```yaml
apiVersion: databases.cloud.stakater.com/v1
kind: PostgreSQLDatabase
metadata:
  name: test-postgres
spec:
  parameters:
    dbName: testapp
    version: "16"
    storageGb: 10
    instances: 1
```

```bash
kubectl apply -f test-claim.yaml
kubectl get postgresqldatabase test-postgres -w
kubectl get postgresqldatabase test-postgres -o jsonpath='{.status}'
```

Remove the test claim before publishing:

```bash
kubectl delete postgresqldatabase test-postgres
```

---

## Step 4: Publish the API

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
kubectl apply -f apiexport.yaml
kubectl get apiexport databases-service
```

---

## Step 5: Verify Consumer Access

```bash
export KUBECONFIG=~/.kube/consumer-project.yaml
kubectl api-resources | grep databases.cloud.stakater.com
```

Consumers can now provision PostgreSQL databases:

```yaml
apiVersion: databases.cloud.stakater.com/v1
kind: PostgreSQLDatabase
metadata:
  name: my-app-db
spec:
  parameters:
    dbName: myapp
    version: "16"
    storageGb: 50
    instances: 3
```

---

## What's Next?

- [Crossplane Compositions](../../service-provider-guide/solutions/crossplane-compositions.md) — Advanced composition patterns
- [Publishing APIs](../../service-provider-guide/api-publishing/publishing-apis.md) — Full publishing guide
- [Crossplane Integration](../../integrations/crossplane.md) — Provider setup and KCL function reference
