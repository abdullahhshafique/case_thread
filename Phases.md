# CaseThread — Phases

**Status:** Draft v1.2 (adds §12 — UX Parity PRD, complete 2026-09-24)
**Last updated:** 2026-09-24
**Timeline basis:** Larger team, standard 6–12 month startup timeline
**Related docs:** [PRD.md](./PRD.md) · [Architecture.md](./Architecture.md) · [Rules.md](./Rules.md) · [memory.md](./memory.md)

---

## 1. Phase Overview

| Phase | Objective | Target window | Status |
|---|---|---|---|
| Phase 0 | Planning & foundation (this document set, environment setup) | Weeks 1–2 | ✅ Complete |
| Phase 1 | Core platform — Case Rooms, access codes, roles, shared core, 2 case-type modules | Months 1–3 | ✅ Complete |
| Phase 2 | Full template library + redaction + notifications + export | Months 3–5 | ✅ Complete |
| Phase 3 | AI agent workflows | Months 5–7 | ✅ Complete |
| Phase 4 | SaaS polish — marketplace, cross-case search, offline mode, mobile store release | Months 7–12 | ✅ Complete (S1–S4); mobile store + paid tier deferred |
| Phase 5 | Investigation intelligence — alibis, contradictions, gaps, dashboard, case status/closed summary | — | ✅ Complete (2026-09-17) |
| Phase 6 — UX Parity PRD (client request) | Light theme, overview enrichment, export overhaul, evidence AI tab + verify-alibi, discussion enhancements, demo seeding + briefing editor, optional chat media | — | ✅ Complete (2026-09-24) — see §12; voice notes + chat media (7.1/7.2) intentionally skipped |
| Phase 7 — OPTIONAL | Voice notes, read receipts, chat media drawer, role-colored avatar dots | — | 🟡 Partial (2026-09-24) — presence + role dots shipped (§12.7); voice notes/chat media skipped behind a scoped mini-sprint |
| Phase 6 — v3 | Spec alignment + v3 Investigation Console + polish tail | — | ✅ Complete (2026-09-23); CI 3/3 green; main tagged `v0.1.0` |

---

## 2. Phase 1 — Core Platform

**Goal:** "Create a room, generate a code, invite a teammate, upload evidence, see it in an audit trail" works end-to-end, for Legal/Investigative and Academic case types, on Web + mobile.

**Epic breakdown:**

| Epic | Priority | Notes |
|---|---|---|
| Auth (sign up/in, session mgmt) | P0 | Supabase Auth, email/password |
| Case Room creation + case-type selection | P0 | Legal/Investigative + Academic only |
| Access code generation, rotation, join flow | P0 | Includes rate limiting (Architecture.md §9) |
| Role definitions + RLS permission enforcement | P0 | Full permission matrix per PRD open question |
| Shared core: dashboard, timeline, vault, discussion, tasks, audit log | P0 | |
| Flutter Web + mobile shell (nav, theming per Design.md) | P0 | |
| CI/CD pipeline (GitHub Actions + Vercel) | P0 | |
| RLS contract test suite | P0 | Non-negotiable per Rules.md §7 |

**Definition of Done for Phase 1:**
- All P0 items above shipped and demoable.
- RLS contract tests pass in CI for every defined role in both case types.
- Design/UX review approved against Design.md.
- Architecture review confirms no P0 item required deviating from Architecture.md without a documented decision.
- Demo Day flow (see §7 below) runs end-to-end without manual database intervention.

**Dependencies:** Supabase project provisioned; Design.md finalized before UI build starts; case-type/role matrix (PRD open question) resolved before RLS policies are written.

**Phase-specific risks:** RLS policy complexity underestimated → mitigate with the contract-test-first approach in Rules.md §7; Flutter web performance unknowns → validate early with real devices (Architecture.md §13).

**Resources:** Backend/DB engineer(s) for Supabase schema + RLS; Flutter engineer(s) for client; 1 designer for Design.md execution; 1 PM/product owner.

**Deliverables:** Deployable web build on Vercel staging, mobile build runnable on emulator/device, RLS test suite in CI, updated memory.md.

**Go/No-Go for Phase 2:** Core flows demo cleanly to an outside observer; no known P0 security gap in RLS coverage.

---

## 3. Phase 2 — Full Template Library

