# Modelling Child Resources

Some solutions are not a single resource but a family of related ones: an OpenShift cluster and its node pools, a database instance and its logical databases. This guide shows how to model the child as its own claim kind — a child resource — that holds a verified reference to its parent claim.

The examples use the platform's `OpenShiftNodePool`, a child resource of `OpenShiftCluster`, as the running example. The same contract applies to any parent/child pair.

---

## Prerequisites

- A parent solution already exists (XRD and Composition) — see [Creating Solutions](creating-solutions.md)
- Familiarity with [Crossplane Compositions](crossplane-compositions.md) authoring patterns

---

## When to Model a Child Resource

A child resource is a claim kind in its own right: it has its own top-level API, appears as its own resource in the console, and is managed independently of its parent. Model a child as its own claim kind when:

- **It is a resource in its own right** — consumers should see and manage it as its own object in the console, not as a field buried in the parent's spec
- **Independent lifecycle** — consumers create, resize, and delete children without touching the parent (e.g. adding a node pool to a running cluster)
- **Variable cardinality** — one parent has many children, and the number is not known when the parent is created
- **Separate ownership** — different people manage the parent and the children

A child that is created alongside its parent by default can still be a child resource — being created together does not make something part of the parent. What matters is whether it stands on its own as a resource afterwards.

Do **not** model a child resource when:

- **It is plain configuration of the parent** — a setting with no identity or lifecycle of its own belongs in the parent's spec

!!! note
    A parent reference gives you a *verified link*, not cascade deletion. Deleting a parent claim does not delete its children — they remain, with `status.<role>Ref.available: false` and a message explaining why. If you need cascade deletion, that is a separate concern to solve outside this contract.

---

## The Parent Reference Contract

A child resource declares its parent relationship in four places, all on the **child** solution:

1. **A reference field** in the child's spec — `spec.parameters.<role>Ref`, where `<role>` names the relationship (`clusterRef`, `networkRef`, …)
1. **A discovery tag** (`x-sco-parent-ref`) on that field, so the marketplace and console can render the relationship
1. **A verified status block** at `status.<role>Ref`, written by the child's composition on every reconcile
1. **Printer columns** showing the claimed parent and its verification state at `kubectl get` time

The parent solution needs no changes.

---

## Step 1: Add the Reference Field to the Child XRD

Each parent reference is an object under `spec.parameters`, holding the parent's name:

```yaml
spec:
  parameters:
    type: object
    required:
      - clusterRef
    properties:
      clusterRef:
        type: object
        description: Reference to the OpenShiftCluster this pool belongs to
        required:
          - name
        properties:
          name:
            type: string
            minLength: 1
            maxLength: 63
            description: Name of the OpenShiftCluster in the same project
```

Conventions:

- `name` is required and always declared.
- The parent is resolved **in the same project** as the child claim.
- `kind` and `apiVersion` are deliberately **not** part of the spec — they are fixed by the solution and declared in the discovery tag (Step 2). Consumers only ever supply a name.

The consumer's claim then looks like:

```yaml
apiVersion: kubernetes.cloud.stakater.com/v1
kind: OpenShiftNodePool
metadata:
  name: my-cluster-workers
spec:
  parameters:
    clusterRef:
      name: my-cluster
    size: small
    replicas: 2
```

---

## Step 2: Tag the Field for Marketplace Discovery

Add the `x-sco-parent-ref` tag directly on the reference field in the child XRD:

```yaml
clusterRef:
  type: object
  description: Reference to the OpenShiftCluster this pool belongs to
  x-sco-parent-ref:
    parentKinds:
      - apiVersion: kubernetes.cloud.stakater.com/v1
        kind: OpenShiftCluster
    statusPath: status.clusterRef
  required:
    - name
  properties:
    name:
      type: string
```

The platform reads this tag straight off the XRD — there is no build step or separate artifact to maintain. It drives:

| Consumer experience | Driven by |
|---------------------|-----------|
| Create forms render a parent picker instead of a free-text field | `parentKinds` |
| Instance views link to the verified parent | `statusPath` |
| Reverse discovery ("list the node pools of this cluster") | The tag's location in the schema — `<field>.name` is the identifier path |

The tag only carries what cannot be deduced: the accepted parent kinds, and the cross-reference to the status block. Everything else follows from where the tag sits in the schema.

!!! tip
    `parentKinds` is a list. A slot that accepts several parent kinds lists them all; the resolved kind for a specific instance is read from the status block (`status.<role>Ref.kind`) at runtime.

---

## Step 3: Declare the Verified Status Block

Mirror the reference at `status.<role>Ref`. This is pure data, written by the child's composition on every reconcile — the discovery tag from Step 2 does not appear here:

```yaml
status:
  type: object
  properties:
    clusterRef:
      type: object
      description: Verified reference to the parent OpenShiftCluster
      properties:
        name:
          type: string
          description: Name of the parent
        kind:
          type: string
          description: Kind of the parent
        apiVersion:
          type: string
          description: ApiVersion of the parent
        namespace:
          type: string
          description: Namespace of the parent
        uid:
          type: string
          description: Observed UID of the parent (survives rename)
        available:
          type: boolean
          description: Whether the parent is currently available
        message:
          type: string
          description: Human-readable status when not available
```

| Field | Written |
|-------|---------|
| `name`, `kind`, `apiVersion`, `namespace` | On every reconcile — the block is self-describing from the first reconcile |
| `uid`, `available` | Once the parent has been observed |
| `message` | While the parent is not available, explaining why |

