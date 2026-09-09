# Docs screenshots — automated capture

Live SCO Console screenshots for these docs, captured with browser-runner.

Console images are not referenced by path. Each one is a `{{ screenshot: <name> }}`
directive standing in for the image path, so the page keeps its own alt text:

```markdown
![The dashboard showing the organisation summary]({{ screenshot: dashboard-org-stats }})
```

Why a directive rather than the path: a path can silently render a stale file and
nothing notices. A directive can only resolve to an image captured for it, and an
unresolved one fails the build.

## Layout

```
screenshots/
  flows/             # one browser-runner YAML per docs page
  captured/          # capture output, committed — what the directives resolve to
  baseline/          # the previous hand-taken images, kept for diffing only
  config.env         # checked-in config: console URL, org, resource plurals
  .env.example       # template for .env — credentials only
  inject.py          # --check gate; can also resolve directives on disk
  mkdocs_hook.py     # resolves directives during mkdocs build (in memory)
```

`captured/` is the only source. Nothing falls back to `baseline/`, because falling
back would publish a stale screenshot — the failure this exists to prevent.

## Running

Copy `.env.example` to `.env` and fill in the credentials, then:

```sh
make screenshots                       # every flow
make screenshots-one FLOW=resources    # just flows/resources.yaml
```

The capture script itself comes from `stakater/.github`. `make` downloads it into
`makefiles/`, which is gitignored, at the ref pinned in the Makefile.

The flows are read-only: they open list, detail and create views but never submit, so
there is nothing to seed or tear down.

`python3 screenshots/inject.py --check` reports any directive that fails to resolve,
plus any capture no page uses. It writes nothing, so it is the gate to run in CI.

## Image standard

**2560 x 1600** — a `1280x800` viewport at `deviceScaleFactor: 2`, light theme, set in
the `viewport:` block of every flow so all captures come out the same size.

## Flows and the images they produce

| Flow | Docs page | Images |
|---|---|---|
| `login` | `accessing-the-console.md`, `dashboard.md`, `overview.md` | `login-org-slug`, `dashboard-org-stats`, `sidebar-resources`, `user-menu` |
| `projects` | `projects.md` | `project-list`, `project-create` |
| `resources` | `resources.md`, `overview.md` | `resource-list`, `resource-detail`, `create-form-standard`, `resource-detail-1`, `detail-advanced` |
| `iam` | `create-iam-user.md`, `create-iam-group.md` | `iam-users-list`, `iam-user-create`, `iam-group-create`, `iam-group-create-members`, `iam-group-detail` |
| `mesh` | `create-mesh.md` | `mesh-list`, `mesh-create`, `mesh-detail` |
| `clusters` | `provision-openshift-cluster.md` | `cluster-list`, `cluster-create-standard`, `cluster-create-advanced`, `cluster-detail` |

`dashboard-org-stats` and `create-form-standard` are each referenced by two pages.

The `iam`, `mesh` and `clusters` flows cover how-to guides rather than console pages, so
they carry a console section into a `kubectl`-first guide. They are still read-only: a
create form is opened and filled, never submitted. Filling matters on those three pages
because the fields the guide is about — a members list, a private networking mode, an
access-group row — are not text boxes, and an empty form does not show a reader what
they are aiming at.

The flows lean on the packs in browser-runner (`login`, `open-resource-list`,
`open-resource-create`, `open-resource-detail`, `expand-sidebar-group`,
`set-complexity-mode`, `fill-array-field`), so a page's flow is mostly navigation intent
rather than selectors. Anything the packs cannot express — opening the account menu,
framing a below-the-fold section — is a step in the flow itself.

The resource packs take a `plural`, not a resource type, because the console resolves
`/<plural>` from the OpenAPI spec alone: one generic route renders list, create and
detail for everything in it. Covering a new resource is therefore a new flow plus a
plural in `config.env`, not new packs — that is why these six flows need only three
selectors between them.

The complexity mode persists in `localStorage`, so within a flow every Standard shot
must be captured before an Advanced one. The `resources`, `iam` and `clusters` flows all
rely on that ordering; `iam` and `clusters` toggle back to Standard before their detail
shots rather than assume it.

Adding a pack means an image rebuild, since packs are baked into `browser-runner`. To
test one before it merges, point `RUNNER_PACKS` at a browser-runner checkout, and it is
mounted over the image's copy:

```sh
RUNNER_PACKS=~/src/browser-runner/src/packs make screenshots-one FLOW=iam
```

## What the environment needs

The flows create nothing, but they do need somewhere to point and something to show:

- a **running console** at `CONSOLE_URL`, reachable from wherever the capture runs.
  Every flow declares it under `requires.reachable`, so an unreachable URL fails before
  the browser starts rather than mid-capture.
- an **existing user** with access to the `CONSOLE_ORG` organisation. The flows never
  create an account: credentials come from `CONSOLE_USER` / `CONSOLE_PASSWORD` in
  `screenshots/.env` locally, and from repo secrets of the same names in CI. What that
  user can see is what gets published, so it needs read access to every resource these
  pages document.
- an organisation with at least one project
- at least one row in each resource list they open (`DOCS_VM_PLURAL`,
  `DOCS_PROJECT_PLURAL`, `DOCS_USER_PLURAL`, `DOCS_GROUP_PLURAL`, `DOCS_MESH_PLURAL`,
  `DOCS_CLUSTER_PLURAL`) — an empty list renders an empty state and no table, which
  fails the capture rather than publishing a screenshot of "No <resources>"
- the resource named in `DOCS_VM_NAME`, used for the detail, delete-panel and
  Advanced shots so all three agree
- the same for `DOCS_GROUP_NAME`, `DOCS_MESH_NAME` and `DOCS_CLUSTER_NAME`. All three are
  provisioned out of band and long-lived; no flow creates them. That matters most for the
  cluster, where submitting the form would provision a hosted control plane and real
  capacity — which is why the `clusters` flow fills its form and never submits it.

If a future flow does need to create something, `capture.sh` runs `flows/_seed.yaml`
first and `flows/_teardown.yaml` last, ahead of and after everything else. There is no
seed today, and adding one gives up the property that a capture run can be pointed at any
environment without changing it.
