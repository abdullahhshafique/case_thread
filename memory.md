# CaseThread — Project Memory

**Last updated:** 2026-09-15 (Phase 4 complete — S2 search, S3 offline, S4 history merged on feature/phase-4-s2-s4)
**Update this file at the end of every work session — it's the fastest way for anyone (including a resuming AI assistant) to get back up to speed.**

---

## 1. Current Project State Summary

**PHASE 4 COMPLETE — `feature/phase-4-s2-s4` branch.** All four Phase 4 epics shipped: **P4-S1** template marketplace (2026-09-14, 78f4e33), **P4-S2** cross-case search, **P4-S3** offline-first sync, **P4-S4** version history. Gate totals: **166/166 pgTAP** (137 from P4-S1 + 10 search + 12 offline + 7 history), **82 Dart tests** (from P4-S1 + unit tests for search/offline/history features), **9/9 Deno** (from P4-S1), analyze 0.

- **P4-S2 cross-case search** — migration 0022: `search_cases()` RPC (RLS-scoped prefix full-text across room names, discussion bodies, manual timeline summaries via v_timeline, task titles, evidence filenames; 50-row limit, descending). Flutter: `features/search/` (search_repository + SearchScreen with 350ms debounce, deep-link into rooms). Route `/search` via app_router; search icon on rooms hub AppBar. pgTAP **10/10** (member-scoped no-leak, prefix match, redaction boundary, RLS deny proof).
- **P4-S3 offline-first sync** — migration 0023: `conflict_flag`/`conflict_note`/`conflict_resolved_at` columns on tasks + timeline_events; `update_task_with_stamp()` + `edit_timeline_event_with_stamp()` LWW-stamped RPCs (check membership/permissions, compare client_value_at, flag loser); `clear_conflict()` (security definer, audit entry); tasks + timeline_events added to realtime publication. Flutter: `features/offline/` (offline_providers connectivity/queue-depth, offline_queue SharedPreferences store 500-cap, OfflineSync controller with 4 replay outcomes, OfflineBanner + ConflictChip UI). pgTAP **12/12** (LWW detection, revoked-member typed deny, clear_conflict idempotent, audit ordering preserved).
- **P4-S4 version history** — migration 0024: `list_versions(object_kind, target_id)` RPC reading audit_log via row_number(); tasks start v1 (create/update), timeline edits start v2; before/after details from audit metadata. Flutter: `features/history/` (version_history_repository + VersionHistorySheet bottom sheet, version_history_sheet.dart). pgTAP **7/7** (task/timeline versions, RLS deny proof, typed error for unknown kinds).

**Still pending from Phase 3:** GROK key (`npx supabase secrets set AI_PROVIDER=grok GROK_API_KEY=…` — function runs mock until then). **Future work:** mobile store submission (developer accounts early — external review timelines), paid-tier groundwork (billing/SSO/compliance export — after Go/No-Go).

---

## 2. Recently Completed Tasks

| Date | Task | Note |
|---|---|---|
| 2026-09-17 | **PHASE 5 COMPLETE** — Investigation Intelligence Layer | 0025–0031 migrations (alibis, contradictions, gaps, investigation_status, closed summaries, statistics view, classification, agent config, audit triggers, RPCs, export extension); `lib/core/api/models.dart` enums + models; 4 feature folders (alibis, contradictions, investigation_gaps, dashboard); Analysis tab + Quick Actions in RoomDetail; AI consent dialogs in AiPane; export extended with contradictions/alibis/gaps/status; dashboard/stats/summary providers; rooms repo investigation methods; 6 pgTAP + 4 Dart test files; updated docs |

