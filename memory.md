# CaseThread — Project Memory

**Last updated:** 2026-09-24 (UX Parity PRD phases 1–7 implemented; working tree ahead of `main` — gates + DB resync + CI pending)
**Update this file at the end of every work session — it's the fastest way for anyone (including a resuming AI assistant) to get back up to speed.**

---

## 1. Current Project State Summary

**PHASES 0–6 COMPLETE (merged to `main`, 43048cb, tagged `v0.1.0`) · UX PARITY PRD PHASES 1–7 + OBSIDIAN-STYLE CONNECTIONS GRAPH STEPS 1–3 IMPLEMENTED (2026-09-24, working tree — commit/push pending).** Graph upgrade: `force_layout.dart` (hand-rolled d3-style physics, alpha-cooled settle, deterministic), `_GraphView` camera (focal-anchored zoom 0.4–3× + pan via onScale*), node drag with re-heat, hover 1-hop highlight, entity/relationship type filter chips, local-graph focus mode (depth 1–3), type-ahead search-jump. Reduced-motion renders the settled layout. 10 physics unit tests in `force_layout_test.dart`. Step 4 DONE: migration `0044_entity_seed.sql` (`entity_seed` jsonb on case_type_templates + `materialize_entity_seed` security-definer RPC — placeholder substitution, key→UUID resolution, idempotent per (room,name), one audit entry per import), pgTAP `entity_seed_test.sql` (7 assertions), client `SeedTemplate` model + `listSeedTemplates`/`importEntitySeed` repo methods + `seedTemplatesProvider`, and `entity_import_sheet.dart` (pick template → fill placeholders → resolved preview → import) behind an edit_case-gated FAB on the Connections tab.

Phase 5 shipped the investigation-intelligence layer (0025–0031: alibis, contradictions, gaps, classification, statistics view, status/closed summary, AI consent, export extension). Phase 6 closed the instructor-doc gaps (dashboard header + graphs, classification UI, connections map tab, Riverside Robbery seed — 0033) and rebuilt the Flutter shell to the v3 HTML console (Geist + gradient + atmosphere, topbar/rail/cases shell, 11-tab embedded room detail, overview hero + stat tiles + charts + coverage meter, live-count "Waiting on you" card, animated connections graph, audit/summary panes) plus the polish tail (mobile bottom nav, notifications sheet, invite copy-link, chat bubbles, vault search + chips, timeline restyle).

**The 2026-09-24 session implemented the client-requested UX Parity PRD end-to-end:**
- **P1 Light theme + debug tools** — `AppColorsLight` (same token names, WCAG-AA values), `buildAppTheme(brightness:)`, persisted `ThemeModeNotifier`, theme toggle on the console, kDebugMode-only demo sign-in (`demo@casethread.test`) + `demoRoleOverrideProvider` permission pill.
- **P2 Overview enrichment** — `CaseBriefingCard`, `AlertCards` (contradictions/gaps/alibis; tap → `analysisTabRequestProvider` → AnalysisPane `animateTo`), `TaskDonut` (52px verified-alibi ring), `AttentionCounts` extended (alibiVerified/Partial/Conflict, openGaps, `totalAlibis`), dashboard order hero→briefing→stats→alerts→donut→charts. `CaseRoom.briefing` added to the model.
- **P3 Export overhaul** — `ExportSheet.show` bottom sheet (fetches the RLS-scoped report, then PDF via `CaseReportPdf.toPdfBytes` + `Printing.sharePdf`, or Markdown copy); `pdf 3.11.2` + `printing 5.13.4` added to pubspec.
- **P4 Evidence detail + verify-alibi** — `EvidenceDetailSheet` (metadata incl. sha256, permission-gated per-item AI run passing `evidence_item_id` to the Edge Function, verify-alibi tiles with required status reason + `evidenceItemIds` attachment); `runAgent` gained an optional `evidenceItemId`; vault tiles are tappable.
- **P5 Discussion enhancements** — `discussionFlagsProvider` (per-room star/pin in SharedPreferences), long-press action sheet, `_PinnedStrip`, "Extract to case timeline" (`addManualEvent`, classification `claim`, edit_case-gated). `main.dart` inits `ThemeModeNotifier` + `DiscussionFlagsNotifier`.
- **P6 Demo seeding + briefing editor** — `0042_room_briefing.sql` (briefing column), `supabase/seed_demo.sql` (idempotent full Riverside seed, code `DEMO1234`, config-CTE user id), `BriefingEditorSheet` + pencil affordance on the card, `RoomsRepository.updateBriefing`. **Bug fixed:** `getMyRooms` select omitted `investigation_status` + `briefing`.
- **P7 (partial by design)** — `0043_presence_watermarks.sql` (co-member watermark reads), `getRoomPresence`, `roomPresenceProvider`, `roleDotColor`/`lastSeenLabel`, role-colored avatar dots (dashboard stack + members tiles), "Active Xm ago" lines. **Voice notes + chat media intentionally skipped** (recording plugin, bucket + policies, playback UI, message-schema work — separate mini-sprint).