**Goal:** Roll out the remaining domain modules (Corporate & Business, Medical & Healthcare, Technical & Engineering) as configs on the existing core; add field-level redaction, notifications, and report export.

**Epic breakdown:**

| Epic | Priority |
|---|---|
| Remaining case-type configs (Corporate, Medical, Technical) | P0 |
| Field-level redaction (per PRD §6.3 edge cases) | P1 |
| Notification/activity feed | P1 |
| PDF/Word export | P1 |
| Entity-relationship map (initial version, recursive-CTE-based) | P1 |

**Definition of Done:** All five case-type categories from the original concept selectable at room creation; redaction verified via RLS contract tests; export produces a correctly-scoped (no privileged-field leakage) PDF/Word file.

**Dependencies on Phase 1:** Shared core and RLS pattern from Phase 1 must be stable — new case types must not require core schema changes (validates the "config not rebuild" architecture principle).

**Risks:** Medical module may surface HIPAA-adjacent handling questions not yet resolved — flag to Product + Legal SME per PRD §10 open questions before building Medical-specific fields.

**Resources:** Same core team; may need a domain SME consult (legal/medical) for realistic field definitions.

**Deliverables:** Updated case-type config library, export service, notification feed, updated memory.md.

**Go/No-Go for Phase 3:** All case types functional; export and redaction pass security review.

---

## 4. Phase 3 — AI Agent Workflows

**Goal:** Ship the workflow builder and the first set of domain-tuned agents, fully human-in-the-loop.

**Epic breakdown:**

| Epic | Priority |
|---|---|
| AI Adapter Layer (provider-agnostic interface) | P0 |
| Workflow builder UI (chain agents visually) | P0 |
| First agents: Contradiction Checker (legal), Financial Anomaly Detector (corporate), Root-Cause Suggester (technical) | P0 |
| Accept/edit/dismiss review flow + audit logging | P0 |
| Remaining agents (Literature Summarizer, Diagnostic Differential Assistant, etc.) | P1 |

**Definition of Done:** At least 3 agents functional end-to-end against at least one real provider; every suggestion is visibly distinct from confirmed case data; every accept/edit/dismiss decision is logged in the audit trail; provider swap (e.g., Claude → Gemini) requires no core logic changes, only config.

**Dependencies:** AI Adapter Layer design finalized (Architecture.md §AI layer); LLM provider default decision resolved (PRD open question).

**Risks:** Prompt injection via malicious evidence content — mitigated by treating all AI output as unprivileged (Architecture.md §9); provider cost/rate-limit unknowns — mitigate by defaulting to a free/cheap tier in dev and gating expensive calls behind explicit user action, not automatic triggers.

**Resources:** 1–2 engineers focused on the AI Adapter Layer and agent prompt design; product input on agent output quality review.

**Deliverables:** AI Adapter Layer, workflow builder, 3+ working agents, updated memory.md.

**Go/No-Go for Phase 4:** Agent suggestion acceptance rate (PRD §3 KPI) trending above the 40% target in pilot usage, or a clear plan to improve it.

---

## 5. Phase 4 — SaaS Polish (COMPLETE 2026-09-15)

**Goal (as planned):** Template marketplace, cross-case search, offline-first mobile, mobile app store release, and initial paid-tier groundwork.

**Epic breakdown — actual delivery:**

| Epic | Priority | Status |
|---|---|---|
| Template marketplace (design/share custom case-type templates) | P2 | ✅ P4-S1 — `publish_template()` RPC + draft→materialize flow; `features/templates/` |
| Cross-case search | P2 | ✅ P4-S2 — `search_cases()` RPC (RLS-scoped prefix full-text); `features/search/` |
| Offline-first mobile sync | P2 | ✅ P4-S3 — LWW-stamped RPCs, conflict flags, offline queue; `features/offline/` |
| Version history on documents/notes | P2 | ✅ P4-S4 — `list_versions()` RPC over audit log; `features/history/` |
| Mobile app store submission (iOS/Android) | P1 | ⏳ Blocked — developer accounts not provisioned |
| Paid tier groundwork (billing integration, SSO, compliance export) | P2 | ⏳ Blocked — pending Go/No-Go product decision |

**Definition of Done (as executed):** All four P2 epics shipped with pgTAP contract tests (29 new assertions: 10 search, 12 offline, 7 history), Dart unit tests, and RLS scoping verified. Offline sync conflict-resolution policy doc (`docs/offline-sync-conflict-policy.md`) served as the pre-build gate. Mobile store and paid-tier items were not in scope for Phase 4 S1–S4 per Phases.md §5 re-plan.

