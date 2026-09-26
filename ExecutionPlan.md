# CaseThread — Execution Plan

**Status:** Draft v1.0
**Owner:** Product Lead
**Last updated:** 2026-09-10
**Related docs:** [PRD.md](./PRD.md) · [Architecture.md](./Architecture.md) · [Phases.md](./Phases.md) · [Design.md](./Design.md) · [Rules.md](./Rules.md) · [memory.md](./memory.md)

> **Role of this document:** Phases.md is the strategic roadmap (what & why, per phase). ExecutionPlan.md is the operational companion (who, when, and in what order). Where the two overlap, Phases.md DoD/gate criteria are reproduced verbatim — if a conflict is ever found, Phases.md wins and this doc is corrected.

---

## 1. Prerequisites — Phase 0 Exit Checklist

Nothing in Sprint 0 starts until every item below is green. These are the blockers called out in memory.md §5 and PRD.md §10.

| # | Item | Owner | Blocks | Status |
|---|---|---|---|---|
| P1 | **Permission matrix per role × case type** (full grid for Legal + Academic: view/edit case, upload evidence, comment, approve AI findings, manage members, export, view privileged fields) | Product + Legal domain SME | All of Sprint 2–3 (RLS policies can't be written correctly without it) | ☐ Open |
| P2 | Git repository initialized with `main` protected (no direct pushes, squash-merge only — Rules.md §2) | Eng lead | CI setup | ☐ Open |
| P3 | Supabase dev project provisioned; Auth (email/password) enabled; project URL + anon key in CI secrets | Backend/DB eng | Sprint 1 onwards | ☐ Open |
| P4 | Vercel project connected to repo (preview deploys per PR) | Eng lead | Web verification from Sprint 0 | ☐ Open |
| P5 | Team roles assigned (backend/DB, Flutter client, design, PM) per Phases.md §2 resource note | Product Lead | Sprint staffing | ☐ Open |
| P6 | Decision log started in memory.md §6 for the four PRD §10 open questions | PM | Phase 2–3 planning | ☐ Open |

**Note:** P1 is the hard blocker. If the SME isn't available in week 1, Product drafts a *starter* matrix marked `draft — pending SME review`, Sprint 2–3 proceeds against it, and the SME review becomes a gate before any RLS policy merges to `main` (not before it's drafted).

---

## 2. Delivery Process — Global Rules

These apply to every sprint in every phase.

### 2.1 Cadence & structure

- **Sprint length:** 2 weeks, Monday start. Phase 1 = Sprint 0–7 (8 sprints ≈ 4 months elapsed calendar incl. buffer; Phases.md says Months 1–3 for dev — see §8 gate table for the mapping).
- **Ceremonies:** 30-min sprint planning (Monday), 15-min async standup (daily, written), 1h sprint demo + retro (Friday of week 2).
- **Branching/merging:** per Rules.md §2 — `feature/…` branches, Conventional Commits, squash-merge, no direct pushes to `main`.

### 2.2 CI gates (every PR, blocking merge)

1. `dart format --set-exit-if-changed` + `flutter analyze` (zero warnings — Rules.md §1)
2. Unit + widget tests (`flutter test`)
3. RLS contract test suite (pgTAP) against Supabase local — **non-negotiable per Rules.md §7**. Run it LOCALLY first (Docker Desktop + `npx supabase db reset && npx supabase test db`, ~seconds per iteration); CI is the confirmation gate, never the debugging loop. Hard-won lesson from Sprint 3: blind CI-driven debugging cost a day; the local Docker loop found every remaining issue in minutes.
4. Supabase migration dry-run
5. Web build succeeds (bundle-size budget check per Rules.md §9 — flag >10% growth without justification)

### 2.3 Both-platform rule (Definition of Done amendment)

Per product decision (2026-09-10): **no milestone, epic, or sprint goal counts as "done" until verified on BOTH:**
- Latest Chrome (web build — via Vercel preview for the PR)
- Android 10+ (API 29+) emulator or physical device

