# White-label docs pipeline

Status: proposal. 2026-09-18. Short form for review, including the task split:
[2026-09-29-whitelabel-docs-design.md](2026-09-29-whitelabel-docs-design.md).

## Problem

`sco-docs` builds one image for everyone: content baked at `Dockerfile:6`, screenshots against one hardcoded
console (`screenshots/config.env:5`), theme from a private submodule (`.gitmodules:2`), and all 15 pages under
`content/api-reference/` hand written. A customer cannot brand it, extend it, or have it reflect the APIs they
actually deploy.

## Shape

One image, one Job, in the customer's cluster. `sco-docs-builder` is `FROM ghcr.io/stakater/browser-runner:<tag>`
plus python3 and mkdocs, carrying baseline content, baseline flows and the prepared theme. It clones the
customer's overlay repo, builds into a new release directory on a PVC, and swaps a `current` symlink that an
nginx Deployment serves.

Only two steps need the cluster: capturing the console and fetching the gateway OpenAPI. Both become local
Service calls, so no credential leaves the cluster and the console needs no public route.

Helm knows two things: where the overlay repo is, and how to authenticate. Everything else lives in the repo.

---

## Overlay repo

```
acme-docs/
  docs.yaml                    # the whole configuration surface
  content/                     # mirrors baseline layout; same path overrides, new path adds
    index.md
    how-to-guides/acme-onboarding.md
  flows/                       # extra browser-runner flows, same schema as baseline
    billing.yaml
  theme/
    extra.css                  # optional, appended last
    assets/logo.svg
```

No baseline in their git history. Upgrading is a builder image tag bump, so merge conflicts are impossible and
their diff only ever shows their own content.

### `docs.yaml`

```yaml
site:
  name: Acme Cloud Docs
  url: https://docs.acme.example

console:
  url: http://console.sco.svc:8080     # in-cluster
  org: acme
gateway:
  url: http://cog-gateway.sco.svc:8080

apis:                                   # declared: must be in the spec, must render
  - virtualmachines.compute.cloud.stakater.com
  - projects.tenant.cloud.stakater.com

capture:
  flows: [login, projects, resources]   # baseline flows, in order
  vars:                                 # interpolated into flow YAML as ${VAR}
    DOCS_VM_NAME: acme-demo-vm
    DOCS_PROJECT_PLURAL: projects
    DOCS_SIDEBAR_GROUP: Virtual Machines

theme:                                  # mkdocs/Material only, unrelated to the console theme
  primary: "#1E3A8A"                    # -> --md-primary-fg-color
  accent: "#F59E0B"                     # -> --md-accent-fg-color
  default_scheme: auto                  # auto | light | dark; the toggle stays either way
  font: { text: Inter, code: JetBrains Mono }
  logo:        { light: theme/assets/logo-light.svg,   dark: theme/assets/logo-dark.svg }
  footer_logo: { light: theme/assets/footer-light.svg, dark: theme/assets/footer-dark.svg }
  favicon: theme/assets/favicon.png
  badges: []                            # replaces the Stakater CSA / HIPAA badges; [] removes them

nav:
  add:
    - page: how-to-guides/acme-onboarding.md
      under: "For Cloud Consumers > How-to Guides"
      title: Acme onboarding
      before: how-to-guides/user/create-project.md   # optional, else appended
  remove:
    - how-to-guides/user/create-vault.md             # we do not offer Vault
    - section: "For Service Providers"
  rename:
    - from: "For Cloud Consumers"
      to: "Using Acme Cloud"
```

`capture.vars` is today's `screenshots/config.env` moved into customer hands. `capture.flows` being read at
runtime is why the flow list never has to be known at Helm render time.

---

## `/tools/build`

### 1. Resolve config

Read and validate `/overlay/docs.yaml`. A missing or unknown key fails naming the key. Secrets arrive as env
(`CONSOLE_USER`, `CONSOLE_PASSWORD`, `GATEWAY_TOKEN`), never from the file.

### 2. Merge content

Copy `/baseline/content` to `/work/content`, then walk `/overlay/content` and copy over it.

- Same relative path replaces the baseline file.
- New path adds.
- Nothing is deleted here. Removal is a nav operation (step 5), because a file present but absent from the nav
  trips `strict: true` at `theme_override/mkdocs.yml:8`.