The `uid` records *which* parent instance was observed, so the link survives a parent being renamed or recreated. A typo in `clusterRef.name` is machine-detectable: `available` stays `false` and `message` says the parent was not found.

---

## Step 4: Add Printer Columns

Show the claimed parent and its verification state at `kubectl get` time:

```yaml
additionalPrinterColumns:
  - name: Cluster
    type: string
    jsonPath: .spec.parameters.clusterRef.name
  - name: Verified
    type: boolean
    jsonPath: .status.clusterRef.available
  - name: Phase
    type: string
    jsonPath: .status.phase
```

```console
$ kubectl get openshiftnodepools
NAME                 CLUSTER      VERIFIED   PHASE
my-cluster-workers   my-cluster   true       Ready
staging-workers      staging      false      WaitingForCluster
```

---

## Step 5: Implement the Parent Watch in the Composition

The child's composition observes the parent, gates its own resources on the parent being ready, and writes the status block. The pattern in KCL (`function-kcl`):

```kcl
oxr = option("params").oxr
ocds = option("params").ocds
parameters = oxr.spec.parameters

_parentName = parameters.clusterRef.name
_parentNamespace = oxr.metadata.namespace

# 1. Observe the parent — never manage it
_parentObserver = {
    apiVersion: "kubernetes.crossplane.io/v1alpha2"
    kind: "Object"
    metadata: {
        name: "{}-cluster".format(oxr.metadata.name)
        annotations: {"krm.kcl.dev/composition-resource-name": "cluster-observer"}
    }
    spec: {
        managementPolicies: ["Observe"]
        providerConfigRef: {name: kubernetesProvider}
        forProvider: {
            manifest: {
                apiVersion: "kubernetes.cloud.stakater.com/v1"
                kind: "OpenShiftCluster"
                metadata: {name: _parentName, namespace: _parentNamespace}
            }
        }
    }
}

# 2. Read what the observer saw on the previous reconcile
_parent = ocds?.["cluster-observer"]?.Resource?.status?.atProvider?.manifest
_conditions = _parent?.status?.conditions or []
_parentAvailable = len([c for c in _conditions if c.type == "Available" and c.status == "True"]) > 0

# 3. Build the verified reference — written on every reconcile
_clusterRef = {
    name: _parentName
    namespace: _parentNamespace
    kind: "OpenShiftCluster"
    apiVersion: "kubernetes.cloud.stakater.com/v1"
} | ({
    uid: _parent?.metadata?.uid
    available: True
} if _parentAvailable else {
    available: False
    message: "Waiting for OpenShiftCluster {} to become available".format(_parentName)
})

# 4. Extract parent fields the child needs
_releaseImage = _parent?.spec?.release?.image or ""

# 5. Create the child's resources only once the parent is available
_nodePool = [
    {
        # ... the child's actual resources, free to use _releaseImage ...
    }
] if _parentAvailable else []

# 6. Write status back to the composite
_xrPatch = {
    apiVersion: oxr.apiVersion
    kind: oxr.kind
    metadata: {name: oxr.metadata.name}
    status: {
        clusterRef: _clusterRef
        phase: "Creating" if _parentAvailable else "WaitingForCluster"
        ready: False
        message: "NodePool {} is creating".format(oxr.metadata.name) if _parentAvailable else "Waiting for cluster {}".format(_parentName)
    }
}

items = [_parentObserver] + _nodePool + [_xrPatch]
```

The key behaviours:

- **The observer uses `managementPolicies: ["Observe"]`** — the child never mutates or takes ownership of the parent.
- **The status block is written on every reconcile**, whether or not the parent is available, so consumers and the console always see the current link state.
- **Child resources are gated** on `_parentAvailable` — nothing is provisioned against a parent that does not exist or is not ready, and the claim reports a clear `WaitingForCluster` phase instead of failing opaquely.
- **Adapt the readiness check to the parent kind** — condition types and readiness signals differ per solution.

---

## Step 6: Verify

Create the child **before** its parent exists, and confirm it waits rather than fails:

```bash
kubectl apply -f nodepool-claim.yaml
kubectl get openshiftnodepool my-cluster-workers
```

```console
NAME                 CLUSTER      VERIFIED   PHASE
my-cluster-workers   my-cluster   false      WaitingForCluster
```

Then create the parent and watch the child verify the link and start provisioning:

```console
NAME                 CLUSTER      VERIFIED   PHASE
my-cluster-workers   my-cluster   true       Creating
```

Inspect the verified reference on the child's status:

```bash
kubectl get openshiftnodepool my-cluster-workers -o jsonpath='{.status.clusterRef}' | jq
```

```json
{
  "name": "my-cluster",
  "kind": "OpenShiftCluster",
  "apiVersion": "kubernetes.cloud.stakater.com/v1",
  "namespace": "my-project",
  "uid": "8f9a2c3e-...",
  "available": true
}
```

Finally, verify the broken-link behaviour: point a child at a parent name that does not exist and confirm `Verified` stays `false` with an explanatory `message`.

---

## What's Next?

- [Creating Solutions](creating-solutions.md) — Define the XRD and Composition for a new solution
- [Crossplane Compositions](crossplane-compositions.md) — Advanced composition patterns and KCL functions
- [Publishing Solutions](../marketplace/publishing-solutions.md) — Make your solution available in the marketplace