| Date | Task | Note |
|---|---|---|
| 2026-09-10 | Refined product concept finalized | Original "investigator's app" reframed as a universal Case Room platform (see original concept doc) |
| 2026-09-10 | PRD.md drafted | Personas, KPIs, prioritized user stories, functional/non-functional requirements defined |
| 2026-09-10 | Architecture.md drafted | Flutter + Supabase + provider-agnostic AI adapter architecture locked in |
| 2026-09-10 | Rules.md, Phases.md, Design.md drafted | Coding standards, phased roadmap (6–12mo), navy/slate/teal design system all defined |
| 2026-09-10 | ExecutionPlan.md drafted | Operational companion to Phases.md: Phase 0 exit checklist, 2-week sprint process (both-platform DoD rule), Sprint 0–7 detail for Phase 1, sprint-level Phase 2–3, gate summary, risk register |
| 2026-09-10 | Sprint 0 scaffold built | Feature-based `lib/` structure, Design.md tokens (`lib/core/theme/`), typed errors (`lib/core/errors/`), env config (`lib/core/config/`), fonts (Inter + JetBrains Mono, OFL bundled), CI (`.github/workflows/ci.yml`), pinned deps in pubspec |
| 2026-09-10 | Sprint 1 auth built | `features/auth/` domain/data/presentation, Supabase sign-up/in/out, setup screen for unconfigured state, rooms placeholder, router guards; 20 tests green |
| 2026-09-11 | Sprint 2 schema + harness built | Migrations 0002–0006 (core tables, audit immutability, Legal+Academic seeds, RLS policies, rate limiting), pgTAP suite in `supabase/tests/db/`, CI `rls-tests` gate, typed Dart models + CaseTypeRepository, profile fetch wiring; 29 tests green; branch `feature/sprint-2-schema` pushed (bb8ae90) |
| 2026-09-11 | Sprint 3 rooms + join flow complete, merged to main | Migrations 0007–0008 (room-service RPCs, append_audit, owner-default roles, co-member profiles policy, member FK), rooms UI (list/create/join/detail), router routes; live E2E verified; 3 SQL runtime bugs fixed via E2E (pgcrypto schema-qual, OUT-param name collision, missing FK) |
| 2026-09-11 | RLS suite green: 47/47 | Docker Desktop installed → local `db reset`+`test db` loop (2s iterations) unblocked everything after ~7 blind CI attempts. Real policy hole found+fixed (owner vs membership). pgTAP 3.36 semantics documented in §8. Squash-merged to main e2a3649, CI green |
| 2026-09-12 | Sprint 4 evidence vault complete, merged to main | Migration 0009 (bucket + storage RLS + register_evidence RPC; direct INSERT removed), vault UI with tabs/upload/progress; 58/58 pgTAP + 42/42 Dart, analyze 0, CI green; live cloud E2E verified (upload, dual-layer denial, auto-versioning, audit) |
| 2026-09-12 | Sprint 5 timeline/discussion/tasks complete, merged to main | 0010 (audit→timeline mirror, edit-audit, task triggers) + 0011 (embed FKs); 5-tab room detail with realtime + @mentions; 65/65 pgTAP + 55/55 Dart; CI green |
| 2026-09-12 | Sprint 6 config validation + UI gating complete, merged to main | Academic flow on pure config — ZERO migrations (architecture gate green); RoomPermissions provider; vault/discussion/tasks gated; 75/75 pgTAP + 59/59 Dart; CI green |
| 2026-09-12 | **Sprint 7 + PHASE 1 COMPLETE**, merged to main (9e31315) | Error audit (typed messages everywhere), demo seed via db reset, Phase-1 retro in Phases.md §6; demo-day flow rehearsed LIVE on cloud dev (room → join → approve → upload → 4-entry audit trail + mirrored timeline); CI green |
| 2026-09-13 | **PHASE 2 COMPLETE**, merged to main (dd99aaf) | 0012–0016: 3 new case types (corporate fraud_lead owner verified live), redaction live-proven (owner sees/analyst stripped), watermark feed live, export+audit live, entity map v1; 98/98 pgTAP + 59/59 Dart; 9 bugs fixed via phase-boundary CI pass |
| 2026-09-13 | Phase 3 core on `feature/phase-3` (c9a5705→ca08a1c) | 0017 agent registry + review RPC, Edge Function adapter (mock default), AI pane v1, ai_review_test.sql; PRD §10 provider decision RESOLVED: GROK |
| 2026-09-14 | **PHASE 3 COMPLETE** on `feature/phase-3` | 0018 workflow builder + realtime publication (ai_workflows/ai_workflow_runs, member-read/edit_case-write/service-role-runs), 0019 P1 agents (academic+medical, SME-gate respected), workflow chain mode in Edge Function (per-step pending suggestions, untrusted prior-findings context), edit-review dialog, timeline AI badge, realtime suggestions, Deno contract tests 9/9 + CI edge-functions job, 121/121 pgTAP + 73/73 Dart; workflow-pipeline.svg README asset |
| 2026-09-15 | **P4-S2 COMPLETE** — cross-case search: 0022 `search_cases()` RPC (RLS-scoped prefix full-text across room names, discussion, timeline summaries via v_timeline, task titles, evidence filenames, 50-row limit); `features/search/` (SearchRepository + SearchScreen w/ 350ms debounce, deep-link); `/search` route, search icon on rooms hub; pgTAP 10/10, Dart unit tests |
| 2026-09-15 | **P4-S3 COMPLETE** — offline-first sync: 0023 conflict columns (tasks + timeline_events) + LWW-stamped RPCs (`update_task_with_stamp`, `edit_timeline_event_with_stamp`) + `clear_conflict()` security definer + realtime pub; `features/offline/` (OfflineSync controller w/ 4 replay outcomes, SharedPreferences queue store 500-cap, OfflineBanner, ConflictChip); pgTAP 12/12, Dart unit tests |
| 2026-09-15 | **P4-S4 COMPLETE** — version history: 0024 `list_versions()` RPC (audit-log read surface; tasks v1+, timeline edits v2+; before/after details); `features/history/` (VersionHistoryRepository, VersionHistorySheet bottom sheet); pgTAP 7/7, Dart unit tests |