### 3. Capture

Flows are `capture.flows` resolved against `/baseline/flows`, in declared order, then every `*.yaml` in
`/overlay/flows`. Order matters: complexity mode persists in `localStorage`, so Standard shots must precede
Advanced ones.

```sh
for f in $FLOWS; do /runner/run "$f" || exit 1; done
```

`browser-runner/docker/bin/run:3` takes a path argument and the image has `/bin/sh`, so no upstream change is
needed. `E2E_ARTIFACTS_DIR=/work/captured`; relative `path:` in a flow joins onto it
(`browser-runner/src/primitives/screenshot.ts:17`).

Any non-zero exit fails the build, naming the flow and its verdict. browser-runner distinguishes them:
`1` a step failed, `2` a precondition was unmet, `3` the YAML is malformed. `requires.reachable` means an
unreachable console costs seconds, not a browser launch.

### 4. Generate the API reference

`GET {gateway.url}/openapi` with the token. For each entry in `apis`, locate its schema and render markdown to
`/work/content/api-reference/<group>/<kind>.md`.

- Declared but absent from the spec: **fail**. It means the customer believes they ship an API they do not.
- Present in the spec but not declared: skip, and log it. The spec also carries `infrastructure.stakater.com`
  APIs, which are not user facing.
- The generator owns the whole `api-reference` subtree. Nav operations may rename that section but may not place
  pages inside it.

Generation produces the **field reference tables**. The hand written prose around them stays: the existing pages
carry things no schema holds, such as how to read credentials out of Vault, and the spec leaks `spec.crossplane`
in 16 of 50 schemas, which `AGENTS.md` forbids showing users. Filter that out.

### 5. Patch the nav

Start from the baseline nav at `theme_override/mkdocs.yml:23` and apply `docs.yaml` operations in order:
`remove`, `rename`, `add`.

- Every operation must resolve against an existing target, else fail. This is what catches a patch gone stale
  after a baseline upgrade, rather than silently dropping the customer's page.
- `remove` also deletes the file from `/work/content`, so the strict build does not then complain about a page
  outside the nav.
- Baseline pages the customer never mentions stay. New baseline pages appear on upgrade with no customer edit.

### 6. Apply the theme

`theme_common` is Material (`theme.name: material`, `mkdocs-material>=9.5.2,<10.0.0`) with
`custom_dir: dist/_theme`. Three things make this cheap:

- The palette is already declared `primary: custom` and `accent: custom`, so Material reads
  `--md-primary-fg-color` and `--md-accent-fg-color` from CSS. `extra_css: stylesheets/extra.css` is already
  wired. Brand colour is two variables, not a theme override.
- The palette already has auto, light and dark entries with a toggle. `default_scheme` picks the default; it
  does not remove the toggle.
- `combine_theme_resources.py` stacks overrides, which `prepare_theme_pr.sh` already relies on by running it
  twice with `-skiprmtree`. Customer assets are a third layer into `dist/_theme`, no new mechanism.

So the step is: render the `theme` block to `stylesheets/extra.css`, layer `theme/assets` into `dist/_theme`,
set the theme keys, then append the customer's `theme/extra.css` last so it wins.

The theme also hardcodes Stakater brand keys: `logo_light`, `logo_dark`, `footer_logo_light`,
`footer_logo_dark`, `favicon`, plus `cloud_security_alliance_logo_*` and `hippa_compliant_logo_*`. All must be
overridable and the compliance badges must be removable. Publishing Stakater's CSA and HIPAA badges in a
customer's docs would be a misrepresentation, not just off brand.

Mapped: colours, scheme, fonts, logos, favicon, badges. Nothing else. The console is React and Tailwind,
mkdocs is Material; partial fidelity beyond this reads as broken.

### 7. Build

`mkdocs build -d /data/releases/$BUILD_ID`, strict. The existing hook (`theme_override/mkdocs.yml:15-16`) resolves
`{{ screenshot: X }}` to `captured/X.png`; an unresolved directive fails.

Then `ln -sfn /data/releases/$BUILD_ID /data/current`. The rename is atomic and mkdocs writes progressively, so
nginx never serves a half built tree. Keeping the last few releases makes a rollback a re-point.

### Failure modes

