# Crossplane

Crossplane is the composition engine that powers the SCO service catalogue. Platform providers use it to define services — virtual machines, clusters, databases, or any infrastructure primitive — as Kubernetes custom resources that consumers can provision via standard claims.

SCO ships with Crossplane pre-installed and pre-configured. This page covers how to extend the platform by adding new providers and authoring your own compositions.

---

## How Crossplane Fits in SCO

When a consumer applies a claim — for example, an `OpenShiftCluster` — Crossplane intercepts it and runs a pipeline of functions to determine what infrastructure to create. Those functions reach out to providers (Kubernetes, cloud APIs, internal systems) to reconcile the desired state.

```text
Consumer claim (OpenShiftCluster)
    ↓
Crossplane composition pipeline
    ↓
Function: function-kcl   ← business logic (KCL scripts)
Function: function-auto-ready
    ↓
Composed resources
    ├── Kubernetes objects
    ├── Cloud provider resources
    └── Operator CRs
```

The composition author decides what gets created, how parameters are validated, what defaults apply, and what status is returned to the consumer. Consumers declare intent; Crossplane handles fulfillment.

---

## Installing a New Provider

Crossplane providers extend what resources you can manage. SCO supports any provider published to the Crossplane marketplace.

### 1. Create the Provider resource

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-s3
spec:
  package: xpkg.upbound.io/upbound/provider-aws-s3:v1.14.0
  packagePullPolicy: IfNotPresent
  installationPolicy: Automatic
```

Apply it to the management cluster:

```bash
kubectl apply -f provider-aws-s3.yaml
```

Wait for the provider to become healthy:

```bash
kubectl get provider provider-aws-s3
# NAME               INSTALLED   HEALTHY   PACKAGE                                         AGE
# provider-aws-s3    INSTALLED=True   HEALTHY=True   xpkg.upbound.io/upbound/provider-aws-s3:...   2m
```

Once healthy, the provider CRDs are available on the cluster, for example `buckets.s3.aws.upbound.io`.

### 2. Configure provider credentials

Most providers need credentials to communicate with external systems. Create a Kubernetes secret containing the credentials, then create a `ProviderConfig` that references it.

#### Example: AWS credentials

```bash
kubectl create secret generic aws-credentials \
  --from-literal=creds='[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY' \
  -n stakater-crossplane
```

```yaml
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: stakater-aws
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: stakater-crossplane
      name: aws-credentials
      key: creds
```

#### Example: Kubernetes provider (in-cluster identity)

When targeting the management cluster itself, the Kubernetes provider can use its injected service account identity — no credentials secret needed:

```yaml
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: kubernetes-provider
spec:
  credentials:
    source: InjectedIdentity
```

#### Example: Vault provider

```yaml
apiVersion: vault.upbound.io/v1alpha1
kind: ProviderConfig
metadata:
  name: provider-vault
spec:
  server: https://vault.example.com:8200
  auth:
    method: kubernetes
    kubernetes:
      role: crossplane
      mountPath: /auth/kubernetes
      serviceAccountToken:
        source: Filesystem
```

!!! tip "Credential management"
    For production deployments, store provider credentials using External Secrets Operator or SealedSecrets rather than creating plain secrets directly. The `ProviderConfig` reference remains the same — only the secret creation method changes.

---

## Composites, Claims, and XRDs

Crossplane exposes services through a three-layer model:

| Resource | Role |
|----------|------|
| `CompositeResourceDefinition` (XRD) | Defines the schema — what fields consumers configure |
| `Composition` | Implements the schema — what gets created |
| Claim | Consumer-facing resource that triggers the composition |

The SCO public service APIs (e.g., `compute.cloud.stakater.com/v1 VirtualMachine`) are XRDs whose compositions are bundled with the platform. You can add your own XRDs alongside them.

---

## Writing Your First Composition

Crossplane compositions use a pipeline of functions to produce composed resources. SCO supports any pipeline function — KCL (`function-kcl`), Go templates (`function-go-templating`), Python (`function-pythonic`), and others. Choose the language that suits your team.

### Step 1: Define the XRD

The XRD declares the API your consumers will use. Create a `CompositeResourceDefinition`:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xpostgresqldatabases.infrastructure.stakater.com
spec:
  scope: LegacyCluster
  group: infrastructure.stakater.com
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
                      description: Name of the Kubernetes ProviderConfig
                    aws:
                      type: string
                      description: Name of the AWS ProviderConfig
                  required: [kubernetes, aws]
                parameters:
                  type: object
                  required: [dbName, dbUsername]
                  properties:
                    dbName:
                      type: string
                      description: Name of the database
                    dbUsername:
                      type: string
                      description: Database username
                    storageGb:
                      type: integer
                      default: 20
                      description: Storage size in GB
                    engineVersion:
                      type: string
                      default: "15"
                      description: PostgreSQL version
            status:
              type: object
              properties:
                endpoint:
                  type: string
                port:
                  type: integer
```