**Key decisions:**
- Offline conflict resolution: LWW with visible conflict flag for manual-event/task edits (not append-only streams); security-sensitive writes never queue; revoked-member queued writes typed-denied.
- Search scope: cross-case full-text (room names, discussion, timeline, tasks, evidence) scoped by RLS — no privileged fields visible.
- Version history: read surface over append-only audit log (no new writes); timeline edits numbered from v2.

**Dependencies:** Stable Phase 1–3 core ✅; app store developer accounts provisioned ahead of submission — **NOT YET DONE**.

**Risks (remaining):** App store review delays — submit early, treat review time as a hard external dependency. Developer accounts (Apple/Google) — provision EARLY per §5.

**Deliverables:** Marketplace ✅, cross-case search ✅, offline mode ✅, version history ✅, published mobile apps ⏳, updated memory.md ✅.

**Go/No-Go:** Phase 4 epics S1–S4 complete. Remaining items (store submission, paid tier) are Phase 5 candidates pending product direction.

---

## 5. Phase 5 — Investigation Intelligence Layer (COMPLETE 2026-09-17)

**Goal:** Ship fact/claim/finding/unknown classification, investigation gaps, alibi verification, contradiction detection (elevated to first-class), case dashboard with statistics, AI case completeness review agent, case status/closed summary, Analysis nav section, Quick Actions bar, and AI consent disclosure. All additive, RLS-first, human-in-the-loop.

**Epic breakdown:**

| Epic | Priority | Status |
|---|---|---|
| Fact/Claim/Finding/Unknown classification | P1 | ✅ — 0027 migration (nullable CHECK columns on evidence_items + timeline_events; vehicle added to entities.type) |
| Investigation gaps | P0 | ✅ — `investigation_gaps` table + `gap_create_task()` RPC; `features/investigation_gaps/` |
| Alibi verification | P0 | ✅ — `alibis` + `alibi_evidence_links` tables + `verify_alibi()` RPC; `features/alibis/` |
| Contradiction detection (elevated) | P0 | ✅ — `contradictions` + `contradiction_sources` tables (first-class); `features/contradictions/` |
| Case dashboard with statistics | P1 | ✅ — `v_case_statistics` view + `CaseStatistics` model; `features/dashboard/` |
| AI case completeness review agent | P1 | ✅ — `case_completeness_review` agent (6th, cross-domain); consent disclosure in Edge Function |
| Case status + closed summary | P1 | ✅ — `case_rooms.investigation_status` + `case_closed_summaries` + `transition_investigation_status()` |
| Analysis nav section + Quick Actions bar | P1 | ✅ — `AnalysisPane` with Alibis/Contradictions/Gaps sub-tabs; Quick Actions in RoomDetailScreen |
| AI consent step | P0 | ✅ — Consent dialogs in AiPane (single-agent + workflow); consent data scope gathered server-side before provider call |
| Export extension (contradictions/alibis/gaps/status) | P1 | ✅ — Migration 0031 extends `export_case_report()` v2; `export_report.dart` toMarkdown extended |

**Definition of Done:**
- All P0 epics demoable end-to-end.
- New tables have RLS contract tests (pgTAP).
- `v_case_statistics` verified no leak.
- AI agent output only via `ai_suggestions` (never directly to case record).
- No guilt-implying UI copy (Design.md §9).
- Open Conflicts from PRD-Phase5.md §7 recorded as decisions in memory.md §6.

**Key decisions:**
- Investigation status is additive to room status (case_room.status = room lifecycle; investigation_status = investigation lifecycle — separate concepts, not a replacement).
- `v_case_statistics` implemented as a function returning a table (live aggregate, not materialized view — per Architecture-Phase5.md §2.10).
- Dashboard repository queries `v_case_statistics` via RPC and filters client-side (RLS on the function itself scopes results).

**Migrations:** 0025 (investigation tables) → 0027 (classification + vehicle) → 0026 (status/summary/view) → 0028 (RLS) → 0029 (agent + audit) → 0030 (RPCs) → 0031 (export extension).

