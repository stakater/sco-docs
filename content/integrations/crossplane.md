# Crossplane

Crossplane is the composition engine that powers SCO's service catalogue. Platform providers use it to define services — virtual machines, clusters, databases, or any infrastructure primitive — as Kubernetes custom resources that consumers can provision via standard claims.

SCO ships with Crossplane pre-installed and pre-configured. This page covers how to extend the platform by adding new providers and authoring your own compositions.

---

## How Crossplane Fits in SCO

When a consumer applies a claim — for example, an `OpenShiftCluster` — Crossplane intercepts it and runs a pipeline of functions to determine what infrastructure to create. Those functions reach out to providers (Kubernetes, cloud APIs, internal systems) to reconcile the desired state.

```
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
# provider-aws-s3    True        True      xpkg.upbound.io/upbound/provider-aws-s3:...     2m
```

Once healthy, the provider's CRDs are available on the cluster (e.g., `buckets.s3.aws.upbound.io`).

### 2. Configure provider credentials

Most providers need credentials to communicate with external systems. Create a Kubernetes secret containing the credentials, then create a `ProviderConfig` that references it.

**Example: AWS credentials**

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

**Example: Kubernetes provider (in-cluster identity)**

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

**Example: Vault provider**

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

SCO's public service APIs (e.g., `compute.cloud.stakater.com/v1 VirtualMachine`) are XRDs whose compositions are bundled with the platform. You can add your own XRDs alongside them.

---

## Writing Your First Composition

SCO compositions use **function-kcl**, a pipeline function that runs KCL (KCL Configuration Language) scripts to produce composed resources. KCL gives you the full expressiveness of a programming language — conditionals, iteration, string formatting — without leaving the Kubernetes ecosystem.

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
            awsProvider = spec?.providerConfigsRef?.aws or "stakater-aws"

            dbName = parameters.dbName
            storageGb = parameters?.storageGb or 20
            engineVersion = parameters?.engineVersion or "15"

            # RDS instance
            _rds = a.createItem({
                resourceName: "rds-instance"
                content: {
                    apiVersion: "rds.aws.upbound.io/v1beta1"
                    kind: "Instance"
                    metadata: {name: dbName}
                    spec: {
                        providerConfigRef: {name: awsProvider}
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
                statusDetails: {
                    statusFunction: lambda item: sc.savedItem -> {str:any} {
                        {
                            endpoint: item.status?.atProvider?.endpoint
                            port: item.status?.atProvider?.port
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

### Step 3: Understanding KCL composition structure

Every KCL composition follows the same skeleton:

```kcl
import stakaterCommon as sc

# 1. Extract context
oxr = option("params").oxr   # The composite/claim being reconciled
ocds = option("params").ocds # Currently observed composed resources
a = sc.generateItemMethods(ocds)

# 2. Pull parameters from the claim spec
spec = oxr.spec
parameters = spec.parameters
kubernetesProvider = spec?.providerConfigsRef?.kubernetes or "kubernetes-provider"

# 3. Define resources using a.createItem()
_myResource = a.createItem({
    resourceName: "unique-name"            # Stable identifier for this resource
    content: {                             # Full Kubernetes resource manifest
        apiVersion: "..."
        kind: "..."
        metadata: {name: "..."}
        spec: {...}
    }
    dependsOn: []                          # Wait for these items before creating
    conditionPropagation: a.defaultPropagation()
    statusDetails: {                       # Propagate fields back to composite status
        statusFunction: lambda item: sc.savedItem -> {str:any} {
            {fieldName: item.status?.atProvider?.value}
        }
    }
    connectionDetails: {                   # Expose connection data to consumer
        rawDataFunction: lambda item: sc.savedItem -> {str:str} {
            {"key": item.status?.atProvider?.value or ""}
        }
    }
})

# 4. Render — must be last
items = a.renderItems({})
```

Key patterns:

- **`dependsOn`** — Resources listed here must be ready before this resource is created. The framework automatically generates Crossplane `Usage` resources to enforce deletion order.
- **`statusDetails.statusFunction`** — Return a dict of fields to merge into the composite's `.status`. These appear as readable status fields on the consumer's claim.
- **`connectionDetails`** — Expose secrets or connection strings to the consumer's connection secret.
- **Conditional creation** — Use the `condition` field on `createItem` to skip a resource based on parameter values.

---

## What's Next?

- [Creating Solutions](../service-provider-guide/solutions/creating-solutions.md) — End-to-end guide to publishing a solution to the catalogue
- [Crossplane Compositions](../service-provider-guide/solutions/crossplane-compositions.md) — Advanced composition patterns
- [KCP Integration](kcp.md) — How the virtual API layer publishes your compositions to consumers