**Gate totals at last full verified pass (Phase 6, 43048cb):** flutter analyze 0, 118/118 Dart, 9/9 Deno, web release ✓, pgTAP 27 files/229 run/232 declared, CI 3/3. **The UX Parity session added 4 migrations' worth of… actually 2 migrations (0042, 0043) + 10 new/extended Dart test files and 2 new deps — gates NOT yet re-run (no Flutter SDK in the authoring environment).**

---

## 2. Recently Completed Tasks

| Date | Task | Note |
|---|---|---|
| 2026-09-24 | **UX PARITY PRD PHASES 1–7 IMPLEMENTED** | Light theme + debug tools, overview enrichment (briefing/alerts/donut), export bottom sheet (PDF/Markdown), evidence detail AI + verify-alibi, discussion star/pin/extract, demo seed + briefing editor, presence dots + last-seen. Migrations 0042–0043; deps pdf+printing; see HANDOFF §4 for the full file map |
| 2026-09-23 | **PHASE 6 FINAL** — spec alignment + v3 polish tail merged to `main` | 43048cb — squash merge; 118/118 Dart, 27 pgTAP files/229 run/232 declared, 9/9 Deno, web release ✓; CI 3/3; cloud synced (0040–0041), backup tag removed |
| 2026-09-20 | **v3 field-hardening wave** (post-demo feedback) | v3 theme canonicalized app-wide; console controls functional; discussion Discord-order + @mention chips; timeline view-streaming fix; creator-chosen access codes (0037); realtime publication gap (0035); evidence→profiles FK (0036); v_timeline conflict columns (0038); Record Alibi implemented |
| 2026-09-19 | Push-protection incident + history scrub | `p6j.txt` (pasted CI log with a Supabase secret) blocked the push; history scrubbed, force-pushed 8d2901e; key rotated 2026-09-23 |

*(Earlier session-by-session history: Sprints 0–7 and Phases 1–5 landed 2026-09-10 → 2026-09-17; see Phases.md §6 retrospective log for the full record.)*

---

## 3. Active Work Items

| File/Feature | Owner | Status |
|---|---|---|
| UX Parity + graph working tree (all `lib/features/...` changes above; `features/connections/force_layout.dart` new) | Flutter eng | Code-complete; **local gates + commit + push + CI pending** — first gate pass happened 2026-09-24 (fixed Riverpod family-notifier API, Uint8List, imports); graph steps 1–3 added after, gates re-run pending |
| Migrations 0042–0044 + seed_demo.sql | Backend eng | pgTAP suite green locally (28/237). **Cloud push of 0044 + per-env seed run remain** (`npx supabase db push --include-all`; run `seed_demo.sql` in the SQL editor with your demo user id) |
| `supabase/migrations/0042_room_briefing.sql`, `0043_presence_watermarks.sql` | Backend eng | Written; **cloud push pending** (`npx supabase db push --include-all`) |
| `supabase/seed_demo.sql` | Backend eng | Written (idempotent); **per-environment run pending** — replace `demo_user_id` in the config CTE first |
| Edge Function deploy | Eng lead | `npx supabase functions deploy ai-agent --project-ref hxrztoakimebjcibvkaa` — pending connectivity; mock mode until GROK key set |
| Mobile store submission (iOS/Android) | Eng lead + PM | Blocked on developer account provisioning |
| Paid-tier groundwork (billing/SSO/compliance export) | Product | Blocked on Go/No-Go product decision |
| Voice notes + chat media (UX Parity 7.1/7.2) | — | Intentionally skipped; scoped as separate mini-sprint |

---

## 4. Known Issues & Blockers

| Issue | Severity | Link |
|---|---|---|
| UX Parity work not yet machine-verified (analyze/test) — authored without a local Flutter SDK | **High** | HANDOFF §3 Step 1 |
| Migrations 0042–0043 not yet on cloud; seed_demo.sql not yet run | Medium | HANDOFF §3 Step 2 |
| Edge Function deploy blocked by connectivity; AI_PROVIDER/GROK_API_KEY unset (mock mode) | Info | memory.md §7 |
| Dev email confirmation currently on; consider disabling in dev project | Info | Dashboard → Authentication → Providers |
| p6j secret — **resolved**: rotated 2026-09-23 | Closed | — |