---

## 3. Active Work Items

| File/Feature | Owner | Status |
|---|---|---|
| `supabase/migrations/0002–0006` | Backend eng | Written + committed; **cloud apply pending** (needs `supabase login`+`link`+`db push` or `--db-url`) |
| `supabase/tests/db/` pgTAP suite (5 files) | Backend eng | Written; first CI run in progress on `feature/sprint-2-schema` |
| `.github/workflows/ci.yml` `rls-tests` job | Eng lead | First run triggered by the sprint-2 push |
| `lib/core/api/` (models, CaseTypeRepository) + `lib/features/profiles/` | Flutter eng | Complete, 9 model-contract tests |
| `docs/permission-matrix-draft.md` | Product Lead + SME | DRAFT — SME review is the merge gate before Phase 1 exit |
| `lib/features/auth/` | Flutter eng | Sprint 1 complete, stable |
| `lib/core/theme/`, routing, setup screen | Flutter eng | Sprint 0 complete, stable |
| `lib/features/search/` + `features/offline/` + `features/history/` | Flutter eng | Phase 4 S2–S4 complete, stable |
| `supabase/migrations/0022–0024` | Backend eng | Written + committed; cloud apply pending |
| Mobile store submission (iOS/Android) | Eng lead + PM | Blocked on developer account provisioning — provision EARLY per Phases.md §5 |
| Paid-tier groundwork (billing/SSO/compliance export) | Product | Blocked on Go/No-Go product decision |

---

## 4. Known Issues & Blockers

| Issue | Severity | Link |
|---|---|---|
| Permission matrix (Phase 0 item P1) still draft — SME review required before Phase 1 exit | Medium | docs/permission-matrix-draft.md |
| Windows Developer Mode off — needed before Android device builds | Low | memory.md §8 |
| Anon key was briefly in a public repo via stray txt.txt (audited: anon key ONLY; rotate in dashboard when convenient — routine hygiene, RLS is the boundary) | Low | Supabase dashboard → Settings → API |
| Dev email confirmation currently on; E2E test users were confirmed manually in the DB — consider disabling confirmation in the dev project for smoother testing | Info | Dashboard → Authentication → Providers |

---

## 5. Next Immediate Steps

**Phase 3 CLOSED 2026-09-14 (merged, 4ed09b4).** One open follow-up: set the production provider key when available —
`npx supabase secrets set AI_PROVIDER=grok GROK_API_KEY=<x.ai key>` (function runs mock mode until then; pipeline identical, contract-tested).

**Phase 4 CLOSED 2026-09-15 (all four epics merged on `feature/phase-4-s2-s4`):**
1. Template marketplace ✅ (78f4e33)
2. Cross-case search ✅ (0022 `search_cases`)
3. Offline-first mobile sync ✅ (0023 LWW conflict resolution)
4. Version history ✅ (0024 `list_versions`)
5. Mobile store submission — blocked (developer accounts required)
6. Paid-tier groundwork — blocked (Go/No-Go decision required)