### Step 2: Write the Composition

The example below uses `function-kcl`. See [Creating Solutions](../service-provider-guide/solutions/creating-solutions.md) for the same composition written in Go templates and Python.

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  labels:
    crossplane.io/xrd: xpostgresqldatabases.infrastructure.stakater.com
  name: postgresql-database
spec:
  compositeTypeRef:
    apiVersion: infrastructure.stakater.com/v1
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
            awsProvider = spec?.providerConfigsRef?.aws or "stakater-aws"

            dbName = parameters.dbName
            storageGb = parameters?.storageGb or 20
            engineVersion = parameters?.engineVersion or "15"

            items = [
                {
                    apiVersion: "rds.aws.upbound.io/v1beta1"
                    kind: "Instance"
                    metadata: {
                        name: dbName
                        annotations: {
                            "krm.kcl.dev/composition-resource-name": "rds-instance"
                        }
                    }
                    spec: {
                        providerConfigRef: {
                            name: awsProvider
                        }
                        forProvider: {
                            region: "eu-west-1"
                            engine: "postgres"
                            engineVersion: engineVersion
                            instanceClass: "db.t3.micro"
                            allocatedStorage: storageGb
                            dbName: dbName
                            username: parameters.dbUsername
                            skipFinalSnapshot: True
                            autoGeneratePassword: True
                            passwordSecretRef: {
                                namespace: "stakater-crossplane"
                                name: "{}-password".format(dbName)
                                key: "password"
                            }
                        }
                    }
                }
            ]

    - step: automatically-detect-ready-composed-resources
      functionRef:
        name: function-auto-ready
```

### Step 3: Understanding KCL composition structure

Every KCL composition follows the same pattern:

```kcl
# 1. Extract context
oxr = option("params").oxr    # The composite/claim being reconciled
ocds = option("params").ocds  # Currently observed composed resources

# 2. Pull parameters from the claim spec
spec = oxr.spec
parameters = spec.parameters
kubernetesProvider = spec?.providerConfigsRef?.kubernetes or "kubernetes-provider"

# 3. Return a list of composed resource manifests
# Each item needs a stable "krm.kcl.dev/composition-resource-name" annotation
items = [
    {
        apiVersion: "..."
        kind: "..."
        metadata: {
            name: "..."
            annotations: {
                "krm.kcl.dev/composition-resource-name": "unique-stable-name"
            }
        }
        spec: {
            # resource spec
        }
    }
]
```

Key patterns:

- **Stable resource names** — The `krm.kcl.dev/composition-resource-name` annotation is how Crossplane tracks composed resources across reconciliations. Use a fixed string, not a dynamic value.
- **Conditional resources** — Use list comprehensions with `if` to include or skip resources based on parameters.
- **Status propagation** — Include the composite resource itself in `items` with updated `.status` fields to surface connection details on the consumer's claim.

---

## What's Next?

- [Creating Solutions](../service-provider-guide/solutions/creating-solutions.md) — End-to-end guide to publishing a solution to the catalogue
- [Crossplane Compositions](../service-provider-guide/solutions/crossplane-compositions.md) — Advanced composition patterns
- [KCP Integration](kcp.md) — How the virtual API layer publishes your compositions to consumers
