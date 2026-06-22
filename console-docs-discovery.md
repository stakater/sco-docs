# SCO Console Docs — Action Plan (Epic: SCO-portal docs)

Tracker for the console documentation scope. Each line is one page = one subtask.
Tick it off when the page is created/filled (placeholders count as done once stubbed).

**Scope:** 14 pages — **0 / 14 done.**
Consumer 10 · Provider 2 · Cross-cutting 2.

This file lives outside `content/`, so it does not publish as a doc page.

---

## Cloud-consumer — Console section (`content/console/`)  · 0/10

- [ ] **C1** `overview.md` — *(fill)* what the console is, layout/navigation, role-based views, Standard vs Advanced mode
- [ ] **C2** `accessing-the-console.md` *(new)* — logging in, choosing organisation/project context
- [ ] **C3** `dashboard.md` — *(fill)* dashboard widgets, key metrics, recent activity
- [ ] **C4** `organizations.md` — *(fill)* viewing/switching organisation context
- [ ] **C5** `projects.md` — *(fill)* project list, create, detail, switching projects
- [ ] **C6** `resources.md` *(new)* — schema-driven resource UX: list → detail → create/edit, Standard vs Advanced
- [ ] **C7** `marketplace.md` — *(fill)* browsing the marketplace in the console
- [ ] **C8** `solutions.md` — *(fill)* provisioning & managing solutions via the console
- [ ] **C9** `activity.md` *(new)* — activity / audit log view
- [ ] **C10** `account-and-billing.md` *(new)* — billing, invoices, cost explorer, support

## Cloud-provider — UI control (placeholders, WIP)  · 0/2

- [ ] **P1** `how-to-guides/provider/control-ui-rendering.md` *(placeholder)* — controlling console UI via `x-ui-*` extensions
- [ ] **P2** `service-provider-guide/console/ui-extensions-reference.md` *(placeholder)* — `x-ui-*` contract reference stub

## Cross-cutting  · 0/2

- [ ] **X1** Verify `installation/*` covers reaching the console; add a note if not
- [ ] **X2** Update `theme_override/mkdocs.yml` nav with new Console pages as they land

---

## Open decisions (resolve when picking up items)

- **C2 placement:** standalone `console/accessing-the-console.md` vs folding into existing `authentication/logging-in.md`.
- **Structure:** keep a standalone "Console" nav section (current) vs weave console pages into the For-Cloud-Consumers journey.
- Provider pages (P1, P2) stay placeholders this cycle per epic note (UI-control is WIP).
