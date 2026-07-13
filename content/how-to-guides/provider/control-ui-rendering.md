# How to Control Console UI Rendering

Shape how your resources appear in the SCO console — labels, inputs, ordering, grouping, visibility, and detail pages — by annotating your Crossplane Composition's OpenAPI schema.

Sam, a platform provider at ACME Corp, has published a new resource API. It works, but in the console it renders with raw field names in schema order. Sam wants a polished form and detail page without changing any console code.

## Prerequisites

- A resource whose schema the platform serves to the console
- The ability to edit the properties in that schema

## How It Works

The console renders each resource from its schema. For every property it resolves the most specific hint first:

```text
x-sco-ui-<view>-*   →   x-sco-ui-*   →   schema type inference
```

So you add `x-sco-ui-*` keys to your schema, and the console adjusts. Resources with no hints still render, using defaults inferred from the schema type. The full list of tags and values is in the [Console UI Extensions Reference](../../service-provider-guide/console/ui-extensions-reference.md).

## Rename a Field

Give a field a human-readable label instead of its property name:

```json
"replicas": {
  "type": "integer",
  "x-sco-ui-label": "Node Count"
}
```

## Order and Group Fields

Put related fields into sections and control their order (lower `x-sco-ui-order` first):

```json
"network": { "type": "string", "x-sco-ui-group": "Networking", "x-sco-ui-order": "1" },
"subnet":  { "type": "string", "x-sco-ui-group": "Networking", "x-sco-ui-order": "2" }
```

Fields without a group fall into a default `General` section on forms.

## Choose the Input

Override the inferred input with `x-sco-ui-component`:

```json
"tier": {
  "type": "string",
  "enum": ["small", "medium", "large"],
  "x-sco-ui-component": "radio"
}
```

See the reference for the full set of form and detail components.

## Hide a Field or Mark It Advanced

```json
"internalId": { "type": "string", "x-sco-ui-visibility": "hidden" },
"tuning":     { "type": "object", "x-sco-ui-complexity": "advanced" }
```

`hidden` removes the field entirely; `x-sco-ui-complexity: "advanced"` keeps it out of **Standard** mode but shows it in **Advanced** mode.

!!! tip
    The Kubernetes envelope (`apiVersion`, `kind`, `metadata`, `status`) and standard Crossplane plumbing fields are hidden automatically — you only need to hide your own internal fields.

## Tailor the Detail Page

Detail-page tags shadow the shared ones, so a field can look different on the form and the detail view:

```json
"phase": {
  "type": "string",
  "x-sco-ui-detail-component": "status"
}
```

At the schema **root**, `x-sco-ui` adds a summary strip, extra tabs, and actions to the detail page. See [Schema-Level Extension](../../service-provider-guide/console/ui-extensions-reference.md#schema-level-extension-x-sco-ui) in the reference.

## What's Next?

- [Console UI Extensions Reference](../../service-provider-guide/console/ui-extensions-reference.md) — Every tag, value, and rule
