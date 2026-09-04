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
  capture.sh         # runs all flows (or one) via docker
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
./screenshots/capture.sh            # every flow
./screenshots/capture.sh resources  # just flows/resources.yaml
```

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

`dashboard-org-stats` and `create-form-standard` are each referenced by two pages.

The flows lean on the packs in browser-runner (`login`, `open-resource-list`,
`open-resource-create`, `open-resource-detail`), so a page's flow is mostly navigation
intent rather than selectors. Anything the packs cannot express — expanding a sidebar
group, opening the account menu, switching to Advanced — is a step in the flow itself.

The complexity mode persists in `localStorage`, so within a flow every Standard shot
must be captured before an Advanced one. The `resources` flow relies on that ordering.

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
  `DOCS_PROJECT_PLURAL`) — an empty list renders an empty state and no table, which
  fails the capture rather than publishing a screenshot of "No <resources>"
- the resource named in `DOCS_VM_NAME`, used for the detail, delete-panel and
  Advanced shots so all three agree