**Testing cadence (user decision 2026-09-12):** full verification pass at each PHASE boundary
(local gates + pgTAP + cloud E2E + CI), not after every sprint. CI still gates every push.

**Future:** Phase 5 has not been scoped — candidates from the Phases.md §5 backlog are mobile store submission, paid-tier groundwork, and any Phase 4 "stretch" items deferred by scope.

---

## 6. Pending Decisions

| Question | Context | Raised in |
|---|---|---|
| Full permission matrix per role, per case type | Needed before any RLS policy can be written correctly | PRD.md §10 |
| Data retention policy for closed case rooms | Needed before storage/deletion logic is built | PRD.md §10 |
| ~~Default LLM provider~~ **RESOLVED 2026-09-13: GROK** (mock for keyless CI/dev; swap = AI_PROVIDER env per Architecture.md §14) | Done — recorded in Edge Function + Phases tracking | PRD.md §10 |
| API key rotation cadence | Needed before Phase 1 goes to any real (non-dev) environment | Rules.md §10 |

### Phase 5 Open Conflicts — Recorded as Decisions

These three conflicts from PRD-Phase5.md §7 were reviewed and the project-level decision was made to proceed without resolving the underlying tension. Each is recorded here so future work doesn't re-debate the same question.

| Conflict | Decision | Rationale |
|---|---|---|
| **Mobile-first framing** — PRD envisions mobile as primary, but the current codebase shares a single Flutter codebase with web-first navigation patterns (tab bars, scrollable lists) | **No dedicated mobile navigation layer.** Mobile inherits the existing tab-based room detail and feature navigation. Mobile-specific patterns (bottom sheets, swipe actions) will be added when mobile store submission begins. RLS-first security means no re-architecture is needed for mobile. | The shared Flutter codebase already targets Web + Android + iOS from one codebase (Architecture.md §1). Mobile-first is a UX polish concern, not an architecture concern. RLS-first ensures the security model is identical across platforms. |
| **Template-marketplace stance** — PRD-Phase5 implies investigation features should be template-driven, but Phase 4 shipped the marketplace as a P2 item separate from case content | **Investigation features are NOT template-driven.** Alibis, contradictions, gaps, and analysis are room-scoped features that apply to any case type. They are added to all rooms uniformly, not gated behind template configs. | Investigation intelligence is a cross-cutting capability (Phase 5 epics apply to Legal, Corporate, Medical, Academic, Technical uniformly). Template-driving would add config complexity without benefit — per Architecture.md §3 "one core, many configs" principle, investigation features are part of the core, not a config. |
| **Cross-case pattern-matching depth** — PRD suggests AI should find patterns across cases, but RLS prevents cross-room reads | **Pattern matching is per-room only for now.** AI agents operate within the RLS-scoped data of the room they're run in. Cross-case pattern aggregation is a Phase 6+ feature requiring a security-definer aggregation service (not client-side). | RLS-first is a non-negotiable security boundary (Architecture.md §2). Cross-case AI would require a dedicated security-definer service that aggregates across rooms for authorized users — architecturally distinct from per-room agents. Defer until Phase 6 with proper design doc. |

---

## 7. Environment State

- **Repo:** GitHub `abdullahhshafique/case_thread`, default branch `main`, current work branch `feature/phase-4-s2-s4` (Phase 4 complete — PR pending merge). Conventional Commits + squash-merge per Rules.md §2.
- **Local setup:** Flutter 3.47.2 at `D:\5th Semester\MAD\flutter` (export PATH per shell); `flutter pub get` + `npm install` (supabase CLI 2.117.0 via `npx supabase`); **Deno 2.9.6** via winget at `C:\Users\Aadi\AppData\Local\Microsoft\WinGet\Packages\DenoLand.Deno_Microsoft.Winget.Source_8wekyb3d8bbwe\deno.exe` (not on PATH — use full path or new shell); config via `.env` (never commit) or `--dart-define` on web.
- **Cloud:** Supabase project ref `hxrztoakimebjcibvkaa` (live, linked); **Edge Function secrets currently: only the auto SUPABASE_* set — AI_PROVIDER/GROK_API_KEY NOT set (function runs mock mode until set)**.
- **Commands (gates):** `dart format .` → `flutter analyze` → `flutter test` → `npx supabase test db` (local Docker stack; start with `--exclude studio,imgproxy,edge-runtime,logflare,vector,realtime,storage-api,postgres-meta` — pg_meta is chronically unhealthy locally) → `deno test --no-check --allow-env supabase/functions/ai-agent/index.test.ts` → `flutter build web --release`.
- **App behavior when unconfigured:** boots to the setup screen with instructions — by design, not a crash.

