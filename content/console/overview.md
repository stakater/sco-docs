# Console Overview

The Stakater Cloud Orchestrator (SCO) console is the web interface for your organisation. It is where cloud consumers sign in, browse the services available to them, provision resources, and manage what they have created.

![The SCO console after sign-in]({{ screenshot: dashboard-org-stats }})

---

## Who the Console Is For

The console is aimed at cloud consumers — developers, team leads, and organisation administrators who provision and manage services on the platform.

---

## Layout

The console has three persistent areas.

### Sidebar

The left sidebar is your main navigation. It contains:

- **Dashboard** — your organisation at a glance
- **Resource sections** — grouped entries for each kind of resource your organisation exposes (for example projects, organisation users and groups, virtual machines, clusters, databases, and storage)

Each resource entry expands to show **All `<resources>`** (the list view) and, where you have permission, **Create `<resource>`**.

The sidebar adapts to you: a resource only appears if your organisation exposes it **and** you have access to it. If you cannot see something you expect, you may not have been granted access — contact your organisation administrator.

![The sidebar with resource groups expanded to show All and Create entries]({{ screenshot: sidebar-resources }})

### Top Bar

The top bar shows your organisation's branding and a button to collapse or expand the sidebar. On the right is your **account menu**, where you can open your account settings, switch the colour theme (light, dark, or system), and log out.

![The account menu in the top bar]({{ screenshot: user-menu }})

### Content Area

The main area renders the page you have navigated to — the dashboard, a resource list, a resource's details, or a create/edit form.

---

## Standard and Advanced Mode

Create, edit, and detail pages offer a **Standard / Advanced** toggle.

- **Standard** (the default) shows the fields most people need.
- **Advanced** reveals additional, lower-level fields.

Your choice is remembered in your browser, so it persists across pages and sessions. Start in Standard mode and switch to Advanced only when you need a field that is hidden.

![A create form in Standard mode, with the Standard and Advanced toggle]({{ screenshot: create-form-standard }})

---

## What's Next?

- [Accessing the Console](accessing-the-console.md) — Sign in to your organisation
- [Dashboard](dashboard.md) — Your organisation at a glance
- [Projects](projects.md) — Work with projects
- [Working with Resources](resources.md) — Browse, provision, and manage services
