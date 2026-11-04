# Modelling Related Resources

Some claims name other claims they use without owning them: a virtual machine attaches existing volumes, a group lists its member users, a project grants access to groups. This guide shows how to tag such a field so the console lists the named resources on the detail page of the claim that names them.

The examples use the platform's `VirtualMachine`, which attaches existing `VirtualMachineVolume` claims, as the running example. The same contract applies to any claim kind that names another.

---

## Prerequisites

- A solution already exists (its CompositeResourceDefinition, or XRD, and its Composition) — see [Creating Solutions](creating-solutions.md)
- The claim kind being referenced (the **target**) is available in the same project

---

## Related Resource or Child Resource?

Both patterns link two claim kinds. They differ in which side holds the pointer:

| | Child resource | Related resource |
|---|---|---|
| Who holds the reference | The child names its one parent | The claim names any number of targets |
| Can several claims name the same target? | No, a child has one parent | Yes, several VMs may attach the same volume |
| Tag | `x-sco-parent-ref` on the child | `x-sco-related-ref` on the claim naming the target |
| Target changes needed | None | None |
| Verified status block and readiness gate | Yes | No, the tag is discovery only |
| Console tab appears on | The parent's detail page | The detail page of the claim holding the tag |

Use a related reference when:

- **The target stands on its own** — it is created and managed independently, and is not a child of the claim that names it
- **The target holds no reference back** — a volume does not record which VMs attach it, so only the VM knows the link
- **The link is many-to-many** — several claims may name the same target

Model a [child resource](modeling-child-resources.md) instead when the child belongs to exactly one parent and must wait for that parent before it provisions.

!!! note
    A related reference is discovery only. The tag does not verify that the target exists or gate provisioning on it. If the composition needs the target to exist before it provisions, it must check for it itself.

---

## The Related Reference Contract

A related reference lives in one place, on the **referencing** solution:

1. **A reference field** in the claim's spec holding the target's name, or a list of names
1. **A discovery tag** (`x-sco-related-ref`) on that field, naming the target kinds

The target solution needs no changes.

---

## Step 1: Add the Reference Field

The reference is an ordinary field under the claim's `spec.parameters`, declared in the XRD's `openAPIV3Schema`. `VirtualMachine` lists its extra disks under `additionalVolumes`, and a persistent disk names an existing volume in `volume`:

```yaml
additionalVolumes:
  type: array
  description: Additional disks to attach to the VM.
  items:
    type: object
    properties:
      name:
        type: string
        description: Disk name within the VM (e.g. data1).
      type:
        type: string
        default: persistent
        enum: ["persistent", "ephemeral", "container"]
      volume:
        type: string
        description: Name of an existing VirtualMachineVolume in your project to attach (persistent disks).
      size:
        type: string
        description: Size of the scratch disk, e.g. 10Gi (ephemeral disks).
      # image and bus trimmed
    required:
      - name
```

The consumer's claim then looks like:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachine
metadata:
  name: data-vm
spec:
  parameters:
    flavour: rhel9
    instanceType: o1.small
    additionalVolumes:
      - name: data1
        type: persistent
        volume: data-vm-data1    # names a VirtualMachineVolume
      - name: data2
        type: persistent
        volume: data-vm-data2
      - name: scratch
        type: ephemeral          # names no volume
        size: 20Gi
```

Conventions:

- The target is resolved **in the same project** as the claim.
- `kind` and `apiVersion` are **not** part of the spec. They are fixed by the solution and declared in the tag (Step 2). Consumers only ever supply a name.

---

## Step 2: Tag the Field for Console Discovery

Add the `x-sco-related-ref` tag on the schema node that holds the name:

```yaml
volume:
  type: string
  description: Name of an existing VirtualMachineVolume in your project to attach (persistent disks).
  x-sco-related-ref:
    relatedKinds:               # which kinds this field names
      - apiVersion: compute.cloud.stakater.com/v1
        kind: VirtualMachineVolume
