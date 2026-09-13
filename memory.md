# CaseThread — Project Memory

**Last updated:** 2026-09-11 (Sprint 3 complete, merged to main)
**Update this file at the end of every work session — it's the fastest way for anyone (including a resuming AI assistant) to get back up to speed.**

---

## 1. Current Project State Summary

**PHASE 2 COMPLETE — merged to `main` (dd99aaf).** All five original-concept case types are live (Legal, Academic, Corporate, Technical, Medical [medical domain fields behind the SME gate]) as pure config data — the one-core-many-configs architecture now carries 5 domains. Field-level redaction is ENFORCED server-side (security-barrier + security-invoker views; `view_privileged` strips payload.privileged per-role — proven live: owner sees the privileged field, analyst sees it stripped from the same event). Activity feed: per-room watermarks + v_activity_feed ('what changed since you opened this room'). Export: server-compiled, permission-gated, audited (report_exported). Entity map v1: edit_case-gated writes, recursive-CTE transitive chains, redaction-aware. 98/98 pgTAP (23 new contracts), 59/59 Dart, analyze 0, CI green; 9 real bugs found by the phase-boundary CI pass (FK ordering, role-pk collision, view-RLS → security_invoker, ambiguous refs, SRF-in-EXISTS, paren nesting, txn-stable now()). **Next:** Phase 3 (AI agent workflows per Phases.md §4) — LLM provider decision from PRD §10 needed first.

---

## 2. Recently Completed Tasks

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

**Phase 2 kickoff (Phases.md §3 order):**
1. Corporate & Technical case-type seeds (config rows only — the Sprint-6 proof says zero migrations)
2. Medical case type — SME consult gate FIRST (PRD §10 HIPAA-adjacent questions)
3. Field-level redaction (RLS contract tests required — Rules.md §7)
4. Notification/activity feed
5. PDF/Word export (sanitized, no privileged leakage)
6. Entity-relationship map v1 (recursive CTEs)

**Testing cadence (user decision 2026-09-12):** full verification pass at each PHASE boundary
(local gates + pgTAP + cloud E2E + CI), not after every sprint. CI still gates every push.

---

## 6. Pending Decisions

| Question | Context | Raised in |
|---|---|---|
| Full permission matrix per role, per case type | Needed before any RLS policy can be written correctly | PRD.md §10 |
| Data retention policy for closed case rooms | Needed before storage/deletion logic is built | PRD.md §10 |
| Default LLM provider at demo day vs. fully user-configurable | Needed before Phase 3 AI Adapter Layer defaults are set | PRD.md §10 / Architecture.md §14 |
| API key rotation cadence | Needed before Phase 1 goes to any real (non-dev) environment | Rules.md §10 |

---

## 7. Environment State

- **Repo:** GitHub `abdullahhshafique/case_thread`, default branch `main`, current work branch `feature/sprint-2-schema` (bb8ae90). Conventional Commits + squash-merge per Rules.md §2.
- **Local setup:** Flutter 3.47.2 at `D:\5th Semester\MAD\flutter` (export PATH per shell); `flutter pub get` + `npm install` (supabase CLI 2.117.0 via `npx supabase`); config via `.env` (never commit) or `--dart-define` on web.
- **Cloud:** Supabase project ref `hxrztoakimebjcibvkaa` (live, GoTrue v2.196.0); **CLI not linked** — `npx supabase login` (token: supabase.com/dashboard/account/tokens) then `npx supabase link --project-ref hxrztoakimebjcibvkaa` then `npx supabase db push`.
- **Commands (gates):** `dart format .` → `flutter analyze` → `flutter test` (29 green) → CI runs `flutter build web --release` + `supabase db reset` + `supabase test db` on GitHub runners (no local Docker needed).
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
- **Local Docker loop (the Sprint-3 unblocker):** `npx supabase start --exclude studio,imgproxy,edge-runtime,logflare,vector,realtime,storage-api` → `npx supabase db reset` → `npx supabase test db` — full pg_prove output in ~2s per iteration. Windows: Hyper-V reserves ports 54262–54361, so config.toml uses DB port **65432** (shadow 65420, pooler 65429). Valid exclude names for CLI 2.117: edge-runtime, gotrue, imgproxy, kong, logflare, mailpit, postgres-meta, postgrest, realtime, storage-api, studio, supavisor, vector — NOT inbucket/analytics. Docker Desktop sometimes stops on its own — relaunch `C:\Program Files\Docker\Docker\Docker Desktop.exe` if `docker ps` fails.
- **pgTAP 3.36 semantics (cost a day of blind CI):** `throws_ok(query, msg)` matches the EXACT full error string (the 3-arg SQLSTATE form concatenates the description into the comparison and always fails); `is()` over an empty result set emits NO test line (silent plan/run mismatch) — use scalar-subquery assertions that always yield exactly one row; each test file runs as its own psql session, so a shared `_helpers.sql` must COMMIT (not run in begin/rollback) and self-declare as a passing TAP file; pgTAP assertions run under SET ROLE contexts — grant the `tests` schema/fixtures/functions to `public`; impersonated sessions can't see rows RLS hides, so row-state verification must run as postgres.
- **Supabase Auth:** dev project rejects `example.com` etc. as invalid emails at signup, and sends a rate-limited confirmation email (429 `over_email_send_rate_limit`) — for dev, disable email confirmation in Dashboard → Authentication → Providers, or wait out the limit.

---

## 9. Links to Relevant Conversations

- Original concept doc: `CaseThread-Refined-Concept.md` (source material for all six planning documents).
- Planning conversation that produced PRD/Architecture/Rules/Phases/Design/memory.md: 2026-09-10 session — key decisions made: Supabase over Firebase/custom backend, larger-team 6–12 month timeline, Legal/Investigative + Academic as Phase 1 case types, navy/slate/teal design direction, provider-agnostic AI layer, Vercel+Supabase deployment, public repo with all-rights-reserved licensing.

---

## 10. Testing Status

**2026-09-13 (PHASE 2 EXIT, `main` dd99aaf):** ALL GREEN — 98/98 pgTAP (23 new: redaction, feed, export, entity map, academic+config flows), 59/59 Dart, analyze 0. Live cloud E2E across every Phase-2 feature. Prior: **2026-09-12 (PHASE 1 EXIT, `main` 9e31315):** ALL GREEN — 75/75 pgTAP RLS contract tests (CI +
local Docker loop, with demo seed present), 59/59 Dart tests, analyze 0, web release build 3.1MB.
Live cloud E2E covers: create → join → approve → upload → audit. Coverage spans profiles, audit
immutability, room/join lifecycle, permission-gated writes across all content tables, every 0007
RPC (rotation, rate limiting), the vault (dual-layer denials, versioning), the Academic config
flow, and the timeline mirror. Phase-2 testing boundary: after step 6 of §5.

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