**Tests:** 6 pgTAP (rls_alibis, rls_contradictions, rls_investigation_gaps, rls_cross_table_leak, statistics_view, investigation_status) + 4 Dart (alibi, contradiction, gap_task, dashboard).

---

## 6. Phase Retrospective Log

*(Updated after each phase closes. Phases 0–5 complete; Phase 6 code-complete, awaiting CI validation.)*

| Phase | What went well | What went poorly | Changes for next phase |
|---|---|---|---|
| Phase 0 | Planning document set produced, environment provisioned, no rework needed | — | — |
| Phase 1 | Full feature set shipped ahead of plan: auth, rooms/join, vault, timeline/discussion/tasks, UI gating — all live-verified against cloud; RLS-first design caught a real policy hole via contract tests; pgTAP suite grew 0→75 | Debugging RLS via blind CI loops cost ~a day before Docker arrived; supabase_flutter API drift (instanceOrNull/publishableKey) and pgTAP 3.36 semantics (throws_ok exact-match, empty-set is()) were repeated time sinks | Local-Docker-loop-first is now standing policy for any DB work (CI is the gate, not the debugger); pin exact library versions + read actual package sources instead of assuming APIs |
| Phase 2 | Five case types shipped as pure config (zero core-schema deviation — the Sprint-6 architecture proof held); redaction enforced server-side via security-barrier views and live-proven in a single session; phase-boundary CI pass caught 9 real bugs before they could ship | Recorded-migration hotfixes needed for cloud (policy patches outside files); export testing required careful privileged-field scoping; recursive-CTE entity queries took several iterations to bound | Contract-test-first applied beyond RLS (redaction, export scoping); phase-boundary full verification pass is now standing policy; view-based redaction (security_invoker) is the pattern for any future field-level gating |
| Phase 3 | Full human-in-the-loop pipeline shipped as data + one Edge Function: agent registry, review RPC, provider adapter with 5 providers behind one interface; workflow builder (0018) reused the case-types-as-config pattern; Deno contract tests with stubbed fetch machine-prove provider-swap-is-config (DoD); realtime publication closed the Architecture §7 push gap | Realtime publication was never wired in Sprint 5 — `.stream()` panes silently no-oped, caught only while wiring suggestions live; UPDATE/DELETE RLS denials are silent no-ops (test asserts state, not throws — cost a test rewrite); local Docker stack start failed twice (pg_meta unhealthy) before a working exclude list | Tables added to `supabase_realtime` publication in the same migration that introduces them, with a pgTAP assertion; deny-contract tests for UPDATE/DELETE assert state-change absence; keep `postgres-meta` excluded from local stack starts |
| Phase 4 | All four P2 epics shipped as committed code with contract tests: template marketplace (draft→publish materialization, per-role validation), cross-case search (RLS-scoped, redaction-aware), offline sync (LWW conflicts, append-only replay, security-gated writes), version history (audit-derived, no new writes). Policy-first approach: conflict-resolution design doc written before any code; every write path uses the same LWW RPCs for live + replay. | Append-only streams (discussion messages) proved trivially replay-safe; manual-event/timeline edits required careful LWW+conflict-flag implementation. RLS scoping for search required verifying no privileged-field leakage (redaction boundary test). | Mobile store submission moves to Phase 5 (external dependency); paid-tier groundwork deferred pending Go/No-Go. All 4 epic items shipped on schedule — no carries. |
| Phase 5 | Investigation layer shipped additively on the config-driven core — contradictions elevated to first-class, status/summary lifecycle automated server-side, classification exposed through the redacted view without touching 0013's shape | The 0027 CHECK-constraint add without dropping the old named constraint bit twice (0027/0034 lesson); impersonated-session fixtures caused a whole class of pgTAP failures that only surfaced in CI | Fixture SQL always `unimpersonate()` first; scalar-subquery pgTAP assertions; CHECK changes drop the old constraint by name |
| Phase 6 | Spec-epic pass closed the instructor-doc gaps (dashboard header+graphs, classification UI, connections map, Riverside seed), then the v3 HTML console was rebuilt in the Flutter shell (Geist + gradient + atmosphere, topbar/rail/cases shell, overview hero + stat tiles + charts, live-count attention card, animated connections graph, audit/summary panes) — zero backend changes, 118/118 Dart green. GitHub Push Protection caught a committed secret (p6j.txt) before it ever reached the remote; the key was rotated and history scrubbed | A pasted CI log was ever committed (p6j.txt with a live Supabase key — history scrubbed, key must rotate); doc/state drift between sessions left HANDOFF claiming fixes CI had never validated | Never commit pasted logs; sync progress docs (HANDOFF/memory/Phases) at the end of every session; treat push-protection blocks as a full history-audit trigger |

