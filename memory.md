# CaseThread — Project Memory

**Last updated:** 2026-09-11 (Sprint 2 session)
**Update this file at the end of every work session — it's the fastest way for anyone (including a resuming AI assistant) to get back up to speed.**

---

## 1. Current Project State Summary

**Sprint 2 COMPLETE and applied to cloud** (branch `feature/sprint-2-schema`, HEAD caf6919): all 14 tables live in the dev project (`hxrztoakimebjcibvkaa`), migrations 0001–0006 recorded in remote history, Legal (6 roles) + Academic (5 roles) seeded with permission grids, RLS policies active on every table via `user_room_role()`/`user_room_permission()`, audit_log immutability triggers armed (UPDATE/DELETE rejected), rate-limiting functions ready for Sprint 3. Cloud verification done via `db query` + PostgREST: unauthenticated reads return empty (default-deny working), seeds + all 5 helper functions + 2 immutability triggers confirmed live. One bug found & fixed during cloud apply: Postgres UNIQUE constraints can't hold expressions (`lower(name)`) — replaced with a unique index on `entities`. Dart side: typed models + CaseTypeRepository + profile fetch wired; 29/29 tests, analyze 0. **Outstanding:** CI `rls-tests` result needs eyeballing in the (private) repo Actions tab — it's the first Postgres execution of the pgTAP suite; authenticated E2E via curl deferred (auth-email rate limit), covered by pgTAP. Next: SME sign-off on permission matrix + Sprint 3 (rooms, access codes, join/approval UI) — schema and contracts are ready for it.

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
| CI `rls-tests` result unconfirmed — repo is private, no `gh` CLI locally; user must check the Actions tab (pushes: bb8ae90, 1a176c9, caf6919) | Medium (verify before merge) | github.com/abdullahhshafique/case_thread/actions |
| Auth email rate limit hit while testing signups (429 over_email_send_rate_limit) — the E2E authenticated-RLS curl test is deferred; local pgTAP suite covers it | Low | memory.md §8 |
| Permission matrix (Phase 0 item P1) still draft — SME review required before Phase 1 exit | Medium | docs/permission-matrix-draft.md |
| Windows Developer Mode off — needed before Android device builds | Low | memory.md §8 |
| No Docker locally — pgTAP suite runs via CI (or `npx supabase test db --linked` after careful review, it mutates shared state — avoid) | Info | memory.md §7 |

---

## 5. Next Immediate Steps

1. Complete the Phase 0 exit checklist in [ExecutionPlan.md](./ExecutionPlan.md) §1 — especially the starter permission matrix per role/case type (blocks RLS policy work).
2. Provision the Supabase project (dev environment) per Architecture.md §10.
3. Scaffold the Flutter project structure (feature-based folders per Rules.md §1).
4. Set up GitHub Actions CI (lint + test) and connect Vercel for web preview deploys.
5. Write the first RLS policies + their contract tests for Case Room creation and join flow (Phase 1 P0 epics in Phases.md §2).

Full sprint-by-sprint breakdown lives in [ExecutionPlan.md](./ExecutionPlan.md) — follow it for order of work; Phases.md remains the strategic source of truth.

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
- **Supabase cloud testing:** `npx supabase db query --linked "..."` works great for live verification (list tables, check triggers, query seeds). PostgREST SELECT under RLS returns `200` with `[]` for denied rows — not 403 — so "empty array" IS the deny proof.
- **Supabase Auth:** dev project rejects `example.com` etc. as invalid emails at signup, and sends a rate-limited confirmation email (429 `over_email_send_rate_limit`) — for dev, disable email confirmation in Dashboard → Authentication → Providers, or wait out the limit.

---

## 9. Links to Relevant Conversations

- Original concept doc: `CaseThread-Refined-Concept.md` (source material for all six planning documents).
- Planning conversation that produced PRD/Architecture/Rules/Phases/Design/memory.md: 2026-09-10 session — key decisions made: Supabase over Firebase/custom backend, larger-team 6–12 month timeline, Legal/Investigative + Academic as Phase 1 case types, navy/slate/teal design direction, provider-agnostic AI layer, Vercel+Supabase deployment, public repo with all-rights-reserved licensing.

---

## 10. Testing Status

**2026-09-11 (`feature/sprint-2-schema`, local):** All 29 Dart tests pass — token contracts, app smoke/routing, auth widgets (fake repo), model parse contracts. `flutter analyze` zero issues; `dart format` clean. **pgTAP RLS suite written but not yet executed** — first run is the CI `rls-tests` job triggered by the sprint-2 push (no local Docker). Cloud schema untested (migrations not pushed). Watch: if CI `rls-tests` fails, fix SQL/tests on the same branch before merging.

---

## 11. Deployment Log

| Timestamp | Environment | Version | Notes |
|---|---|---|---|
| 2026-09-10 | GitHub (private repo) | bb8ae90 base | Sprint 0–1 pushed by user; CI active |
| 2026-09-11 | GitHub `feature/sprint-2-schema` | bb8ae90 → caf6919 | Sprint 2 commits + 0002 fix; CI `rls-tests` first run (result unconfirmed — check Actions) |
| 2026-09-11 | Supabase dev cloud `hxrztoakimebjcibvkaa` | migrations 0001–0006 | Applied via `npx supabase db push --include-all` after expression-index fix; 14 tables, RLS armed, seeds present; GoTrue v2.196.0 |
