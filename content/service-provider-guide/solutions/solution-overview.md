# Solutions

A **solution** is any service that a platform provider has defined and published to the SCO catalogue. Consumers discover solutions in the marketplace and provision instances of them using standard Kubernetes claims.

---

## What a Solution Is

At its core, a solution is a Kubernetes custom resource type — defined by a `CompositeResourceDefinition` (XRD) — that abstracts the provisioning of one or more infrastructure resources. Providers write the XRD to define the API shape (what parameters consumers configure) and write a Composition to implement it (what actually gets created underneath).

A solution might represent:

- A virtual machine with configurable OS, instance size, storage, and networking
- A hosted OpenShift cluster with configurable compute and node pools
- A PostgreSQL database with configurable version, storage, and backup
- A Kafka cluster with configurable broker count and topic retention
- Any infrastructure primitive or combination of primitives your organisation needs to offer

From the consumer's perspective, all solutions work identically: apply a claim YAML, wait for `Ready`, and use the provisioned service.

---

## Built-in Solutions

SCO ships with two flagship solutions:

### Virtual Machine

**API:** `compute.cloud.stakater.com/v1 VirtualMachine`

Provisions Linux virtual machines using OpenShift Virtualization. Consumers configure instance type, OS image, storage size, networking mode, and an SSH public key. The VM is accessible within minutes.

### OpenShift Cluster

**API:** `kubernetes.cloud.stakater.com/v1 OpenShiftCluster`

Provisions full OpenShift clusters using hosted control planes. Consumers configure cluster name, compute resources, node pool size, and optionally the OpenShift version. The cluster is fully functional with its own kubeconfig.

---

## Custom Solutions

Platform providers can publish any additional solution alongside the built-in offerings. Custom solutions appear in the same catalogue and follow the same claim-based provisioning model.

Examples of custom solutions providers typically add:

| Solution type | Backing operator | API group |
|---------------|-----------------|-----------|
| PostgreSQL database | CloudNativePG | `databases.cloud.stakater.com` |
| Kafka cluster | Strimzi | `messaging.cloud.stakater.com` |
| Redis instance | Redis Operator | `caching.cloud.stakater.com` |
| AI/ML workspace | OpenShift AI | `ai.cloud.stakater.com` |
| S3-compatible storage | Rook/Ceph or cloud provider | `storage.cloud.stakater.com` |

There is no constraint on what API group, kind, or parameters a custom solution uses — providers define the API and implementation entirely.

---

## Solution Anatomy

Every solution consists of:

| Component | Role |
|-----------|------|
| `CompositeResourceDefinition` (XRD) | Defines the claim API: schema, validation, versioning |
| `Composition` | Implements the claim: what resources to create, using which providers |
| `ApiExport` claim | Publishes the API to consumer project workspaces |
| Marketplace metadata | Display name, description, documentation — shown in the catalogue |

The XRD and Composition live on the management cluster. The `ApiExport` claim triggers the api-syncagent to bridge the API into KCP workspaces. Marketplace metadata controls how the solution appears to consumers.

---

## Solution Lifecycle

```text
Provider defines XRD + Composition
          ↓
Provider applies ApiExport claim
          ↓
Solution appears in consumer project workspaces
          ↓
Consumer applies a claim
          ↓
Composition pipeline provisions infrastructure
          ↓
Claim status → Ready
          ↓
Consumer updates claim → Composition reconciles
          ↓
Consumer deletes claim → Composition tears down
```

The composition engine handles the full lifecycle. Providers write the composition once; Crossplane manages all subsequent reconciliation, updates, and deletions.

---

## What's Next?

- [Creating Solutions](creating-solutions.md) — Write your first XRD and Composition
- [Crossplane Compositions](crossplane-compositions.md) — Composition patterns and KCL functions
- [Publishing APIs](../api-publishing/publishing-apis.md) — Expose your solution to consumer projects
- [Crossplane Integration](../../integrations/crossplane.md) — Provider setup and composition reference