Every sprint demo runs the increment on both platforms. Flutter-web-performance risk (Architecture.md §13) is mitigated by this being a check from Sprint 0, not a late surprise.

### 2.4 Documentation hygiene

- memory.md updated at end of every sprint (§7 of memory.md requires session updates — treat the sprint demo as the session boundary).
- Architecture-affecting discoveries go in Architecture.md, not chat logs (Rules.md §3).

---

## 3. Phase 1 — Core Platform (Sprint 0–7)

**Goal (from Phases.md §2):** "Create a room, generate a code, invite a teammate, upload evidence, see it in an audit trail" works end-to-end, for Legal/Investigative and Academic case types, on Web + mobile.

### Sprint 0 — Foundation (Week 0–1)

| Work item | Detail | Owner |
|---|---|---|
| Flutter scaffold, feature-based folders | `lib/core/` (theme, errors, routing, API contracts), `lib/features/<feature>/` per Rules.md §1. No `widgets/`/`models/` flat sprawl. | Flutter eng |
| Pinned dependencies | `supabase_flutter`, `flutter_riverpod`, `go_router` (exact versions pinned per Rules.md §4). **Open decision:** router choice is not fixed by Architecture.md — confirm `go_router` at Sprint 0 kickoff or record alternative in memory.md §6. | Flutter eng |
| Design tokens | Dark theme per Design.md §1–2 as a `ThemeData` built from named tokens (no hardcoded colors anywhere — enables the Phase 2+ light theme). Inter + JetBrains Mono wired via font assets. | Flutter eng + design |
| GitHub Actions CI | The §2.2 gate pipeline, running on PR + `main`. | Eng lead |
| Vercel connection | Flutter web build auto-deployed per PR preview + `main` staging. | Eng lead |
| Supabase local dev stack | Docker-based local Supabase via CLI for RLS test runs; cloud dev project for manual testing. | Backend eng |

**Sprint 0 DoD:** `main` deploys a themed (Design.md tokens) placeholder shell to Vercel; CI is green with all 5 gates; `flutter run` works on Chrome + Android emulator.

### Sprint 1 — Auth & Profiles

- Supabase Auth email/password sign-up/in/out, session persistence (secure client storage per Architecture.md §7 login flow).
- `profiles` table (display name, avatar) + RLS: users read/update only their own row.
- Riverpod auth state — `AsyncNotifier` session provider driving route guards (unauthenticated → auth screen).
- **Typed-error pattern established here** (Rules.md §5): `AuthError` hierarchy defined in `lib/core/errors/`; every later feature copies this pattern. No bare exceptions.
- Auth flows verified on both platforms (§2.3).

### Sprint 2 — Database Schema & Test Harness

- Full logical schema from Architecture.md §5 as numbered Supabase migrations: `profiles` (from Sprint 1), `case_rooms`, `room_members`, `roles`, `evidence_items`, `timeline_events`, `audit_log`, `discussion_messages`, `tasks` (+ `ai_suggestions`, `entities`, `entity_relationships` created now for forward compatibility, unused until Phase 2–3 — keeps later migrations additive per Architecture.md §14).
- **`audit_log` immutability enforced at grant level:** no UPDATE/DELETE grants for any role (Architecture.md §4 — enforced in DB, not app logic).
- pgTAP (or equivalent) RLS contract-test harness wired into CI gate 3 — the harness itself is the deliverable; policies arrive next sprint.
- Migration discipline: additive-only changes; destructive changes need an Architecture.md §14-style justification in the PR.

### Sprint 3 — Rooms, Codes, Join Flow, RLS

- Room creation (name, case type → owner) — server-side, via RLS-protected insert.
- **Access code generation:** 8-char alphanumeric, ambiguous chars (`0/O`, `1/I`) excluded, collision → silent regenerate (PRD §6.1 edge case). Hashed server-side only — Edge Function for generation + rotation; plaintext never stored or sent to client (Architecture.md §9).
- Join flow: enter code → validate (no information leak on invalid/expired codes — PRD §6.2) → select role from case type's allowed list → pending state → owner approve/deny. Existing member re-join routes straight into the room (PRD §6.2 edge case).
- Code rotation: invalidates old code for new joins only; pending requests on old code stay valid (PRD §6.1 edge case).
- Rate limiting on join attempts (per-user + per-IP) against 8-char code brute-forcing.
- **RLS policies + allow/deny contract tests for every role in both case types** (Phases.md Phase 1 P0 epic: "RLS contract test suite").

