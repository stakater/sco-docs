# SCO Console Docs — Action Plan (Epic: SCO-portal docs)

Tracker for the console documentation scope. Each line is one page = one subtask.
Tick it off when the page is created/filled (placeholders count as done once stubbed).

**Scope:** 14 pages — **0 / 12 to do now**, **2 deferred (mocked)**.
Consumer 8 active + 2 deferred · Provider 2 · Cross-cutting 2.

> ⚠️ **Mocks:** several console areas serve mock data in the current build.
> Disable mocks before writing/screenshotting so the public docs don't expose
> placeholder or internal information.

This file lives outside `content/`, so it does not publish as a doc page.

---

## Cloud-consumer — Console section (`content/console/`)  · 0/8

- [ ] **C1** `overview.md` — *(fill)* what the console is, layout/navigation, role-based views, Standard vs Advanced mode
- [ ] **C2** `accessing-the-console.md` *(new)* — logging in, choosing organisation/project context · **standalone page, cross-linked from `authentication/logging-in.md`**
- [ ] **C3** `dashboard.md` — *(fill)* dashboard widgets, key metrics, recent activity · 🅼 **disable mock data first** — only document real widgets
- [ ] **C4** `organizations.md` — *(fill)* viewing/switching organisation context
- [ ] **C5** `projects.md` — *(fill)* project list, create, detail, switching projects
- [ ] **C6** `resources.md` *(new)* — schema-driven resource UX: list → detail → create/edit, Standard vs Advanced
- [ ] **C7** `marketplace.md` — *(fill)* browsing the marketplace in the console
- [ ] **C8** `solutions.md` — *(fill)* provisioning & managing solutions via the console

### Deferred — 🅼 mocked, add when available for real

Public-facing docs, so hold these until the functionality is backed by real data.

- [ ] **C9** `activity.md` *(new)* — activity / audit log view · 🅼 **mocked — defer**
- [ ] **C10** `account-and-billing.md` *(new)* — billing, invoices, cost explorer, support · 🅼 **mocked — defer**

## Cloud-provider — UI control (placeholders, WIP)  · 0/2

- [ ] **P1** `how-to-guides/provider/control-ui-rendering.md` *(placeholder)* — controlling console UI via `x-ui-*` extensions
- [ ] **P2** `service-provider-guide/console/ui-extensions-reference.md` *(placeholder)* — `x-ui-*` contract reference stub

## Cross-cutting  · 0/2

- [ ] **X1** Verify `installation/*` covers reaching the console; add a note if not
- [ ] **X2** Update `theme_override/mkdocs.yml` nav with new Console pages as they land

---

## Decisions

- **C2 placement:** ✅ standalone `console/accessing-the-console.md`, referenced from the existing `authentication/logging-in.md`.
- **Structure:** keep a standalone "Console" nav section (current) vs weave console pages into the For-Cloud-Consumers journey. *(open)*
- Provider pages (P1, P2) stay placeholders this cycle per epic note (UI-control is WIP).
- **Mocked features (C9, C10):** deferred until real — public docs must not surface mock data.