---

## 7. Demo Day Plan (reference)

Reused from the original concept as the acceptance test for Phase 1's Definition of Done — a single ~90-second flow:

1. Create a Case Room (pick case type, get a private code).
2. Second device joins with a role, no IT setup.
3. Upload evidence to the vault.
4. *(Phase 3+)* AI agent flags a contradiction, clearly marked as a suggestion.
5. *(Phase 3+)* Lead approves it, logged in the audit trail.
6. *(Phase 2+)* Export a PDF report.

In Phase 1, steps 4–6 are stubbed/skipped since AI and export ship in later phases — Phase 1's demo proves steps 1–3 plus a visible, populated audit log.

---

## 8. GitHub Deployment & README Guidance

- **License:** this is a **public repository, all rights reserved** (not open-source licensed) — the README must include a clear `## License` section stating "All rights reserved. This code is publicly visible for portfolio/demonstration purposes; no license is granted for reuse, modification, or redistribution without permission," rather than an MIT/Apache badge.
- **README structure to build:**
  1. Project title + one-line positioning (§13 of the original concept doc).
  2. **Hero visual** — an architecture or product-flow image/animated SVG near the top (see §9 below for generation prompts).
  3. Problem/why-now summary (condensed from PRD.md §1).
  4. Feature highlights with the "How CaseThread Compares" table (from the concept doc §4).
  5. **Workflow pipeline visual** — the AI agent workflow or the Case Room lifecycle, placed inline near the relevant section.
  6. Tech stack badges (Flutter, Supabase, Vercel).
  7. **Result/stat card image** — a visual summarizing KPIs or demo-day results once available (placeholder until real pilot data exists).
  8. Setup/local dev instructions.
  9. Links to PRD.md, Architecture.md, Design.md for anyone wanting depth.
  10. License section (per above).
- **Image placement convention:** store generated images/SVGs/GIFs under `/docs/assets/` in the repo, reference them in the README with relative paths (`![Architecture Overview](./docs/assets/architecture-overview.svg)`) so they render correctly on GitHub.
- **Animated SVG/GIF usage:** best suited for the workflow pipeline (showing the suggestion → human-approval loop) since motion communicates the human-in-the-loop story better than a static diagram; keep static images for the architecture diagram and stat card for clarity/loading speed.

---

## 9. AI Image/Asset Generation Prompts

Pick 2–3 of these depending on what's ready to show; all are written to be portable across image-generating LLM tools.

**1. Architecture overview diagram (static, recommended)**
> "Create a clean, modern technical architecture diagram for a SaaS product called CaseThread. Show a Flutter client (Web, Android, iOS icons) connecting via HTTPS/WSS to a Supabase backend box containing four sub-components: Auth, Postgres+RLS, Storage, and Realtime, plus a separate Edge Functions box labeled 'AI Adapter Layer' connecting outward to four small provider icons labeled Claude, GPT, Gemini, and Grok. Use a navy (#0D1526) background, slate blue-gray boxes, white text, and a single muted teal accent color (#4FA8A0) for connecting lines and highlights. Flat, minimal, rounded rectangles, no drop shadows, no 3D effects, generous whitespace, suitable for a GitHub README on a dark theme. Export as SVG."

**2. Workflow pipeline / human-in-the-loop animation (animated SVG or GIF, recommended)**
> "Create a simple animated SVG/GIF showing a 4-step horizontal pipeline: (1) 'Evidence Uploaded' icon, arrow to (2) 'AI Agent Analyzes' icon (subtle pulsing to suggest processing), arrow to (3) 'Suggestion Flagged' icon in amber/gold (#E8B04B) to show a pending state, arrow to (4) 'Human Approves' icon in muted teal (#4FA8A0) with a checkmark, which then connects to a final 'Logged in Audit Trail' icon. Use a navy background (#0D1526), flat minimal line-icon style, smooth 2–3 second loop, no realistic imagery, no text-heavy labels beyond short captions under each step. Optimize for embedding in a GitHub README (small file size, seamless loop)."

