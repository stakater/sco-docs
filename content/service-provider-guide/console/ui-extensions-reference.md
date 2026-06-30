# Console UI Extensions Reference

The SCO console is schema-driven: it builds resource lists, detail pages, and create/edit forms directly from each resource's OpenAPI schema. The `x-sco-ui-*` extensions documented here let you, as a platform provider, control that rendering by annotating the schema — no console code changes required.

Add the extensions to the schema your API exposes. Resources without `x-sco-ui-*` extensions still render, using sensible defaults inferred from the schema type.

For a task-oriented introduction, see [Controlling Console UI Rendering](../../how-to-guides/provider/control-ui-rendering.md).

---

## How a Tag Resolves

For any property, the console resolves each setting through a chain, most specific first:

```text
x-sco-ui-<view>-*   →   x-sco-ui-*   →   schema type inference
```

`<view>` is `detail` (the detail page) or `form` (create/edit forms). A view-specific tag shadows the shared tag, which in turn overrides what the console would infer from the property's type. This lets you, for example, show a field one way on a form and another way on the detail page.

---

## Property-Level Extensions

Set these on individual schema **properties**.

| Tag | Values | Effect |
|-----|--------|--------|
| `x-sco-ui-label` | Free text | Field label. Defaults to a title-cased property name. |
| `x-sco-ui-order` | Integer string (e.g. `"10"`) | Sort order within a group; lower first. Unset sorts last. |
| `x-sco-ui-group` | Free text | Groups fields into a named section. Fields without a group fall into `General` (forms) / `Details` (detail). |
| `x-sco-ui-component` | See below | Overrides the input (forms) or display (detail) component. |
| `x-sco-ui-visibility` | `hidden`, `inline`, `readonly`, `hide-if-null` | Controls whether and how the field shows. See [Visibility](#visibility). |
| `x-sco-ui-complexity` | `advanced` | Hides the field in **Standard** mode; shows it in **Advanced** mode. |
| `x-sco-value-encoding` | `base64` | The user edits plain text; the console encodes on save and decodes on load. |
| `x-sco-value-type` | `enum` | The field's options come from the platform's value catalogue rather than a schema `enum`. Renders as a select. |

### `x-sco-ui-component` values

**Forms:** `input`, `text`, `textarea`, `number`, `switch`, `checkbox`, `select`, `radio`, `select-detail`, `select-table`.

**Detail page:** `text`, `boolean`, `status`, `time`, `code`, `link`, `json`.

If the value isn't valid for the view, the console falls back to type inference.

### Visibility

| Value | Behaviour |
|-------|-----------|
| `hidden` | Field is omitted entirely. |
| `inline` | For objects: the wrapper is dropped and its child fields render at the parent level (paths are preserved). |
| `readonly` | **Forms only** — shown as read-only text, skipped by validation. |
| `hide-if-null` | **Detail only** — field is hidden when its value is empty (`null`, `""`, `0`, `false`, empty array/object). |

---

## Detail-Page Overrides

Each of these shadows its shared counterpart **on the detail page only**, then falls back to the shared tag, then to inference.

| Tag | Falls back to |
|-----|---------------|
| `x-sco-ui-detail-visibility` | `x-sco-ui-visibility` |
| `x-sco-ui-detail-component` | `x-sco-ui-component` |
| `x-sco-ui-detail-label` | `x-sco-ui-label` |
| `x-sco-ui-detail-order` | `x-sco-ui-order` |
| `x-sco-ui-detail-group` | `x-sco-ui-group` |
| `x-sco-ui-detail-complexity` | `x-sco-ui-complexity` |

`x-sco-ui-detail-visibility` accepts `hidden`, `inline`, and `hide-if-null` (not `readonly`). `x-sco-ui-detail-component` accepts the detail-page component values listed above.

---

## Schema-Level Extension: `x-sco-ui`

Set `x-sco-ui` on the **root** of a resource schema to shape its detail page beyond the field list.

| Field | Purpose |
|-------|---------|
| `detailSummaryFields` | A strip of key facts shown above the detail content. |
| `detailTabs` | Extra tabs on the detail page (for example, related resources). |
| `relations` | Definitions of related-resource lists that tabs and actions reference. |
| `actions` | Buttons on the detail page (header or row), with optional confirmation and forms. |

### `detailSummaryFields`

```json
"detailSummaryFields": [
  { "label": "Instance type", "path": "spec.parameters.instanceType" },
  { "label": "Status", "path": "status.vm.printableStatus" }
]
```

Each entry is a `label` and a dot-`path` into the resource.

### `detailTabs` and `relations`

```json
"detailTabs": [
  { "id": "storage", "label": "Storage", "type": "relatedList", "relation": "volumes" }
],
"relations": [
  {
    "id": "volumes",
    "columns": [
      { "label": "Volume", "path": "name" },
      { "label": "State", "path": "state" }
    ],
    "emptyState": { "title": "No volumes", "description": "Attach a volume to get started." }
  }
]
```

A tab of `type: relatedList` renders the `relation` with the matching `id` as a table.

### `actions`

```json
"actions": [
  { "id": "start", "label": "Start", "icon": "Play", "surface": "header",
    "when": { "path": "status.ready", "equals": false } },
  { "id": "stop", "label": "Stop", "icon": "Square", "surface": "header",
    "when": { "path": "status.ready", "equals": true },
    "confirm": { "title": "Stop virtual machine?", "message": "The VM will be powered off.", "confirmLabel": "Stop" } }
]
```

| Field | Purpose |
|-------|---------|
| `surface` | Where the button appears: `header`, `tab`, or `row`. |
| `when` | Show the action only when a `path` `equals` a value. |
| `confirm` | Require confirmation, with a `title`, `message`, and `confirmLabel`. |
| `form` | Collect input before running the action (`presentation`, `title`, `submitLabel`, `schema`). |

---

## Automatic Behaviour

Even without tags, the console applies these rules.

### Hidden fields

The Kubernetes envelope (`apiVersion`, `kind`, `metadata`, `status`) is hidden from forms, and standard Crossplane composition plumbing fields are hidden as well. Promote what matters with explicit tags.

### Type inference

When no component is set, the console infers one:

| Schema | Form | Detail |
|--------|------|--------|
| Has `enum` (or `x-sco-value-type: enum`) | `select` | text |
| `string` with `maxLength` > 200 | `textarea` | text |
| `string` (name suggests status) | text | `status` |
| `string` with `format: date-time` | text | `time` |
| `string` with `format: uri` | text | `link` |
| `boolean` | toggle | `boolean` |
| `integer` / `number` | `number` | text |
| `object` without properties / `array` | nested editor | `json` |

### Status colours

Status badges are coloured by convention (case-insensitive): `ready`/`running`/`active`/`available`/`healthy` → green; `pending`/`provisioning`/`waiting`/`unknown` → amber; `failed`/`error`/`terminated` → red; anything else → grey.

---

## Examples

Relabel a field and make it a dropdown:

```json
"size": {
  "type": "string",
  "enum": ["100Gi", "200Gi", "300Gi"],
  "x-sco-ui-label": "Capacity"
}
```

Flatten a wrapper object so its fields render at the parent level:

```json
"crossplane": {
  "type": "object",
  "x-sco-ui-visibility": "inline",
  "properties": {
    "region": { "type": "string" },
    "replicas": { "type": "integer" }
  }
}
```

Store a secret as base64 while the user edits plain text:

```json
"kubeconfig": {
  "type": "string",
  "x-sco-ui-component": "textarea",
  "x-sco-value-encoding": "base64"
}
```

---

## Work in Progress

!!! note
    These extensions are still evolving. Expect new tags and values to be added over time — treat this reference as the current state rather than the final set.

---

## What's Next?

- [Controlling Console UI Rendering](../../how-to-guides/provider/control-ui-rendering.md) — Task-oriented guide
- [Console Overview](../../console/overview.md) — How consumers experience the console