```

The platform reads this tag straight off the XRD — there is no build step or separate artifact to maintain.

| Key | Required | Description |
|-----|----------|-------------|
| `relatedKinds` | Yes | The kinds this field names, as `{ apiVersion, kind }`. List several when the field accepts more than one kind. |
| `selector.name` | No | Dot path on the claim holding the name(s), overriding the path derived from where the tag sits. |
| `selector.targetName` | No | Dot path on the **target** holding the value the names refer to. Defaults to `metadata.name`. See [Step 3](#step-3-match-on-something-other-than-the-object-name). |

### Where the name is read from

The tag carries no path by default. The console derives it from where the tag sits:

| Tagged field | Name read from | Example |
|--------------|----------------|---------|
| `type: string` | The field itself | `volume: data-vm-data1` |
| Array of strings (`items.type: string`) | Every entry | `members: [alice@example.com, bob@example.com]` |
| Anything else | `<field>.name` | `storageRef: { name: data-vm-data1 }` |

Fields inside arrays need no index or wildcard: a tag on `additionalVolumes[].volume` reads the `volume` of every entry. Entries without the field are skipped, so the ephemeral disk above contributes nothing.

!!! tip
    Always declare `type: string` on a field that holds a name. Without it the console assumes an object reference and reads `<field>.name`, finds nothing, and shows no tab.

---

## Step 3: Match on Something Other Than the Object Name

By default each name is matched against the target's `metadata.name`. When the field holds another identifier, such as an email address or a display name, set `selector.targetName` to the path on the target that holds it.

For example, if a `Group` listed its members by email, its tag would match each name against the email a `User` claim carries in `spec.parameters.email`:

```yaml
members:
  type: array
  items:
    type: string
  x-sco-related-ref:
    relatedKinds:
      - apiVersion: iam.cloud.stakater.com/v1
        kind: User
    selector:
      targetName: spec.parameters.email
```

!!! note
    Without `targetName` here, the tab renders but lists nothing, because no `User` is named after an email address.

---

## Step 4: Verify

Create two blank volumes for the VM from Step 1 to attach. Each is a `VirtualMachineVolume` claim:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachineVolume
metadata:
  name: data-vm-data1
spec:
  parameters:
    storageSize: large
```

Save it as `data-vm-data1.yaml`, and a copy named `data-vm-data2` as `data-vm-data2.yaml`. Save the `data-vm` claim from Step 1 as `data-vm.yaml`, then apply all three:

```bash
kubectl apply -f data-vm-data1.yaml -f data-vm-data2.yaml -f data-vm.yaml
```

Open `data-vm` in the console. Its detail page shows a **Virtual Machine Volumes** tab listing `data-vm-data1` and `data-vm-data2`.

Then check the edge cases:

1. Delete `data-vm-data2`. The tab stays and lists only `data-vm-data1`.
1. Create a VM with only ephemeral disks. It has no volumes tab.

---

## What Consumers See

On the detail page of the claim holding the tag, the console adds one tab per tagged field, listing the named targets in the claim's project.

| Situation | Console behaviour |
|-----------|-------------------|
| The claim names nothing (no persistent disks) | No tab |
| A name matches no object (a typo, or a deleted volume) | The tab shows, with that name missing from the list — a broken reference stays visible |
| Several fields name the same kind (a rule's source and destination groups) | One tab per field, labelled by field name ("Source Group Names") instead of the kind |
| The target kind is not available in the project | No tab |
| The viewer may not list the target kind | No tab |

A related tab offers neither create nor delete. Creating a target would not attach it to the claim, and deleting one would remove an object other claims may still name. Consumers change the link by editing the claim itself.

!!! tip
    Because a tag naming an unavailable kind produces no tab, you can tag a field before the target solution is published. The tab appears once the target kind is available.

---

## What's Next?

- [Modelling Child Resources](modeling-child-resources.md) — Model a child that belongs to one parent, with a verified link
- [Console UI Extensions Reference](../console/ui-extensions-reference.md) — Every tag that shapes how a solution renders in the console
- [Creating Solutions](creating-solutions.md) — Define the XRD and Composition for a new solution