**3. Result/stat card (static, use once pilot/demo data exists)**
> "Create a clean stat-card graphic for a SaaS product README, dark navy background (#0D1526), showing 3–4 large bold numbers with short labels beneath each — e.g., 'Time-to-first-room: <3 min', 'Case types supported: 5', 'Roles per room: up to 6', 'Codebase: 1 (Flutter, Web+Android+iOS)'. Use a single muted teal accent (#4FA8A0) for the numbers, off-white (#EDEFF3) for labels, minimal geometric divider lines between stats, no icons or illustrations, clean sans-serif typography (Inter or similar), suitable as a wide banner image for a GitHub README."

**4. Product mockup / screenshot placeholder (optional, once UI exists)**
> "Create a realistic browser-window mockup showing a dark-themed case-management dashboard UI called CaseThread: left sidebar with room navigation, center panel showing a case timeline with a few entries (one marked with an amber 'AI suggestion' badge), right panel showing team member avatars with role labels. Use navy (#0D1526) background, slate surfaces (#1B2436), teal accent (#4FA8A0) for primary buttons/active states, amber (#E8B04B) only for the pending-AI-suggestion badge, Inter font. Clean, professional SaaS aesthetic, no clutter."

---

## 10. LinkedIn Post Template

Use once Phase 1 (or a meaningful milestone) is demoable. Fill in bracketed placeholders with real specifics before posting.

```
🧵 [THE HOOK]
Built CaseThread — a case-room platform where any team (legal, academic,
corporate, medical, or technical) can spin up a private, secure workspace
in minutes, invite the right people with a join code, and manage an
entire case — evidence, timeline, and AI-assisted insight — in one place.

[THE PROBLEM]
Most case-management tools are built for one domain and require IT to
provision accounts before anyone can start working. That's fine for a
large agency with a procurement budget — it's useless for a legal team,
a student integrity board, or a fast-moving fraud unit that needs to be
collaborating in the next five minutes, not next week.

[THE TECH / PROCESS]
→ Flutter — one codebase shipping to Web, Android, and iOS
→ Supabase — Postgres, Auth, Realtime, and Row-Level Security doing the
   real permission enforcement, not just the UI
→ A provider-agnostic AI adapter layer — Claude, GPT, Gemini, or Grok,
   swappable behind one interface, always human-in-the-loop
→ Vercel + GitHub Actions for CI/CD

[THE RESULT]
[X] weeks in, [what's shipped — e.g., "the core Case Room flow — create,
join, upload evidence, see it all in an immutable audit trail — works
end-to-end across web and mobile."] Biggest lesson so far: [one real
learning, e.g., "building the permission model in the database (RLS)
instead of the UI made every later feature safer by default."]

[CALL TO ACTION]
If you've built or used a tool like this — what's the one feature that
made the difference between "another shared folder" and something your
team actually trusted with sensitive case data? Would love to hear it.

#SaaS #Flutter #Supabase #BuildInPublic #ProductDevelopment
```

**Hashtag notes:** swap `#ProductDevelopment` for something more specific to the milestone if useful (`#LegalTech`, `#EdTech`, `#AIAgents`) — keep to 3–5 total per the original brief.

## 11. Phase 6 — Spec Alignment & v3 Console (2026-09-17 → 2026-09-19)

Closes the gaps against the instructor's "Complete Project Understanding" doc, then rebuilds the Flutter shell to the approved v3 HTML console (`casethread-v3.html`).

| Epic | What shipped |
|---|---|
| Dashboard (doc §8–9) | Case-info header (name, investigation status, lead, team, opened), 8th stat tile (unverified alibis), evidence-by-type + events-over-time graphs (custom-drawn, no deps), mounted as the FIRST tab |
| Fact/Claim/Finding/Unknown (doc §7) | Classification badges on Timeline + Vault tiles, filter chips on Timeline, classification picker in the Add-Event sheet, v_timeline exposes the 0027 column |
| Connections map (doc §13) | New Map tab: circular entity graph (person/location/vehicle/evidence/org colors), tap node/edge for "Why connected?" sheets, add-relationship flow for edit_case holders |
| Coherent mock case (doc §30) | Riverside Robbery #2291 seed: full cast, relationships, classified evidence, the doc's timeline sequence, alibi-in-conflict, contradiction, gaps — access code ROBBERY2 |
| Tests | case_breakdown pgTAP suite (6), CaseBreakdown + EntityMapData Dart suites |