---

## 5. Next Immediate Steps

**In order (details in HANDOFF §3):**

1. `flutter pub get` → `dart format .` → `flutter analyze` (fix any nits) → `flutter test`.
2. `npx supabase db push --include-all` (0042 + 0043), then run `seed_demo.sql` in the SQL editor with your demo user id.
3. Commit (Conventional Commits), push, CI green, squash-merge to `main`.
4. Deploy the Edge Function; set `AI_PROVIDER=grok` + `GROK_API_KEY` when ready.
5. E2E walkthrough of all new UX Parity features (HANDOFF §3 Step 5).
6. Decide on voice notes / chat media mini-sprint (7.1/7.2) — or close the PRD as delivered.

**Testing cadence (user decision 2026-09-12):** full verification pass at each PHASE boundary; CI gates every push.

---

## 6. Pending Decisions

| Question | Context | Raised in |
|---|---|---|
| ~~Default LLM provider~~ **RESOLVED: GROK** (mock for keyless CI/dev) | Done | PRD.md §10 |
| Data retention policy for closed case rooms | Needed before storage/deletion logic is built | PRD.md §10 |
| API key rotation cadence | Needed before any real (non-dev) environment | Rules.md §10 |
| Voice notes / chat media (UX Parity 7.1/7.2) — build or formally close? | Scoped: `record` plugin + mic perms, `chat_media` bucket + policies, playback UI, message-attachment schema | UX Parity PRD Phase 7 |

### Phase 5 Open Conflicts — Recorded as Decisions (unchanged)

| Conflict | Decision |
|---|---|
| Mobile-first framing | No dedicated mobile navigation layer; mobile inherits the tab-based shell; RLS-first means no re-architecture for mobile |
| Template-marketplace stance | Investigation features are core, not template-driven |
| Cross-case pattern-matching depth | Per-room only; cross-case aggregation deferred behind a security-definer service design |

---

## 7. Environment State

- **Repo:** GitHub `abdullahhshafique/case_thread`, default branch `main` (tagged `v0.1.0`); UX Parity work in the local working tree (uncommitted at doc time). Conventional Commits + squash-merge per Rules.md §2.
- **Local setup:** Flutter 3.47.2 at `D:\5th Semester\MAD\flutter` (export PATH per shell); `flutter pub get` + `npm install` (supabase CLI via `npx supabase`); Deno via winget (not on PATH — use full path); config via `.env` (never commit) or `--dart-define` on web.
- **Cloud:** Supabase project ref `hxrztoakimebjcibvkaa` (live, linked); Edge Function secrets: only auto SUPABASE_* — AI_PROVIDER/GROK_API_KEY NOT set (mock mode).
- **Commands (gates):** `dart format .` → `flutter analyze` → `flutter test` → `npx supabase test db` (local Docker stack; exclude `studio,imgproxy,edge-runtime,logflare,vector,realtime,storage-api,postgres-meta`) → `deno test --no-check --allow-env supabase/functions/ai-agent/index.test.ts` → `flutter build web --release`.
- **App behavior when unconfigured:** boots to the setup screen with instructions — by design, not a crash.

---

## 8. Recent Learnings & Gotchas

**Added 2026-09-24 (UX Parity session):**
- **Riverpod 3.4.3 `NotifierProvider` requires both type args** — `NotifierProvider<int?>` alone fails with "Expected 2 type arguments"; use `NotifierProvider<MyNotifier, int?>(MyNotifier.new)`. Family notifiers: `NotifierProvider.family<MyFamilyNotifier, State, Arg>` with `FamilyNotifier<State, Arg>` (build takes `arg`, access via `this.arg`).
- **`const` on widgets with runtime constructor args doesn't compile** — `const AlertCards(roomId: roomId)` inside `build()` is "not a constant expression" when `roomId` is a parameter; drop the `const`.
- **`AppTextTheme` has no static style members** — styles live on the built `TextTheme`; use `Theme.of(context).textTheme.labelMedium` etc.
- **`ref.listen` inside `initState` of a `ConsumerState`** is the clean one-shot cross-widget signal pattern (overview alert card → analysis nested TabController `animateTo`).
- **`getMyRooms` explicit column lists are a footgun** — the select omitted `investigation_status` (and would have omitted `briefing`), silently defaulting the client model. Fixed 2026-09-24; keep column lists in sync with the model.
- **`Printing.sharePdf`** is the one-call PDF handoff (save/share/print; browser download on web) — no path_provider needed.
- **pgTAP/history gotchas (2026-09-10 → 09-19) remain in force** — see the entries below from prior sessions:
- Flutter SDK lives at `D:\5th Semester\MAD\flutter` (not on PATH); mirror `flutter-io.cn` configured.
- supabase_flutter 2.17.2: no `Supabase.instanceOrNull`; `publishableKey:` (not `anonKey:`); prefix supabase imports (`as supabase`) — gotrue names collide with domain types.
- Riverpod 3.x: `AsyncValue.valueOrNull` gone — use `.value`; sealed classes can't be extended outside their library.
- Flutter 3.47: `withOpacity` → `withValues(alpha:)`; `ElevatedButton.styleFrom` lost hover/disabled colors — build `ButtonStyle` with `WidgetStateProperty.resolveWith`.
- Postgres: UNIQUE constraints reject function expressions; cloud `db push` is transactional per file. RLS deny semantics: INSERT throws, UPDATE/DELETE silently no-op — assert state, never `throws_ok`, for UPDATE/DELETE denials.
- Realtime: tables must be in the `supabase_realtime` publication (same-migration DO-block + pgTAP assertion).
- Local Docker loop: `npx supabase start --exclude studio,imgproxy,edge-runtime,logflare,vector,realtime,storage-api,postgres-meta` → `db reset` → `test db`; DB port 65432 (Hyper-V reserves 543xx).
- pgTAP 3.36: `throws_ok` exact-match; empty-set `is()` emits no line (use scalar-subquery form); `_helpers.sql` must COMMIT; unimpersonate before fixture inserts.

