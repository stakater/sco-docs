# Release Data Format

The release notes are also published as JSON, for tools and agents that plan or check an upgrade. This page defines the format.

## Files and URLs

All files are served from this site, next to the release notes:

| File | Content | Schema |
|------|---------|--------|
| [`release-notes/index.json`](index.json) | The list of releases | [`index.schema.json`](index.schema.json) |
| `release-notes/<id>.json` | One release. `<id>` is the release version, or `next-release` for the draft | [`release.schema.json`](release.schema.json) |

The schemas are JSON Schema draft-07. Under `https://docs.stakater.com/stakater-cloud-orchestrator/latest/` the files always reflect the latest version of this documentation. Paths inside the files (`notes`, `data`, `docs`) are relative to the file that contains them.

A release keeps its file name once it has a version. The draft `next-release.json` is renamed to `<version>.json` when the version is assigned.

## Conventions

- `version` is `null` while a version is not assigned or a component is not released yet. The prose shows it as **TBD**.
- `status` is `draft` (not released, can change), `released`, or `withdrawn` (do not install or upgrade to it).
- `date` is the release date as `YYYY-MM-DD`, or `null` for a draft.
- `schemaVersion` is `1`. A change that breaks readers of this format increases it.

## Release Index

| Field | Type | Description |
|-------|------|-------------|
| `schemaVersion` | integer | `1` |
| `product` | string | `Stakater Cloud Orchestrator` |
| `releases[]` | list | One entry per release, newest first |
| `releases[].id` | string | File name of the release, without `.json` |
| `releases[].version` | string or null | Platform release version |
| `releases[].status` | string | `draft`, `released` or `withdrawn` |
| `releases[].date` | string or null | Release date |
| `releases[].notes` | string | The release page |
| `releases[].data` | string | The release file |

## Release File

| Field | Type | Description |
|-------|------|-------------|
| `schemaVersion`, `id`, `version`, `status`, `date`, `notes` | | As in the index |
| `upgradePaths[]` | list | Releases you can upgrade from |
| `upgradePaths[].from` | string or null | Version to upgrade from; `null` when not known yet |
| `upgradePaths[].supported` | boolean | Whether the upgrade is supported |
| `upgradePaths[].notes` | string | Conditions, such as an intermediate release |
| `components[]` | list | Components this release adds, changes or removes |
| `components[].name` | string | Component name, as it appears on the cluster or in the registry |
| `components[].type` | string | `crossplane-package`, `helm-chart`, `container-image` or `cli` |
| `components[].version` | string or null | Version in this release |
| `components[].change` | string | `added`, `changed`, `deprecated` or `removed` |
| `components[].summary` | string | What changes |
| `breakingChanges[]` | list | Changes that need action; see [What Counts as Breaking](versioning.md#what-counts-as-breaking) |
| `breakingChanges[].id` | string | Stable identifier |
| `breakingChanges[].title` | string | One line |
| `breakingChanges[].affects` | string | Which objects or settings are affected |
| `breakingChanges[].impact` | string | What happens to them |
| `breakingChanges[].before[]` | list of string | Actions before the upgrade, in order |
| `breakingChanges[].after[]` | list of string | Actions and checks after the upgrade, in order |
| `breakingChanges[].docs` | string | Section of the release page with commands |
| `interfaceChanges[]` | list | Changes to APIs and configuration interfaces |
| `interfaceChanges[].interface` | string | API group, version, kind and field, or chart and configuration key |
| `interfaceChanges[].type` | string | `api`, `configuration`, `console`, `rbac` or `admission` |
| `interfaceChanges[].change` | string | `added`, `changed`, `deprecated` or `removed` |
| `interfaceChanges[].breaking` | boolean | Whether it is a breaking change |
| `interfaceChanges[].summary` | string | What changes |
| `interfaceChanges[].docs` | string | Reference page |
| `features[]` | list | `title`, `summary`, `docs` |
| `fixes[]` | list | `component`, `summary` |
| `knownIssues[]` | list | `summary`, `workaround` |

## Example

List the breaking changes of every release that is not a draft:

```bash
BASE=https://docs.stakater.com/stakater-cloud-orchestrator/latest/release-notes
curl -s "$BASE/index.json" | jq -r '.releases[] | select(.status == "released") | .data' |
  while read -r f; do curl -s "$BASE/$f" | jq '{version, breakingChanges}'; done
```