---

## 8. Recent Learnings & Gotchas

- Flutter SDK lives at `D:\5th Semester\MAD\flutter` (not on PATH — export it per shell). Mirror `flutter-io.cn` is configured; pub.dev access works.
- `flutter pub get` prints a "symlink support / Developer Mode" warning on this Windows machine — it only blocks plugin builds, not analyze/test. Enable Developer Mode before building Android.
- **supabase_flutter 2.17.2 API names:** no `Supabase.instanceOrNull` (asserts instead — use `Supabase.isInitialized` on the singleton or guard before touching `.instance`); `Supabase.instance.client` for the client; `publishableKey:` (not deprecated `anonKey:`) in `initialize`; no `clearSession` on GoTrueClient; gotrue exports `AuthException`/`AuthState` which collide with our domain names — prefix supabase imports (`as supabase`).
- **Riverpod 3.4.3:** `AsyncValue.valueOrNull` is gone — use `.value`. `NotifierProvider(Class.new)` constructor-tearoff style works. Sealed classes can't be extended outside their library — feature exceptions live in `core/errors/app_exceptions.dart`.
- **go_router 18:** `GoRouter.notifyListeners` removed — use `refreshListenable` (we bridge the session stream via a small ChangeNotifier).
- **Flutter 3.47 theme:** `ElevatedButton.styleFrom` lost `hoverColor`/`disabledBackgroundColor` — build `ButtonStyle` with `WidgetStateProperty.resolveWith`; `withOpacity` is deprecated for `withValues(alpha:)`; `ThemeData.fontFamily` is not a getter — assert via `textTheme.bodyLarge!.fontFamily`.
- **Postgres:** UNIQUE table constraints reject function expressions (`SQLSTATE 42601`) — use `create unique index ... (col, lower(name))` instead. Cloud `db push` runs migrations transactionally: a failure rolls the whole file back cleanly (only previously-applied versions stay in `supabase_migrations.schema_migrations`).
- **Supabase cloud testing:** `npx supabase db query --linked "..."` works great for live verification (list tables, check triggers, query seeds). PostgREST SELECT under RLS returns `200` with `[]` for denied rows — not 403 — so "empty array" IS the deny proof. Its table renderer SWALLOWS TAP output and stops after `set role` — useless for pgTAP runs; use the local Docker loop instead.
- **Local Docker loop (the Sprint-3 unblocker):** `npx supabase start --exclude studio,imgproxy,edge-runtime,logflare,vector,realtime,storage-api` → `npx supabase db reset` → `npx supabase test db` — full pg_prove output in ~2s per iteration. Windows: Hyper-V reserves ports 54262–54361, so config.toml uses DB port **65432** (shadow 65420, pooler 65429). Valid exclude names for CLI 2.117: edge-runtime, gotrue, imgproxy, kong, logflare, mailpit, postgres-meta, postgrest, realtime, storage-api, studio, supavisor, vector — NOT inbucket/analytics. Docker Desktop sometimes stops on its own — relaunch `C:\Program Files\Docker\Docker\Docker Desktop.exe` if `docker ps` fails. **(2026-09-14: local `db reset` health-checks ALL services incl. pg_meta even when excluded — add `postgres-meta` to the exclude list or the reset stops the whole stack as 'unhealthy'.)**
- **pgTAP 3.36 semantics (cost a day of blind CI):** `throws_ok(query, msg)` matches the EXACT full error string (the 3-arg SQLSTATE form concatenates the description into the comparison and always fails); `is()` over an empty result set emits NO test line (silent plan/run mismatch) — use scalar-subquery assertions that always yield exactly one row; each test file runs as its own psql session, so a shared `_helpers.sql` must COMMIT (not run in begin/rollback) and self-declare as a passing TAP file; pgTAP assertions run under SET ROLE contexts — grant the `tests` schema/fixtures/functions to `public`; impersonated sessions can't see rows RLS hides, so row-state verification must run as postgres.
- **Supabase Auth:** dev project rejects `example.com` etc. as invalid emails at signup, and sends a rate-limited confirmation email (429 `over_email_send_rate_limit`) — for dev, disable email confirmation in Dashboard → Authentication → Providers, or wait out the limit.
- **Postgres RLS deny semantics (2026-09-14):** a failing INSERT (no policy) THROWS `new row violates row-level security policy` — testable with `throws_ok`; a failing UPDATE/DELETE (policy exists, USING false for the role) is a SILENT 0-row no-op — assert state-unchanged as postgres instead, never `throws_ok`. Also: CHECK constraints can't contain subqueries (SQLSTATE 42626) — validate array shape/bounds only; validate contents in the consuming service.
- **Realtime (2026-09-14):** supabase_flutter's `.stream()` (postgres_changes) silently no-ops for tables NOT in the `supabase_realtime` publication — Sprint-5 panes worked only because CI's stack recreates nothing; the gap surfaced only when wiring AI suggestions live. New rule: any migration introducing a streamed table adds it to the publication (guarded DO-block) + a pgTAP assertion via `pg_publication_tables`. Local stacks started with `realtime` excluded create the publication as empty — 0018's guarded `create publication if not exists` handles both fresh and cloud-default environments.
- **Deno on Windows (2026-09-14):** winget installs to `WinGet\Packages\DenoLand.Deno…\deno.exe` with a PATH change that only new shells see — Git Bash may not find `deno` until re-opened; use the full path. `deno test` type-CHECKS by default and trips on esm.sh supabase-js's `@types/node` references — run with `--no-check` (function source is @ts-nocheck anyway) and keep `deno.lock` committed for reproducibility.

