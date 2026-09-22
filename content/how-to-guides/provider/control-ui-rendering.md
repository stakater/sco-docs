# How to Control Console UI Rendering

Shape how your resources appear in the SCO console — labels, inputs, ordering, grouping, visibility, and detail pages — by annotating your Crossplane Composition's OpenAPI schema.

Sam, a platform provider at ACME Corp, has published a new resource API. It works, but in the console it renders with raw field names in alphabetical order. Sam wants a polished form and detail page without changing any console code.

This guide picks up where [Creating Solutions](../../service-provider-guide/solutions/creating-solutions.md) leaves off, and uses the same `PostgreSQLDatabase` solution throughout.

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
"storageGb": {
  "type": "integer",
  "x-sco-ui-label": "Storage (GiB)"
}
```

## Order Fields

Field order comes from `x-sco-ui-order` — lower values render first:

```json
"dbName":    { "type": "string",  "x-sco-ui-order": "10" },
"version":   { "type": "string",  "x-sco-ui-order": "20" },
"storageGb": { "type": "integer", "x-sco-ui-order": "30" },
"instances": { "type": "integer", "x-sco-ui-order": "40" }
```

Count in tens rather than ones. The gaps let you slot a field in later — give it `"25"` — without renumbering every field after it.

!!! important
    A field with no `x-sco-ui-order` falls back to **alphabetical** order, *not* the order you wrote it in your schema file. Property order in a schema file is not carried through to the console, so writing `dbName` before `version` does not put it first. Tag every field whose position matters.

Untagged fields sort after tagged ones, alphabetically among themselves. Within one group, tag all the fields or none — a half-tagged group reads as arbitrary.

## Group Fields into Sections

Add `x-sco-ui-group` to collect related fields:

```json
"dbName":  { "type": "string", "x-sco-ui-group": "Database", "x-sco-ui-order": "10" },
"version": { "type": "string", "x-sco-ui-group": "Database", "x-sco-ui-order": "20" }
```

Fields without a group fall into a default `General` section on forms. A section takes its position from the lowest `x-sco-ui-order` among its fields, so number across groups, not within each one.

## Choose the Input

Override the inferred input with `x-sco-ui-component`:

```json
"version": {
  "type": "string",
  "enum": ["14", "15", "16"],
  "x-sco-ui-component": "radio"
}
```

See the reference for the full set of form and detail components.

## Hide a Field or Mark It Advanced

```json
"providerConfigsRef": { "type": "object",  "x-sco-ui-visibility": "hidden" },
"instances":          { "type": "integer", "x-sco-ui-complexity": "advanced" }
```

`hidden` removes the field entirely; `x-sco-ui-complexity: "advanced"` keeps it out of **Standard** mode but shows it in **Advanced** mode.

!!! tip
    The Kubernetes envelope (`apiVersion`, `kind`, `metadata`, `status`) and standard Crossplane plumbing fields are hidden automatically — you only need to hide your own internal fields.

## Tailor the Detail Page

Detail-page tags shadow the shared ones, so a field can look different on the form and the detail view:

```json
"endpoint": {
  "type": "string",
  "x-sco-ui-detail-component": "code"
}
```

`status` is the component to reach for when a field holds a phase or health value — it renders as a coloured badge.

At the schema **root**, `x-sco-ui` adds a summary strip, extra tabs, and actions to the detail page. See [Schema-Level Extension](../../service-provider-guide/console/ui-extensions-reference.md#schema-level-extension-x-sco-ui) in the reference.

## What's Next?

- [Console UI Extensions Reference](../../service-provider-guide/console/ui-extensions-reference.md) — Every tag, value, and rule
