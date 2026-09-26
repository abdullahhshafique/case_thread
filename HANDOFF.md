# CaseThread — Progress Handoff (for the next developer)

**Written:** 2026-09-24
**Purpose:** exact state of the project, what is done, what remains, and the immediate next steps. Another developer should be able to continue from this file alone.

---

## 1. Big picture — how much of the project is done

| Phase | Scope | State |
|---|---|---|
| Phase 0 | Planning docs | ✅ 100% |
| Phase 1 | Core platform (auth, rooms, codes, join, vault, timeline, discussion, tasks, gating) | ✅ 100% — merged to `main`, live-verified |
| Phase 2 | 5 case types, redaction, activity feed, export, entity map | ✅ 100% — merged to `main`, live-verified |
| Phase 3 | AI agent workflows (registry, Edge Function, human-in-the-loop review) | ✅ 100% — merged via PR #1; **live E2E verified** |
| Phase 4 | Marketplace, cross-case search, offline sync, version history | ✅ 100% (S1–S4) — reached `main` via the phase-6 tree; mobile store + paid tier deferred (external/decision-blocked) |
| Phase 5 | Investigation intelligence (alibis, contradictions, gaps, dashboard, case status) | ✅ 100% |
| Phase 6 | v3 Investigation Console rebuild + polish tail | ✅ 100% — squash-merged to `main` as 43048cb, tagged `v0.1.0`, CI 3/3 green |
| **UX Parity PRD Phase 1** | Light theme + debug tools | ✅ 100% (2026-09-24) — `AppColorsLight` value-swap palette, `ThemeModeNotifier` (persisted), theme toggle in the console, demo sign-in button + role-override pill (debug builds only) |
| **UX Parity PRD Phase 2** | Overview enrichment | ✅ 100% (2026-09-24) — briefing card, 3 alert cards deep-linking into Analysis sub-tabs, verified-alibi donut, `attentionCountsProvider` extended with alibi/gap breakdowns, `analysisTabRequestProvider` hoisted-tab mechanism |
| **UX Parity PRD Phase 3** | Export overhaul | ✅ 100% (2026-09-24) — export bottom sheet: formatted PDF (`pdf` + `printing`, OS save/share = download on web) + Markdown copy; same RLS-scoped `export_case_report` document |
| **UX Parity PRD Phase 4** | Evidence detail AI analysis + verify-alibi | ✅ 100% (2026-09-24) — evidence detail sheet (metadata + sha256, per-item AI run with `evidence_item_id`, permission-gated), verify-alibi flow attaching evidence ids with a required status reason |
| **UX Parity PRD Phase 5** | Discussion enhancements | ✅ 100% (2026-09-24) — star/pin (client-side, SharedPreferences per room), pinned strip, extract-to-case (manual timeline event classified `claim`) |
| **UX Parity PRD Phase 6** | Demo seeding + briefing editor | ✅ 100% (2026-09-24) — `0042_room_briefing.sql`, `supabase/seed_demo.sql` (idempotent Riverside seed, code `DEMO1234`), briefing editor sheet, `getMyRooms` column fix (`investigation_status` + `briefing` were missing from the select!) |
| **UX Parity PRD Phase 7** | Optional extras | ✅ Delivered subset (2026-09-24) — role-colored presence dots (dashboard + members pane) and "Active Xm ago" presence (`0043_presence_watermarks.sql` lets co-members read each other's watermark). **Voice notes + chat media intentionally skipped** (need recording plugin, storage bucket + policies, playback UI, message-schema changes — a separate mini-sprint) |
| **Connections graph upgrade (Obsidian-style), steps 1–4** | Force-directed layout engine, zoom/pan camera, node drag, hover highlight, filter chips, local-graph focus, search-jump, template-driven entity import | ✅ 100% (2026-09-24) — `force_layout.dart` + `_GraphView` rework + 10 physics tests; migration **0044_entity_seed.sql** + `materialize_entity_seed` RPC + pgTAP `entity_seed_test.sql` (7) + `entity_import_sheet.dart` + `SeedTemplate` model — **0044 needs a cloud push; run the pgTAP suite** |
| Phase 4 remainder (S5+) | App-store release, billing groundwork, template marketplace UI polish | ⬜ External/decision-blocked |

**Overall: 100% of the planned roadmap AND the client-requested UX Parity PRD are built.** Backend: 43 migrations (0001–0043), 27 pgTAP test files (232 declared tests), RLS on every table. Flutter: 90 lib files, 28 test files, analyze 0 at last full pass. Edge Function: deployed-able, runs mock provider until `GROK_API_KEY` is set.

---

## 2. Current branch state

```
main = everything through Phase 6 (43048cb, tagged v0.1.0)
working tree = UX Parity phases 1–7 (2026-09-24 session) — COMMIT + PUSH + CI pending
```

**New migrations to push to cloud:** `0042_room_briefing.sql` (adds nullable `case_rooms.briefing`) and `0043_presence_watermarks.sql` (co-member watermark reads for presence). Plus `supabase/seed_demo.sql` — NOT a migration; run in the SQL editor after replacing `demo_user_id` in its `config` CTE.

**New Dart dependencies:** `pdf: 3.11.2`, `printing: 5.13.4` (run `flutter pub get`).

**Migration numbering note:** the old docs reserved 0042 for a "demo seed expansion" and 0043 for a "chat-media bucket". As built: **0042 = briefing column, 0043 = presence policy, demo seed lives at `supabase/seed_demo.sql`** (not a numbered migration, because it needs a real `auth.users` id that only exists in the target environment). Chat media was never built, so no bucket migration exists.

---

## 3. IMMEDIATE NEXT STEPS (in order)

### Step 1 — Run the local gates on the UX Parity work
```bash
flutter pub get
dart format .
flutter analyze   # must be 0
flutter test      # 28 test files
```
Note: no Flutter SDK was available in the authoring environment for the final session — the code was written carefully against pinned APIs but **not machine-verified**. Expect possibly a few analyzer nits; fix before pushing.

### Step 2 — Database resync
```bash
npx supabase db push --include-all          # applies 0042 + 0043 to cloud
# then in Supabase SQL editor: run supabase/seed_demo.sql
# (replace demo_user_id in the config CTE with your auth.users id)
```

### Step 3 — Commit, push, CI green, merge
Conventional Commits + squash-merge per Rules.md §2. CI: `.github/workflows/ci.yml` — `flutter` job + `rls-tests` job.

### Step 4 — Edge Function (when connectivity allows)
`npx supabase functions deploy ai-agent --project-ref hxrztoakimebjcibvkaa`; set `AI_PROVIDER=grok` + `GROK_API_KEY=<key>` via `npx supabase secrets set` for the real provider. Until then the AI pane and per-evidence analysis surface clean typed errors.

### Step 5 — E2E walkthrough of the new UX Parity features
Demo sign-in (debug) → seeded Riverside case → Overview (briefing card, alert cards deep-link, donut) → export sheet (PDF/Markdown) → Evidence → tile detail (metadata, AI run, verify-alibi) → Discussion (long-press star/pin/extract) → theme toggle → Members pane presence.

---

## 4. UX Parity implementation map (where everything lives)

| Feature | Files |
|---|---|
| Light theme | `lib/core/theme/app_colors.dart` (`AppColorsLight`), `app_theme.dart` (`buildAppTheme(brightness:)`), `theme_mode_provider.dart`, `app.dart` |
| Theme toggle + debug pill | `lib/features/rooms/rooms_screen.dart` (`_ThemeToggle`, `_DebugRolePill`), `room_permissions.dart` (`demoRoleOverrideProvider`) |
| Demo sign-in | `lib/features/auth/presentation/auth_screen.dart` (kDebugMode button, `demo@casethread.test`) |
| Briefing card + editor | `lib/features/dashboard/case_briefing_card.dart`, `lib/features/rooms/briefing_editor_sheet.dart`, `RoomsRepository.updateBriefing` |
| Alert cards + donut | `lib/features/dashboard/alert_cards.dart`, `task_donut.dart`, `dashboard_screen.dart` (layout: hero → briefing → stats → alerts → donut → charts) |
| Tab deep-link | `analysisTabRequestProvider` in `rooms_providers.dart`; listener in `analysis_pane.dart` (`initState` → `_tabs.animateTo`) |
| Export sheet + PDF | `lib/features/rooms/export_sheet.dart`, `export_pdf.dart` (`CaseReportPdf.toPdfBytes`), wired in `room_detail_screen.dart` `_export` |
| Evidence detail sheet | `lib/features/rooms/evidence_detail_sheet.dart`, wired in `vault_pane.dart` tile `InkWell`; `runAgent(evidenceItemId:)` in `ai_suggestions.dart` |
| Discussion flags | `lib/features/rooms/discussion_flags.dart` (star/pin per room), action sheet + `_PinnedStrip` + `_extractToCase` in `discussion_pane.dart`; inits in `main.dart` |
| Force graph + camera + filters | `lib/features/connections/force_layout.dart` (engine), `connections_screen.dart` (`_GraphView`: sim ticker, camera, hover, filters, focus mode, search-jump), `test/features/connections/force_layout_test.dart` |
| Presence + role dots | `lib/features/rooms/presence.dart` (`roomPresenceProvider`, `roleDotColor`, `lastSeenLabel`); used by `dashboard_screen.dart` `_AvatarStack` and `room_detail_screen.dart` `_MemberTile`; `getRoomPresence` in `activity_feed.dart` |

**New tests (10 files):** `theme_switch_test.dart`, `alert_cards_test.dart`, `case_briefing_card_test.dart`, `dashboard_layout_test.dart` (extended), `export_report_test.dart`, `evidence_detail_sheet_test.dart`, `discussion_flags_test.dart`, `presence_test.dart`, plus extended `app_theme_test.dart` and auth tests.

---

## 5. Environment / how to run

```bash
# Toolchain
#   Flutter at D:\5th Semester\MAD\flutter (add to PATH)
#   Node 24 + npx (supabase CLI pinned in package.json)
#   Docker Desktop (ONLY needed for the local pgTAP loop; flaky on this machine)

cd "D:\5th Semester\MAD\CaseThread\case_thread"
flutter pub get
cp .env.example .env        # fill SUPABASE_URL + SUPABASE_ANON_KEY (cloud project hxrztoakimebjcibvkaa)

flutter run -d chrome       # app (web)
flutter test                # Dart tests
flutter analyze             # must be 0 issues
npx supabase test db        # pgTAP suite (needs Docker; CI runs it too)
npx supabase db push --include-all   # apply migrations to cloud
npx supabase functions deploy ai-agent --project-ref hxrztoakimebjcibvkaa
```

CI: `.github/workflows/ci.yml` — `flutter` job (format/analyze/test/build) + `rls-tests` job (db reset + pgTAP). Both must be green before merge. **Test at phase boundaries, not per sprint (user decision).**

---

## 6. Gotchas catalog (read before writing SQL tests)

All learned the hard way — details in memory.md §8:
1. Impersonated sessions can't insert fixtures → `select tests.unimpersonate();` first.
2. pgTAP `is()` over an empty set emits no line → plan/run mismatch → scalar-subquery form.
3. `now()` is transaction-stable → force time boundaries with intervals.
4. `throws_ok` matches the EXACT full error string (this pgTAP build).
5. Non-member `INSERT..SELECT` → 0 rows land (no exception) → assert count 0.
6. Set-returning functions need FROM, can't nest in scalar EXISTS → CTE form.
7. `add check` without dropping the old named constraint → both apply (0027/0034 lesson).
8. Views: `security_invoker` + `security_barrier`, NOT row-level security (42809).
9. 0003 `touch_updated_at` trigger overwrites manual `updated_at` writes.
10. Docker Desktop on this machine: start LEAN (`--exclude studio,imgproxy,inbucket,edge-runtime,logflare,analytics,vector`); the full 12-service start crashes the engine. DB port is 65432 (Hyper-V reserves 543xx).

**Riverpod 3.4.3 (UX Parity session):** `NotifierProvider` needs TWO type args (`NotifierProvider<MyNotifier, State>` — the single-arg form fails to compile); `FamilyNotifier<State, Arg>` with `arg` for family notifiers; test overrides use `overrideWith(() => TestNotifierSubclass)` (no `overrideWithValue` on notifier providers); `ref.listen` in `initState` of a `ConsumerState` is the pattern for one-shot cross-widget signals (alert card → analysis tab).

---

## 7. Unresolved / deferred

- **Final gate run on UX Parity work** — see Step 1; authored without a local Flutter SDK.
- **Voice notes + chat media (UX Parity 7.1/7.2)** — intentionally skipped; needs `record` plugin + mic permissions, a `chat_media` storage bucket + policies, playback UI, and a message-attachment schema. Scoped as a separate mini-sprint if the client wants them.
- **Mobile store submission + paid tier** — external/decision-blocked (unchanged).
- **GROK key** — `npx supabase secrets set AI_PROVIDER=grok GROK_API_KEY=…` still unset; function runs mock.
- **Vercel deploy** — configured in docs, not yet connected in this environment.
- **Seed demo SQL** — must be run per-environment (needs a real auth.users id); documented in README + HANDOFF.