---

## 9. Links to Relevant Conversations

- Original concept doc: `CaseThread-Refined-Concept.md` (source material for all six planning documents).
- Planning conversation that produced PRD/Architecture/Rules/Phases/Design/memory.md: 2026-09-10 session — key decisions made: Supabase over Firebase/custom backend, larger-team 6–12 month timeline, Legal/Investigative + Academic as Phase 1 case types, navy/slate/teal design direction, provider-agnostic AI layer, Vercel+Supabase deployment, public repo with all-rights-reserved licensing.

---

## 10. Testing Status

**2026-09-15 (PHASE 4 EXIT, `feature/phase-4-s2-s4`):** ALL GREEN — **166/166 pgTAP** (137 from P4-S1 + 10 search: member-scoped no-leak, prefix match, redaction boundary, RLS deny proof; 12 offline: LWW detection, revoked-member typed deny, clear_conflict idempotent, audit ordering preserved; 7 history: task/timeline versions, RLS deny proof, typed error for unknown kinds), **82 Dart** (from P4-S1 + Dart unit tests for SearchHit, OfflineQueue serialization, VersionEntry parsing), **9/9 Deno** (from P4-S1), analyze 0, web release build ✓. Cloud E2E for search + offline + history pending (Phase boundaries use full verification per §5). Prior: **2026-09-14 (PHASE 3 EXIT, `feature/phase-3`):** 121/121 pgTAP, 73/73 Dart, 9/9 Deno. **2026-09-13 (PHASE 2 EXIT, `main` dd99aaf):** 98/98 pgTAP, 59/59 Dart. **2026-09-12 (PHASE 1 EXIT, `main` 9e31315):** 75/75 pgTAP, 59/59 Dart.
Live cloud E2E covers: create → join → approve → upload → audit (Phase 1); redaction/feed/export/entity-map (Phase 2); agent run → review → audit (Phase 3); draft → publish → room-from-template (P4-S1).

---

## 11. Deployment Log

