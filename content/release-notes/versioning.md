# Versioning Policy

!!! note "Proposed"
    This policy is a proposal under review. Releases made before it is adopted do not follow it.

SCO uses [semantic versioning](https://semver.org/) for the platform release and for every platform package: Helm charts, Crossplane packages and the console.

## Package Versions

| Package version | Breaking change | New feature | Fix |
|-----------------|-----------------|-------------|-----|
| `0.x.y` (most packages today) | minor (`0.4.2` → `0.5.0`) | patch (`0.4.2` → `0.4.3`) | patch |
| `1.0.0` and later | major (`1.4.2` → `2.0.0`) | minor (`1.4.2` → `1.5.0`) | patch (`1.4.2` → `1.4.3`) |

## What Counts as Breaking

A change is breaking when any of these is true:

- An API kind or field is removed or renamed.
- Validation is tightened, so an object that was accepted before is rejected (on create or on its next update).
- A default changes in a way that changes the behaviour of existing objects.
- A configuration key is removed or renamed.
- An admin or a user has to do something on upgrade.

Deprecating a field or key, without removing it, is not breaking. The release notes list it under **Deprecated**.

## Platform Release Version

The platform release carries a set of package versions and has its own semantic version. It moves by the **largest change of any component it carries**: if one package has a breaking change, the platform release has a breaking change too, even if every other package only has fixes.

The release notes of each platform release list the version of every component it changes, and every breaking change with the action it requires. See [Release Notes](index.md).