Key decisions: charts hand-drawn (no fl_chart — pinned-deps rule); Dashboard mounted as tab 0 (doc §32 main-nav); seed added alongside existing rooms (back-compat).
Migrations: 0033_case_breakdown.sql (v_case_breakdown security-invoker fn + v_timeline gains classification).

### 11.1 v3 Investigation Console rebuild (2026-09-19 — code complete, CI pending)

Presentation-layer rebuild of the Flutter shell to the approved v3 design — zero backend changes; every existing provider/RPC reused:

| v3 element | Where it lives |
|---|---|
| Geist + GeistMono fonts, brand gradient (teal→blue→violet), console surface/status tokens, ambient atmosphere (shell grid + aurora + glow orbs; reduced-motion aware) | `pubspec.yaml`, `assets/fonts/Geist*`, `lib/core/theme/app_colors.dart`, `lib/shell/ambient_atmosphere.dart`, `app_text_theme.dart` |
| Topbar + icon rail + cases-panel shell; room detail embedded with 11 v3 tabs (Overview / Discussion / Evidence / Timeline / Analysis / Connections / Tasks / AI / Audit Log / Members / Summary) | `rooms_screen.dart`, `room_detail_screen.dart` |
| Overview hero, 6 stat tiles, evidence-by-type + 14-day event charts, classification coverage meter | `features/dashboard/dashboard_screen.dart` (v_case_statistics 0026 + v_case_breakdown 0033) |
| "Waiting on you" attention card with live counts (open tasks, open contradictions, unverified alibis) | `attentionCountsProvider` + `roomTasksStreamProvider` in `rooms_providers.dart` |
| Animated connections graph — pulsing orbs, flowing dashed edges, dashed ring for unknown types, type legend | `features/connections/connections_screen.dart` |
| Audit Log + Summary panes (were imported but missing — the build blocker this phase fixed) | `audit_pane.dart`, `summary_pane.dart` |

**Gates:** flutter analyze 0 issues; 118/118 Dart tests; pgTAP 27 files / 229 all green; 9/9 Deno; web release build ✓. CI 3/3 green on `43048cb`; squash-merged to main, tagged `v0.1.0`. v3 polish tail shipped (mobile bottom nav, notifications sheet, invite copy-link, chat bubbles, vault search + chips, timeline restyle, hero title).

---

## 12. UX Parity PRD (client request) — COMPLETE 2026-09-24

Implemented end-to-end in one session; migration numbering deviated from the PRD plan (see 12.6). No Edge Function or RPC changes; every feature reuses existing providers/RPCs except the noted additions.

### 12.1 Light theme + debug tools (P1)
- `AppColorsLight` in `app_colors.dart` — same token names as `AppColors`, light-appropriate WCAG-AA values; components swap classes, never hardcode.
- `buildAppTheme({Brightness brightness})`; `themeModeProvider` (Notifier, persisted via SharedPreferences, cycles system→dark→light).
- Theme toggle on the console; kDebugMode-only demo sign-in (`demo@casethread.test`) and `demoRoleOverrideProvider` permission-override pill for instant role testing.

### 12.2 Overview enrichment (P2)
- `CaseBriefingCard` reading `CaseRoom.briefing`; `AlertCards` (contradictions/coral, gaps/amber, alibis/mint; tap → `analysisTabRequestProvider` → AnalysisPane animates the nested TabController); `TaskDonut` (52 px verified-alibi ring).
- `AttentionCounts` extended (alibiVerified/Partial/Conflict, openGaps, totalAlibis getter).
- Dashboard order: hero → briefing → 6 stats → 3 alerts → donut → charts.

### 12.3 Export overhaul (P3)
- `ExportSheet` bottom sheet: fetches the RLS-scoped `export_case_report` document, then **PDF** (`CaseReportPdf.toPdfBytes` via `pdf 3.11.2`, handed to the OS with `Printing.sharePdf` 5.13.4 — a download on web) or **Markdown copy**. Replaces the copy-only AppBar action.

### 12.4 Evidence detail AI analysis + verify-alibi (P4)
- `EvidenceDetailSheet` on vault-tile tap: full metadata (type/size/version/uploader/date/sha256), permission-gated per-item AI run (`runAgent(evidenceItemId:)` → Edge Function `evidence_item_id`), verify-alibi tiles (Verified/Partial/Conflict/Insufficient → required status reason dialog → `verify_alibi` with `evidenceItemIds: [this item]`).

