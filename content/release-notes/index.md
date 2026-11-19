# Release Notes

What changes in each release of Stakater Cloud Orchestrator (SCO), and what you have to do when you upgrade.

Release notes are keyed by the **platform release version**. This documentation site has its own version (shown in the header), which moves separately: one version of the docs carries the notes of every platform release.

## Releases

| Release | Status | Date | Notes | Data |
|---------|--------|------|-------|------|
| Next release | Draft, not released | — | [Next release (unreleased)](next-release.md) | [`next-release.json`](next-release.json) |

A draft describes changes that are merged but not yet released. Do not plan an upgrade from it: its content and its component versions can still change. When the version is assigned, the page and its JSON file are renamed to that version.

## What Each Release Page Contains

1. **Component versions** — every component the release changes, with its version, and the platform releases you can upgrade from
1. **Breaking changes** — what stops working, the action required before and after the upgrade, and migration steps
1. **Configuration and API changes** — configuration interfaces and APIs added, changed, deprecated or removed
1. **New features and fixes**
1. **Known issues** — with workarounds

How versions move, and what counts as a breaking change, is defined in the [Versioning Policy](versioning.md).

## Machine-Readable Release Data

Every release page has a JSON file with the same content, for tools and agents:

- [`index.json`](index.json) — the list of releases
- one file per release, linked from the table above

The format is defined in [Release Data Format](release-data.md). The files are also listed in the site's [`llms.txt`](../llms.txt).