---

## 9. Links to Relevant Conversations

- Original concept doc: `CaseThread-Refined-Concept.md` (source material for all six planning documents).
- UX Parity PRD: `CaseThread-UX-Parity-PRD.md` (client request, phases 1–7 — implemented 2026-09-24).
- Planning session 2026-09-10: Supabase over Firebase, 6–12mo timeline, Legal+Academic first, navy/slate/teal, provider-agnostic AI, public repo all-rights-reserved.

---

## 10. Testing Status

**2026-09-25 (all gates GREEN on the working tree):** pgTAP **28 files / 237 tests — all PASS** (incl. new `entity_seed_test.sql` for the 0044 import RPC); Dart analyze 0 + full test suite green (168+ tests; last fix = force-layout alpha decay clamp); migrations 0042–0044 verified by local `db reset`. Prior: **2026-09-24 (UX Parity, working tree — UNVERIFIED):** +10 new/extended Dart test files (theme_switch, alert_cards, case_briefing_card, dashboard_layout extended, export_report, evidence_detail_sheet, discussion_flags, presence, app_theme extended, auth extended). **Last machine-verified pass — 2026-09-23 (PHASE 6 FINAL, `main` 43048cb):** Dart **118/118**, analyze 0, pgTAP **27 files / 229 run — all PASS**, 9/9 Deno, web release ✓, CI 3/3. Prior gates: 166 pgTAP + 82 Dart (Phase 4 exit), 121 + 73 (Phase 3), 98 + 59 (Phase 2), 75 + 59 (Phase 1).

Live cloud E2E covers: create → join → approve → upload → audit (Phase 1); redaction/feed/export/entity-map (Phase 2); agent run → review → audit (Phase 3); draft → publish → room-from-template (P4-S1).

---

## 11. Deployment Log

| Timestamp | Environment | Version | Notes |
|---|---|---|---|
| 2026-09-23 | GitHub `main` | 43048cb | Phase 6 final: v3 console + polish tail; CI 3/3; cloud synced (0040–0041 + seed); p6j key rotated; tagged `v0.1.0` |
| 2026-09-17 | Phase 6 — Spec Alignment | Dashboard graphs, classification UI, Connections map, Riverside seed | COMPLETE |
| 2026-09-15 | GitHub (phase-4 tree) | S2–S4 | Search + offline + version history; reached main via phase-6 tree; CI 3/3 |
| 2026-09-14 | GitHub `main` | 4ed09b4 | **PHASE 3 COMPLETE** — PR #1; CI green on all 3 jobs; live AI E2E (3 agents, workflow chain) |
| 2026-09-13 | GitHub `main` | dd99aaf | **PHASE 2 COMPLETE** — 5 case types, redaction, feed, export, entity map |
| 2026-09-12 | GitHub `main` | 9e31315 | **PHASE 1 COMPLETE** — live demo-day rehearsal on cloud |
| 2026-09-11 | Supabase cloud `hxrztoakimebjcibvkaa` | 0001–0008+ | Core schema, RLS, room service live |
| **2026-09-24 (pending)** | working tree → `main` | UX Parity 1–7 | **NOT YET PUSHED** — gates + 0042–0043 push + CI + squash-merge outstanding |