### Sprint 4 — Evidence Vault

- Supabase Storage bucket + upload via typed API contract (Architecture.md §2: no ad-hoc queries in UI code).
- Limits per PRD §6.4: PDF/DOCX/PNG/JPG/TXT/common audio (metadata only), 50MB/file (configurable per deployment).
- Every upload → `evidence_items` row + `audit_log` entry (uploader, timestamp, **file hash**) — audit write via DB trigger so it can't be bypassed by a future code path.
- Duplicate filename → version suffix, never overwrite (PRD §6.4 edge case). Mid-transfer failure → partial file invisible to members, user-initiated retry.
- Vault list UI: lazy `ListView.builder` (Rules.md §9), image thumbnails (never full-res originals), responsive list→detail on tablet.

### Sprint 5 — Timeline, Discussion, Tasks

- **Timeline:** merged view of manual + system events (Architecture.md §5 `timeline_events` types). Manual events editable by permitted roles; every edit itself logged. Lazy list, reflow to stacked cards on mobile (Design.md §12).
- **Discussion:** threaded, room-scoped, realtime via Supabase Realtime channels scoped `room:{id}` (Architecture.md §8). `@mentions` (parse + array column). Live updates via `StreamNotifier`.
- **Tasks:** title, assignee, optional due date, status (open/in progress/done), optional linked evidence.
- Responsive shell complete: mobile bottom-tab bar / desktop sidebar + context panel (Design.md §12).

### Sprint 6 — Case-Type Configs (Legal + Academic)

- **Case types as data, not code** (Architecture.md §2): `roles` + case-type config rows (JSONB templates) for Legal/Investigative and Academic — validates the "one core, many configs" principle early. If this sprint needs core schema changes, that's an architecture red flag → stop and document (Phases.md Phase 2 dependency note).
- Role-scoped UI gating on top of RLS (UI hides what the DB would refuse — both layers per Architecture.md §2 RLS-first note).
- Accessibility pass: keyboard nav (web), screen-reader semantics, 44px touch targets, labels on every input (Rules.md §8).
- Performance pass: web bundle budget check on real low-end hardware (Architecture.md §13 risk).

### Sprint 7 — Hardening, Demo Day Readiness, Gate

- Error-handling audit against Rules.md §5: every fetch screen has an error boundary; typed errors everywhere; permission-denied messages are role-specific (PRD §6.7: "Your role — Observer — can't upload evidence in this room").
- Seed/mock data script for demo environments (Rules.md §13 — never reachable from prod).
- **Demo Day flow (Phases.md §7 steps 1–3 + audit log):** create room → second device joins with role → upload evidence → visible populated audit log. Rehearsed on Chrome + Android device, end-to-end, no manual DB intervention.
- Sprint retro → Phase 1 retro logged in Phases.md §6.

**Phase 1 Definition of Done (from Phases.md §2, verbatim):**
- All P0 items shipped and demoable.
- RLS contract tests pass in CI for every defined role in both case types.
- Design/UX review approved against Design.md.
- Architecture review confirms no P0 item required deviating from Architecture.md without a documented decision.
- Demo Day flow runs end-to-end without manual database intervention.
- *(ExecutionPlan addition)* Both-platform rule (§2.3) satisfied for every epic.

**Go/No-Go for Phase 2 (from Phases.md §2):** Core flows demo cleanly to an outside observer; no known P0 security gap in RLS coverage.

---

## 4. Phase 2 — Template Library & Reporting (Months 3–5)

**Goal (from Phases.md §3):** Remaining domain modules (Corporate, Medical, Technical) as configs on the existing core; field-level redaction, notifications, report export.