| Condition | Result |
|---|---|
| Unknown or missing `docs.yaml` key | Fail, naming the key |
| Declared flow exits non-zero | Fail, naming flow and verdict |
| Declared API absent from the OpenAPI spec | Fail, naming the API |
| Nav operation targets something that does not exist | Fail, naming the target |
| `{{ screenshot: X }}` with no `X.png` from this run | Fail, naming the directive |
| Any of the above | PVC untouched, previous site keeps serving |

---

## Decisions

| Decision | Why |
|---|---|
| Overlay only repo, baseline never in customer git | Upgrading is a tag bump. Merge conflicts impossible |
| All config in `docs.yaml`, Helm holds only repo and credentials | One place the customer looks, reviewable in a PR |
| Baseline baked, not pulled at runtime | The image tag is the version. Pulling adds a knob that can disagree |
| Declarative nav patch, not full nav ownership | New baseline pages appear on upgrade without a customer edit |
| API reference from the gateway OpenAPI, not a cluster XRD scan | Same credential as capture, no cluster read access, matches what the console renders |
| Docs theme decoupled from the console theme | Different engines. The overlap is colours, fonts, logos, favicon. Material's `primary: custom` already exposes the colour hook |
| `FROM browser-runner` rather than a franken-image | Inherits the Playwright pin asserted at `browser-runner/Dockerfile:8,23`. Costs ~1GB, pulled once per node |
| Shell loop, not N initContainers, not an upstream change | Three lines, ships today, no release coordination |
| Job plus PVC, not an initContainer in the serving Deployment | A failed rebuild must leave the previous site serving; an initContainer cannot start at all while the console is down |
| Fail on any uncapturable declared flow | Chosen over pruning pages or falling back to baseline images. Customer seeds a demo org before their first green build |

## Changes to `sco-docs`

1. Stop committing `screenshots/captured/`; it becomes build output.
2. `screenshots/config.env` dissolves into `docs.yaml` under `capture.vars`.
3. The 14 pages under `content/api-reference/` lose their hand maintained parameter tables to generation. The
   prose stays.
4. `Makefile:24-30` and `.github/workflows/screenshots.yaml` are superseded by the builder.
5. `sco-docs` becomes customer zero: `docs.stakater.com` is produced by this pipeline against a Stakater demo
   org, so the pipeline cannot rot unnoticed.
6. `prepare_theme.sh:1-3` moves into the builder image build, so customers never need access to the private
   theme repo.

## Open questions

1. **Renderer for step 4.** Valid CRD YAML is derivable from the merged spec in about 25 lines, proven against a
   captured response: `x-kubernetes-group-version-kind` gives group, version and kind; the paths give plural and
   scope. That makes `crdoc` usable. `gen-apidocs` also consumes OpenAPI but wants swagger 2.0 and is wired to the
   Kubernetes release process. Go-source generators (`crd-ref-docs`, `gen-crd-api-reference-docs`) cannot see our
   APIs at all, since they come from KCL packages. Needs a short bake off against
   `content/api-reference/public-apis/s3-bucket.md`.
2. Which endpoint serves the merged OpenAPI, and does a user token suffice?
3. **Storage.** The release swap handles atomicity and rollback, but the Job and nginx still share the volume. On
   `ReadWriteOnce` that needs both on one node. Confirm an RWX storage class, or pin with node affinity.
4. Every customer needs a seeded demo org before their first green build. Whose runbook?
5. A `run-all <dir>` subcommand upstream could share one browser across flows, saving the 10 to 15s login each.
   At six flows (`login`, `projects`, `resources`, `clusters`, `iam`, `mesh`) that is a minute or more per build.
6. **Portable image.** A PVC cannot produce an image the customer runs elsewhere. If that is wanted, build it in CI
   from a captured artifact rather than inside the customer cluster.

**Resolved.** Description coverage in the merged spec is 37% of `spec.*` fields and 23% of required ones, best
schema 67%, worst 7%. Generation therefore produces field tables and the prose stays. Improving this means richer
descriptions in the KCL packages, which would also improve the console's form hints, since both render from the
same spec.

## Related

`browser-runner/docs/docs-screenshot-automation.md` designs docs capture for CI and leaves the target
environment open, live staging URL versus ephemeral deploy. Running in the customer's cluster closes that
question: the console captured is the console the docs describe.
