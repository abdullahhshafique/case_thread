# CaseThread — Project Memory

**Last updated:** 2026-09-10 (Sprint 0–1 session)
**Update this file at the end of every work session — it's the fastest way for anyone (including a resuming AI assistant) to get back up to speed.**

---

## 1. Current Project State Summary

Sprint 0 + Sprint 1 (auth) are code-complete as of 2026-09-10: the Flutter app is scaffolded feature-first (`lib/core/` + `lib/features/{auth,rooms,setup}/`) with the full Design.md dark token system, Supabase email/password auth behind a repository interface, routing guards (unconfigured → setup screen, unauthenticated → auth screen), a 20-test suite, GitHub Actions CI (format/analyze/test/web-build), and a draft `profiles` migration (Sprint 2 preview). All gates green locally: format clean, `flutter analyze` zero issues, 20/20 tests, web release build. **Not yet done:** git repo init + Supabase dev project provisioning (Phase 0 exit checklist items P2–P3 in ExecutionPlan.md §1) — the app boots to the setup screen until `.env`/dart-defines provide credentials. Next: Sprint 2 (full schema + pgTAP harness) once Supabase is provisioned.

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

---

## 3. Active Work Items

| File/Feature | Owner | Status |
|---|---|---|
| `lib/features/auth/` (domain/data/presentation + providers) | Flutter eng | Sprint 1 complete, tested |
| `lib/core/theme/` (tokens, theme builder) | Flutter eng | Sprint 0 complete, token contract tests in `test/core/theme/` |
| `lib/core/routing/app_router.dart` | Flutter eng | Sprint 0 complete (auth redirect + refreshListenable) |
| `supabase/migrations/0001_profiles.sql` | Backend eng | DRAFT — apply once Supabase dev project exists (Phase 0 item P3) |
| `.github/workflows/ci.yml` | Eng lead | Sprint 0 complete — push repo to GitHub to activate (Phase 0 item P2) |

---

## 4. Known Issues & Blockers

| Issue | Severity | Link |
|---|---|---|
| No Supabase dev project provisioned yet — app boots to setup screen; Sprint 2 schema work blocked until provisioned | High (blocks Sprint 2) | ExecutionPlan.md §1 P3 |
| Not a git repo yet — CI and Vercel deploys inactive | High (blocks Phase 0 exit) | ExecutionPlan.md §1 P2 |
| Windows Developer Mode off — `flutter pub get` warns about symlink support; plugin/Android builds need it enabled | Low (analyze/test unaffected) | memory.md §8 |
| Permission matrix (Phase 0 item P1) still draft | Medium (blocks RLS merge gate, not draft work) | ExecutionPlan.md §1 |

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

- **Repo:** local only — NOT yet a git repository (Phase 0 item P2 pending: init on `main` with branch protection + squash-merge, push to GitHub to activate CI).
- **Local setup:** Flutter 3.47.2 at `D:\5th Semester\MAD\flutter` (export PATH per shell); `flutter pub get`; config via `.env` (copy `.env.example`) for Android/desktop or `--dart-define` for web; `supabase/migrations/0001_profiles.sql` is a draft — apply once the dev project exists (P3 pending).
- **Commands:** `dart format .` → `flutter analyze` → `flutter test` (all green 2026-09-10) → `flutter build web --release` (2.6 MB main.dart.js).
- **App behavior when unconfigured:** boots to the setup screen with instructions — by design, not a crash.

---

## 8. Recent Learnings & Gotchas

- Flutter SDK lives at `D:\5th Semester\MAD\flutter` (not on PATH — export it per shell). Mirror `flutter-io.cn` is configured; pub.dev access works.
- `flutter pub get` prints a "symlink support / Developer Mode" warning on this Windows machine — it only blocks plugin builds, not analyze/test. Enable Developer Mode before building Android.
- **supabase_flutter 2.17.2 API names:** no `Supabase.instanceOrNull` (asserts instead — use `Supabase.isInitialized` on the singleton or guard before touching `.instance`); `Supabase.instance.client` for the client; `publishableKey:` (not deprecated `anonKey:`) in `initialize`; no `clearSession` on GoTrueClient; gotrue exports `AuthException`/`AuthState` which collide with our domain names — prefix supabase imports (`as supabase`).
- **Riverpod 3.4.3:** `AsyncValue.valueOrNull` is gone — use `.value`. `NotifierProvider(Class.new)` constructor-tearoff style works.
- **go_router 18:** `GoRouter.notifyListeners` removed — use `refreshListenable` (we bridge the session stream via a small ChangeNotifier).
- **Flutter 3.47 theme:** `ElevatedButton.styleFrom` lost `hoverColor`/`disabledBackgroundColor` — build `ButtonStyle` with `WidgetStateProperty.resolveWith`; `withOpacity` is deprecated for `withValues(alpha:)`; `ThemeData.fontFamily` is not a getter — assert via `textTheme.bodyLarge!.fontFamily`.

---

## 9. Links to Relevant Conversations

- Original concept doc: `CaseThread-Refined-Concept.md` (source material for all six planning documents).
- Planning conversation that produced PRD/Architecture/Rules/Phases/Design/memory.md: 2026-09-10 session — key decisions made: Supabase over Firebase/custom backend, larger-team 6–12 month timeline, Legal/Investigative + Academic as Phase 1 case types, navy/slate/teal design direction, provider-agnostic AI layer, Vercel+Supabase deployment, public repo with all-rights-reserved licensing.

---

## 10. Testing Status

**2026-09-10 (main, local):** All 20 tests pass — token contract tests (`test/core/theme/`), app smoke/routing tests (`test/app_test.dart`), auth form widget tests with a fake repository (`test/features/auth/`). `flutter analyze` zero issues; `dart format` clean; web release build green. CI not yet active (repo not pushed). No RLS/permission tests yet — they arrive with the Sprint 2 schema + pgTAP harness.

---

## 11. Deployment Log

| Timestamp | Environment | Version | Notes |
|---|---|---|---|
| *(none yet)* | — | — | First deploy will be a Vercel staging preview once Phase 1 scaffolding lands |