Sprint-level plan (2-week sprints, ~5 sprints incl. buffer):

| Sprint | Epic | Key notes |
|---|---|---|
| P2-S1 | **Corporate & Technical case-type configs** | Proves "config not rebuild" (Phases.md dependency): zero core schema changes allowed. RLS contract tests extended to new role sets. |
| P2-S2 | **Medical case-type config** | Gate before build: HIPAA-adjacent open questions resolved with Product + Legal SME (Phases.md risk note). |
| P2-S3 | **Field-level redaction** | Column-level views / JSONB masking in the query layer — never a client-side hide (Architecture.md §9). Redaction verified by RLS contract tests per Phases.md DoD. |
| P2-S4 | **Notification/activity feed** | Postgres + Realtime; "what changed since you last opened this room" (Architecture.md §4). Decision point from PRD §10: push-vs-web-only for Observer/Client roles — resolve in this sprint's design review. |
| P2-S5 | **PDF/Word export** | Edge Function export service; input-sanitized rendering (Architecture.md §9 input sanitization); DoD: correctly-scoped output with **no privileged-field leakage** (Phases.md §3). Also: entity-relationship map v1 (recursive CTE — evaluate Apache AGE only with real volume, per Architecture.md §5). |

**Phase 2 DoD (from Phases.md §3):** All five case-type categories selectable at room creation; redaction verified via RLS contract tests; export produces a correctly-scoped PDF/Word file.

**Go/No-Go for Phase 3 (from Phases.md §3):** All case types functional; export and redaction pass security review.

---

## 5. Phase 3 — AI Agent Workflows (Months 5–7)

**Goal (from Phases.md §4):** Workflow builder + first domain-tuned agents, fully human-in-the-loop.

Sprint-level plan (~5 sprints):

| Sprint | Epic | Key notes |
|---|---|---|
| P3-S1 | **AI Adapter Layer — ONE provider end-to-end** | Architecture.md §13 mitigation: wire a single provider (default per PRD §10 open question — must be resolved by Sprint 0 of Phase 3) fully before adding others. Contract tests with fixture responses, no live API calls in CI (Rules.md §7). |
| P3-S2 | **Remaining adapters behind the same interface** | Claude / GPT / Gemini / Grok normalized; provider swap = config change only (Phase 3 DoD requirement). Secrets in Edge Function env vars only (Rules.md §10). |
| P3-S3 | **Workflow builder UI + first agent (Contradiction Checker, legal)** | Agents write **only** to `ai_suggestions` (status=pending) — never to `timeline_events`/`audit_log` directly (Rules.md §11). Suggestions visually distinct via the amber `state/pending` token (Design.md §1). |
| P3-S4 | **Agents 2–3 (Financial Anomaly Detector, Root-Cause Suggester) + review flow** | Accept/edit/dismiss by Lead-tier role; decision + resulting timeline event + audit entry in one transaction (Architecture.md §7 AI workflow path). |
| P3-S5 | **Prompt-injection hardening + agent prompt versioning** | All AI output treated as unprivileged (Architecture.md §9). Prompts versioned and reviewed like code (Rules.md §11). Remaining P1 agents scheduled. |

**Phase 3 DoD (from Phases.md §4):** ≥3 agents functional end-to-end against ≥1 real provider; every suggestion visibly distinct from confirmed case data; every accept/edit/dismiss decision logged in the audit trail; provider swap requires no core logic changes — only config.

**Go/No-Go for Phase 4 (from Phases.md §4):** Agent suggestion acceptance rate trending above the 40% target (PRD §3) in pilot usage, or a clear plan to improve it.

---

## 6. Phase 4 — SaaS Polish (Months 7–12)

**Goal (from Phases.md §5):** Marketplace, cross-case search, offline-first mobile, store release, paid-tier groundwork.

