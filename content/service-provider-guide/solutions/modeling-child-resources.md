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

The parent reference is declared in the child's `CompositeResourceDefinition` (XRD) — the same XRD that defines the claim API, as covered in [Creating Solutions](creating-solutions.md). Inside the XRD's `openAPIV3Schema` (which describes the claims consumers create, not a claim itself), each parent reference is an object under the claim's `spec.parameters`, holding the parent's name:

```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: openshiftnodepools.kubernetes.cloud.stakater.com
spec:
  scope: Namespaced
  group: kubernetes.cloud.stakater.com
  names:
    kind: OpenShiftNodePool
    plural: openshiftnodepools
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
              required:
                - parameters
              properties:
                parameters:
                  type: object
                  required:
                    - clusterRef
                  properties:
                    # The parent reference field — everything else in this
                    # XRD is the usual claim schema
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
      name: my-cluster    # the only thing the consumer supplies about the parent
    size: small
    replicas: 2
```

---

## Step 2: Tag the Field for Marketplace Discovery

Add the `x-sco-parent-ref` tag directly on the reference field's schema node from Step 1 (`spec.parameters.clusterRef` inside the XRD's `openAPIV3Schema`):

```yaml
clusterRef:
  type: object
  description: Reference to the OpenShiftCluster this pool belongs to
  x-sco-parent-ref:
    parentKinds:                # which kinds this slot accepts
      - apiVersion: kubernetes.cloud.stakater.com/v1
        kind: OpenShiftCluster
    statusPath: status.clusterRef    # where the verified reference lives (Step 3)
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

Still in the XRD's `openAPIV3Schema`, mirror the reference under the claim's `status` at `status.<role>Ref`. This is pure data, written by the child's composition on every reconcile — the discovery tag from Step 2 does not appear here:

```yaml
status:
  type: object
  properties:
    clusterRef:
      type: object
      description: Verified reference to the parent OpenShiftCluster
      properties:
        # Always written, on every reconcile
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
        # Written only once the parent has been observed
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

On the XRD version entry (alongside `schema`), add printer columns showing the claimed parent and its verification state at `kubectl get` time:

```yaml
additionalPrinterColumns:
  - name: Cluster                # the claimed parent (what the consumer asked for)
    type: string
    jsonPath: .spec.parameters.clusterRef.name
  - name: Verified               # whether that link is confirmed (Step 3)
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

The child's composition must observe the parent, gate its own resources on the parent being ready, and write the status block from Step 3 on every reconcile. The `stakater-common` KCL module packages all of this behind a single call, `parentRef`:

```kcl
import stakaterCommon as sc

oxr = option("params").oxr
ocds = option("params").ocds or {}
env = option("params").ctx["apiextensions.crossplane.io/environment"]

methods = sc.generateItemMethods(ocds)

spec = oxr.spec
parameters = spec.parameters or {}

kubernetesProviderConfigName = env?.providerConfigs?.kubernetes or "kubernetes-provider"

# Observe the parent and surface the verified reference
cluster = sc.parentRef({
    role: "cluster"                       # writes status.clusterRef
    namePrefix: oxr.metadata.name
    parentKind: "OpenShiftCluster"
    parentApiVersion: "kubernetes.cloud.stakater.com/v1"
    parentName: parameters.clusterRef.name
    defaultNamespace: oxr.metadata.namespace
    providerConfigRef: kubernetesProviderConfigName
    # What "ready" means for this parent kind (optional — defaults to
    # the parent's Available condition)
    readyCheck: lambda parent: any -> bool {
        _conds = parent?.status?.conditions or []
        len([c for c in _conds if c.type == "Available" and c.status == "True"]) > 0
    }
    # Parent fields the child needs downstream (optional)
    extract: {
        version: lambda parent: any -> str { parent?.status?.version or "" }
    }
    # Status to show on the child while the parent is not ready
    xrStatusOnWaiting: {
        ready: False
        phase: "WaitingForCluster"
        message: "Waiting for OpenShiftCluster '{}' to become Available".format(parameters.clusterRef.name)
    }
}, methods)

# Create the child's resources only once the parent is ready
nodePool = methods.createItem({
    condition: lambda _: {str:sc.savedItem} -> bool { cluster.ready }
    dependsOn: [cluster.item]
    resourceName: "{}-nodepool".format(oxr.metadata.name)
    content: {
        # ... the child's actual resources, free to use cluster.fields.version ...
    }
})

items = methods.renderItems({})
```

The one `parentRef` call gives you the whole contract:

- **An observer for the parent** with `managementPolicies: ["Observe"]` — the child never mutates or takes ownership of the parent.
- **A readiness gate** — `cluster.ready` and `cluster.item` for `condition`/`dependsOn` on dependent items, so nothing is provisioned against a parent that does not exist or is not ready.
- **The `status.<role>Ref` block from Step 3**, written on every reconcile: `name`/`kind`/`apiVersion`/`namespace` always, `uid`/`available` once the parent is observed, `message` while it is not.
- **Extracted parent fields** via `cluster.fields.<key>`.
- **A clear waiting state** — while the parent is not ready, the child's status shows the `xrStatusOnWaiting` block (e.g. `phase: WaitingForCluster`) instead of failing opaquely.

!!! note
    Compositions written with other pipeline functions (Go templates, Python, …) implement the same contract by hand: an Observe-only resource for the parent, a readiness gate on the child's resources, and the Step 3 status block written on every reconcile.

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