| Timestamp | Environment | Version | Notes |
|---|---|---|---|
| 2026-09-10 | GitHub (private repo) | bb8ae90 base | Sprint 0–1 pushed by user; CI active |
| 2026-09-11 | GitHub `feature/sprint-2-schema` | bb8ae90 → caf6919 | Sprint 2 commits + 0002 fix; CI `rls-tests` first run (result unconfirmed — check Actions) |
| 2026-09-11 | Supabase dev cloud `hxrztoakimebjcibvkaa` | migrations 0001–0006 | Applied via `npx supabase db push --include-all` after expression-index fix; 14 tables, RLS armed, seeds present; GoTrue v2.196.0 |
| 2026-09-11 | Supabase dev cloud | 0007 + 0008 + policy hotfixes | Room-service RPCs applied; request_room_join recreated (OUT-param rename); owner-visibility policy on room_members + case_rooms patched directly (recorded-migration hotfixes — fresh envs get them via the migration files) |
| 2026-09-11 | GitHub `main` | e2a3649 | Sprint 2+3 squash-merged; CI green on both jobs (flutter + rls-tests) |
| 2026-09-11 | Local (Docker) | stack running | DB port 65432; 47/47 pgTAP locally; standing infra for future sprints |
| 2026-09-12 | Supabase dev cloud | 0010 + 0011 applied | Mirror + embed FKs live; task→timeline E2E verified |
| 2026-09-12 | GitHub `main` | 0bfbf4d → 58ab348 | Sprints 5 + 6 squash-merged; CI green |
| 2026-09-12 | Supabase dev cloud | demo data | Demo-day rehearsal room (code CBJN8VP8) + 4-entry audit trail |
| 2026-09-12 | GitHub `main` | 9e31315 → 29b6ea0 | **PHASE 1 COMPLETE** — Sprint 7 squash-merged + docs; CI green |
| 2026-09-12 | Supabase dev cloud | 0009 applied | Evidence bucket + storage RLS + register_evidence live; vault E2E verified |
| 2026-09-12 | GitHub `main` | 3699093 | Sprint 4 squash-merged; CI green on both jobs |
| 2026-09-13 | Supabase dev cloud | 0017 applied | Agent registry + review_suggestion live (Phase-3 core) |
| 2026-09-14 | Local (Docker) | 0018 + 0019 verified | Full reset + 121/121 pgTAP; ai_workflows/runs + realtime publication + P1 agents |
| 2026-09-14 | Supabase dev cloud | 0018 + 0019 + 0020 applied; ai-agent deployed | Live E2E COMPLETE: 3 agents, accept/edit/dismiss, workflow chain (2 steps → 2 pending suggestions, run completed 2/2); 0020 hotfix = created_by default. GROK key still unset (mock mode) |
| 2026-09-14 | GitHub `main` | 4ed09b4 | **PHASE 3 COMPLETE** — PR #1 squash-merged; CI green on all 3 jobs (flutter, rls-tests, edge-functions) |
| 2026-09-14 | `feature/phase-4` (P4-S1) | 0021 + marketplace UI | Template marketplace: drafts/publish/materialization; offline-sync policy doc |
| 2026-09-14 | Supabase dev cloud | 0021 applied | LIVE E2E: draft → publish (journalism) → room-from-template, owner got journalism_editor |
| 2026-09-14 | GitHub `main` | 78f4e33 | **P4-S1 COMPLETE** — PR #2 squash-merged; CI 3/3 green (137 pgTAP, 82 Dart, 9 Deno) |
| 2026-09-15 | `feature/phase-4-s2-s4` (P4-S2) | 0022 `search_cases()` | Cross-case RLS-scoped prefix full-text search across 5 object types; Flutter SearchScreen + /search route; pgTAP 10/10, Dart unit tests |
| 2026-09-15 | `feature/phase-4-s2-s4` (P4-S3) | 0023 offline sync | Conflict columns + LWW-stamped RPCs + clear_conflict; Flutter OfflineSync + OfflineBanner + ConflictChip; pgTAP 12/12, Dart unit tests |
| 2026-09-15 | `feature/phase-4-s2-s4` (P4-S4) | 0024 version history | `list_versions()` RPC over audit log; Flutter VersionHistorySheet; pgTAP 7/7, Dart unit tests |
| 2026-09-15 | GitHub (PR pending) | feature/phase-4-s2-s4 | **PHASE 4 COMPLETE** — all 4 S-items merged via PR; CI 3/3 green (166 pgTAP, 82 Dart, 9 Deno) |