**Phase-4 kickoff re-plan (2026-09-14, per the "re-plan at the Phase 3 gate" note):** Phase 3 closed ahead of the pilot-data assumption — no live acceptance-rate data exists yet (metric tracking lands with pilot usage; Phase-3 DoD was satisfied by the complete review pipeline + contract tests). Workstream order below sequenced by dependency + DoD criticality.

| Sprint | Epic | Key notes |
|---|---|---|
| P4-S1 | **Template marketplace** | 0021 `case_type_templates` + `publish_template()` RPC (materializes case_types + roles; server-side grid validation — unknown keys, view_case invariant, lead-tier requirement). Conflict-policy design doc ships here too (offline gate). |
| P4-S2 | **Cross-case search** | Postgres full-text across the caller's rooms (RLS-scoped); watch search performance per §6 note. |
| P4-S3 | **Offline-first mobile v1** | Per `docs/offline-sync-conflict-policy.md` (approved gate): queued writes replay through existing RPC/RLS paths; LWW + visible conflict flag; security-sensitive writes never queue. |
| P4-S4 | **Version history on documents/notes** | Pairs with offline sync work. |
| P4-S5 | **Store submission + hardening** | Developer accounts provisioned EARLY (hard external dependency); offline field-test DoD scenario runs here. |
| P4-S6 | **Paid-tier groundwork** | Billing integration, SSO, compliance export — LAST; only after the Phases.md §5 monetization Go/No-Go. |

**Phase 4 DoD (from Phases.md §5):** Offline mode verified on ≥1 field-test scenario (connectivity loss mid-session, successful resync); marketplace supports template creation + sharing within a workspace; mobile builds pass store review.

---

## 7. Cross-Cutting Workstreams (continuous, all phases)

| Workstream | Rhythm | Source |
|---|---|---|
| RLS contract tests | Every PR touching schema/permissions — gate 3 in §2.2 | Rules.md §7 |
| Component library (Button, Card, Badge, Modal, Table row, Avatar, Toast, Tabs — Design.md §6 catalogue) | Built alongside features as they're first needed; token-only styling | Design.md §6 |
| memory.md updates | End of every sprint (demo is the session boundary) | memory.md header |
| Security review checklist | Applied to every PR; full pass at each phase gate | Rules.md §12 |
| Bundle-size / performance budget | Web build checked in CI every PR | Rules.md §9 |
| Retrospective log | Phase retros into Phases.md §6 | Phases.md §6 |

---

## 8. Milestone & Gate Summary

| Gate | Target | Criteria (verbatim from Phases.md) | Verified on |
|---|---|---|---|
| Phase 0 exit | Sprint 0 start | §1 checklist all green (P1 may proceed as draft-matrix per §1 note) | — |
| Sprint 0 exit | Week 1 | Themed shell deployed via Vercel; CI green; both platforms run | Chrome + Android |
| Phase 1 exit | Month 3 | Phase 1 DoD (§3 above) + Go/No-Go: clean demo, no P0 RLS gap | Chrome + Android |
| Phase 2 exit | Month 5 | All 5 case types; redaction tested; export leak-free; security review passed | Chrome + Android |
| Phase 3 exit | Month 7 | ≥3 agents live; suggestions distinct; decisions logged; provider-swap = config; acceptance rate ≥40% or improvement plan | Chrome + Android |
| Phase 4 exit | Month 12 | Offline verified in field test; marketplace working; store review passed; monetization Go/No-Go decided | Chrome + Android + store devices |

---

## 9. Risk Register (execution-level)

Condensed from Architecture.md §13 + Phases.md per-phase risks; each risk has an owner and a sprint-level trigger for action.