### 12.5 Discussion enhancements (P5)
- `discussionFlagsProvider` — per-room star/pin sets in SharedPreferences (client-side view flags, not case data). Long-press action sheet; pinned strip above the thread; **Extract-to-case** writes a manual timeline event classified `claim` (edit_case-gated).

### 12.6 Demo seeding + briefing editor (P6)
- `0042_room_briefing.sql` (nullable `case_rooms.briefing`); `BriefingEditorSheet` + edit-pencil on the card (edit_case-gated); `RoomsRepository.updateBriefing`.
- **Bug fixed:** `getMyRooms` explicit column list omitted `investigation_status` (and would omit `briefing`) — both added.
- `supabase/seed_demo.sql` — idempotent full Riverside Robbery #2291 seed (briefing, entities, classified evidence, tasks, open contradiction, two alibis, gaps, timeline; code `DEMO1234`). Lives outside the numbered migrations because it needs a real `auth.users` id per environment. **Numbering note:** 0042 = briefing (not "demo seed expansion"), 0043 = presence policy (not "chat-media bucket" — chat media was skipped).

### 12.7 Optional extras (P7) — partial
- Shipped: role-colored presence dots (`roleDotColor` — lead=blue, analyst=violet, forensic=cyan, legal=magenta, viewer=slate) on the dashboard avatar stack + member tiles; "Active Xm ago" per member (`0043_presence_watermarks.sql` lets approved co-members read each other's `room_last_seen`; `getRoomPresence` + `roomPresenceProvider`).
- Skipped: voice notes, read receipts on messages, chat media drawer — need a recording plugin + mic permissions, a `chat_media` storage bucket + policies, playback UI, and a message-attachment schema. Scoped as a separate mini-sprint.

### 12.8 Tests added/extended (10 files)
theme_switch, alert_cards, case_briefing_card, dashboard_layout (extended), export_report, evidence_detail_sheet, discussion_flags, presence, app_theme (extended), auth (extended).

**Gates at doc time:** code-complete; local gates + `flutter pub get` (new deps) + migrations 0042–0043 push + seed run + CI **pending** (authored without a local Flutter SDK) — see HANDOFF §3.

---

## 13. Obsidian-style Connections Graph upgrade (2026-09-24)

Client-approved plan (guideline approved in session): bring Obsidian.md's graph experience — force-directed layout, camera, filters, and template-driven entity import — to the Connections tab. Zero backend changes for steps 1–3.

| Step | Scope | Status |
|---|---|---|
| 1 | Force-directed layout engine (`force_layout.dart`, pure Dart: repulsion + springs + centering, alpha-cooled settle, deterministic golden-angle start, drag support), wired into `_GraphView` with a settle-and-stop Ticker; reduced-motion settles synchronously. 10 unit tests (convergence, no-NaN, spring/repulsion behavior, determinism, drag pin, hit-test, dangling edges, drift bounds) | ✅ |
| 2 | Camera + hover: focal-anchored pinch zoom (0.4–3×) + pan via `onScale*` (one gesture arena for node-drag/pan/zoom), constant screen-space stroke widths, MouseRegion hover highlight of the 1-hop neighborhood | ✅ |
| 3 | Filters + local graph + search: entity-type & relationship-type filter chips, local-graph focus mode (tap refocuses, depth 1–3 hops), type-ahead search-jump that centers the camera and flashes the target's neighborhood | ✅ |
| 4 | Obsidian-templates half: `entity_seed` JSONB on `case_type_templates` (migration 0044), `materialize_entity_seed` security-definer RPC (stable keys → UUID resolution, edit_case-gated, idempotent per (room,name), audited), import-with-preview sheet (`entity_import_sheet.dart`) behind an edit_case-gated FAB, `SeedTemplate` model + 2 tests, 7-assertion pgTAP suite (`entity_seed_test.sql`) | ✅ |

Key decisions: no graph package (hand-rolled physics per the pinned-deps rule; O(n²) repulsion is fine for case-sized graphs — Barnes-Hut only if rooms exceed hundreds of entities); no WebGL canvas (CustomPainter + Ticker settles this scale); the existing "Why connected?" sheets are kept (better than Obsidian's equivalent).