| Risk | Trigger / early warning | Mitigation | Owner |
|---|---|---|---|
| Permission matrix (P1) not resolved before Sprint 2 | SME unavailable in week 1 | Starter draft matrix + SME review gate before RLS merge (§1 note) | Product Lead |
| RLS policy complexity underestimated | Sprint 3 slipping >1 sprint | Contract-test-first approach (tests written with the policy, same PR); pull in DB-eng help early | Backend eng |
| Flutter web perf on low-end devices | Sprint 0/6 device tests sluggish | Both-platform rule from Sprint 0; keep initial bundle lean; lazy-load non-first-paint routes (Rules.md §9) | Flutter eng |
| Supabase single point of failure | Any Supabase outage | Accepted for MVP (PRD §9 assumption); revisit Phase 2+ | Eng lead |
| Medical module HIPAA-adjacent questions | P2-S2 entry | SME consult gate before Medical fields are built | Product Lead |
| Prompt injection via malicious evidence | Phase 3 | AI output always unprivileged + human-in-the-loop; prompt versioning review | AI-layer eng |
| AI provider cost/rate limits | Phase 3 | Free/cheap tier in dev; expensive calls gated behind explicit user action | AI-layer eng |
| App store review delays | Phase 4 | Developer accounts + early submission; review time is a hard external dependency | Mobile release eng |
| Offline sync complexity | Phase 4 | Conflict-resolution policy documented BEFORE build starts | Mobile eng |

---

## 10. Immediate Next Actions (this week)

1. **Product Lead:** draft the starter permission matrix (P1) for Legal + Academic role sets against PRD §6.3's permission dimensions; schedule SME review.
2. **Eng lead:** init git repo on `main` with branch protection + squash-merge (P2); wire GitHub Actions (CI gates from §2.2) and Vercel preview deploys (P4).
3. **Backend eng:** provision Supabase dev project (P3); enable email/password auth; set up Supabase local dev stack via CLI.
4. **Flutter eng:** restructure `lib/` to the feature-based layout; add pinned deps; implement Design.md dark-theme tokens.
5. **PM:** start the §6 decision log in memory.md; schedule Sprint 0 planning.
6. **Everyone:** read Rules.md before the first PR — it's binding (Rules.md header).

## 11. UX Parity PRD (client request — `CaseThread-UX-Parity-PRD.md`)

Phases 1–7, strictly ordered; Phase 7 optional. No backend migration/RPC/RLS changes unless a phase explicitly says so.

| Phase | Content | Status |
|---|---|---|
| Phase 1 — Light Theme + Debug Tools | `AppColorsLight` + `buildAppTheme(brightness:)`, persisted theme toggle, demo sign-in + role-override pill (kDebugMode) | ✅ Complete 2026-09-24 |
| Phase 2 — Case Room Overview Enrichment | Briefing card, 3 alert cards with Analysis deep-links, alibi donut, `analysisTabRequestProvider` | ✅ Complete 2026-09-24 |
| Phase 3 — Export Overhaul | Export bottom sheet: formatted PDF (`pdf` + `printing`, OS save/share/download) + Markdown copy | ✅ Complete 2026-09-24 |
| Phase 4 — Evidence AI + Verify-Alibi | Evidence detail sheet (metadata + sha256, per-item AI run, verify-alibi with evidence attachment) | ✅ Complete 2026-09-24 |
| Phase 5 — Discussion Enhancements | Star + pin (per-room SharedPreferences flags), pinned strip, Extract to Case as `claim` timeline event | ✅ Complete 2026-09-24 |
| Phase 6 — Demo Seeding + Briefing Editor | `0042_room_briefing.sql` + `BriefingEditorSheet`; idempotent `supabase/seed_demo.sql` (Riverside Robbery #2291, code DEMO1234) | ✅ Complete 2026-09-24 |
| Phase 7 — OPTIONAL (partial) | Role-colored presence dots + "Active Xm ago" (`0043_presence_watermarks.sql`) ✅; voice notes / read receipts / chat media ⏭ intentionally skipped — scoped as a separate mini-sprint | 🟡 Partial 2026-09-24 |

**As-built deviations from this plan:** single-room seed (Riverside) instead of 2 extra demo rooms; migration numbering 0042 = briefing, 0043 = presence policy; demo seed lives at `supabase/seed_demo.sql`, not a numbered migration; evidence detail is a single scrollable sheet, not two tabs. Full map in HANDOFF.md §4. Gates (pub get / analyze / test) + migrations push + CI outstanding — see HANDOFF §3.

