# CaseThread — Progress Handoff (for the next developer)

**Written:** 2026-09-19
**Purpose:** exact state of the project, what is done, what remains, and the immediate next steps. Another developer should be able to continue from this file alone.

---

## 1. Big picture — how much of the project is done

| Phase | Scope | State |
|---|---|---|
| Phase 0 | Planning docs | ✅ 100% |
| Phase 1 | Core platform (auth, rooms, codes, join, vault, timeline, discussion, tasks, gating) | ✅ 100% — merged to `main`, live-verified |
| Phase 2 | 5 case types, redaction, activity feed, export, entity map | ✅ 100% — merged to `main`, live-verified |
| Phase 3 | AI agent workflows (registry, Edge Function, human-in-the-loop review) | ✅ 100% — merged via PR #1 (4ed09b4); **live E2E verified** |
| Phase 4 | Marketplace, cross-case search, offline sync, version history | 🟡 ~80% — S1 (marketplace) merged to `main` (#2); S2–S4 code on `feature/phase-4-s2-s4` (CI green at 908893d), **not merged** |
| Phase 5 | Investigation intelligence (alibis, contradictions, gaps, dashboard, case status) | 🟡 ~90% — code on `feature/phase-5-investigation-intelligence`, CI issues being fixed |
| Phase 6 | Spec alignment to the v3 HTML console (`C:\Users\Aadi\Downloads\casethread-v3.html`) | 🟡 ~85% — v3 console shell + Overview/Audit/Summary/Connections built (see §4b); **analyzer/tests not re-run yet** |
| Phase 4 remainder (S5+) | App-store release, billing groundwork, template marketplace UI polish | ⬜ 0% |

**Overall: ≈80% of the planned roadmap is built.** The backend (34 migrations, 26 pgTAP test files, 8 Edge Functions, RPCs, RLS on every table) is substantially complete. The Flutter client implements most of it. The remaining work is (a) one red CI branch, (b) merging three CI-green branches, (c) the console UI rebuild to match the v3 mockup, (d) Phase 4's P2 tail.

---

## 2. Repo layout — branches and what's in them

```
main                        = Phase 1+2+3 merged (PRs #1, #2). CI green.
feature/phase-4-s2-s4       = cross-case search, offline sync, version history. CI GREEN (908893d) → MERGE ME
feature/phase-5-investigation-intelligence = alibis/contradictions/gaps/dashboard. CI RED (minor test-context fixes)
feature/phase-6-spec-alignment = v3-console alignment + Phase-6 tests. CI RED (current work, checkout here)
```

**DB migrations: 0001–0034** (all applied to cloud `hxrztoakimebjcibvkaa`).
**pgTAP tests: 26 files, 220 tests** (98 were green at the Phase-3 boundary; the Phase-4/5/6 session's new test files introduced fixture-context bugs now mostly fixed).
**Dart: 64+ tests, analyze 0.**

---

## 3. IMMEDIATE NEXT STEPS (in order)

### Step 1 — Get `feature/phase-6-spec-alignment` CI green (the branch is checked out)

**Already fixed and pushed** (commit 0093efa): `entity_type` CHECK constraint conflict (0027/0034), missing room creation in 4 test files, impersonation-context bugs, LWW test semantics, jsonb access in case_breakdown, non-member INSERT..SELECT row-count semantics, version-history outsider not-found.

**Known remaining failures** (from run for f7c1f28 — the latest commit adds fixes for these; verify with a fresh CI run):
1. `case_breakdown_test.sql:103` — `column bd.evidence_by_type does not exist`: one more `bd.` column-style ref wasn't converted (fixed at 0093efa — verify).
2. `statistics_view_test` — "sam sees only Room X" fails: the evidence fixture ran impersonated; commit 0093efa added the unimpersonate guard (verify).
3. `version_history_test.sql:112` — `Task not found.`: the outsider `list_versions` assertion needs the typed-error form (fixed at 0093efa — verify).
4. `offline_sync_test.sql:202` — `syntax error at "1"`: **NOT yet fixed** — the second `clear_conflict` assertion has a missing closing paren at line 184–187:
   ```sql
   select is(
     (select count(*) from public.clear_conflict('task',
       (select member_id from tests.fixtures where key = 'off-task'))),
     1::bigint, ...
   ```
   Both instances must end `)))` then `, 1::bigint,` — check lines ~174–187.

**Fix pattern for any remaining test failures** (the recurring bug class — fixture/setup SQL running while a session is impersonated):
- `select tests.unimpersonate();` before any direct `INSERT` into app tables, member fixtures, or evidence fixtures (0005/0009 RLS denies impersonated sessions).
- Non-member `INSERT..SELECT` tests: RLS hides the room from the source SELECT → 0 rows land → assert `count(*) = 0` ("nothing lands"), NOT `throws_ok`.
- pgTAP `is()` over an empty result set silently emits NO test line → plan/run mismatch. Use scalar-subquery `is((select ...), expected, ...)`.
- `now()` is transaction-stable: everything in one test txn shares one timestamp. Force LWW/watermark boundaries with `now() - interval '1 hour'` etc.
- Capture timeline fixtures with `and event_type = 'manual'` (0010 mirrors system events into the same txn; `occurred_at` ties make unfiltered captures non-deterministic).
- jsonb: `v_case_breakdown(...)` returns a jsonb scalar — access keys with `(bd -> 'key')`, not `bd.key`.

Then: `git push` → CI → green → `git checkout main && git merge --squash feature/phase-6-spec-alignment && git commit && git push`.

### Step 2 — Merge the pending CI-green branches
- `feature/phase-4-s2-s4` (908893d) — CI green, just squash-merge.
- `feature/phase-5-investigation-intelligence` — after rebase onto updated main + CI green.

### Step 3 — Cloud resync
The cloud DB `hxrztoakimebjcibvkaa` is at 0017+partial-hotfixes; `npx supabase db push --include-all` applies the rest (0018–0034). Then re-apply the seed: `npx supabase db query --linked --file supabase/seed.sql` (idempotent-ish; use `on conflict do nothing` discipline).

### Step 4 — Deploy Edge Functions
`npx supabase functions deploy ai-agent --project-ref hxrztoakimebjcibvkaa` (worked before, mock provider runs without keys). Set `AI_PROVIDER=grok` + `GROK_API_KEY=<key>` via `npx supabase secrets set` for the real provider.

---

## 4. The v3 console rebuild (the big remaining workstream)

`C:\Users\Aadi\Downloads\casethread-v3.html` (2339 lines) is the approved design — a complete "Investigation Console" UI. v3 vs v2 diff (v3 adds §13 modules): members/roles rows, AI review cards (amber), audit log, closed summary, Fact/Claim/Finding/Unknown legend, mobile bottom nav, invite/code display, room search, export checklist, tab divider, case-type picker.

**"Same to same" means rebuilding the Flutter shell to this design.** Mapping to our existing backend (everything the mockup shows has a real endpoint already):

| v3 element | Backend to wire |
|---|---|
| Cases sidebar w/ search + status chips | `roomsProvider` (exists) + client-side filter |
| Overview hero + 6 stat cards + evidence-by-type chart + coverage meter | `v_case_breakdown` RPC (0033) + `v_case_statistics` (0026) |
| "Waiting on you" attention card | tasks (open) + pending ai_suggestions counts |
| Needs-attention rows (conflicts/gaps/alibis) | Phase-5 tables (0025/0029/0030) |
| Room activity feed | `v_activity_feed` (0014) + audit_log |
| Discussion w/ chat bubbles + attach menu | realtime discussion (Sprint 5) + evidence link |
| Evidence vault w/ search + type chips | evidence_repository (Sprint 4) + file_picker |
| Timeline w/ node styling + source filter chips | v_timeline stream (0013 redaction) + classification (0027) |
| Analysis subtabs (alibis/contradictions/gaps) | Phase-5 repos |
| Connections graph (animated orbs + edges) | `get_entity_map` RPC (0016) |
| Tasks w/ check styling | tasks (Sprint 5) |
| AI review cards (amber, accept/dismiss) | `suggestionsProvider` + `review_suggestion` RPC (0017) |
| Audit log rows | `audit_log` (member-scoped) |
| Members w/ role badges (owner/lead/analyst/assistant) | `roomMembersProvider` + role mapping |
| Closed summary | 0026 `transition_investigation_status` + summary view |
| New-case dialog (type-grid picker + code display) | `create_case_room` RPC — already built, restyle |
| Invite/code display + copy | access code display (Sprint 3) — restyle |
| Notifications sheet | `v_activity_feed` (0014) + `room_last_seen` upsert |
| Mobile bottom nav | Design.md §12 responsive shell |

**Suggested Flutter file layout** (feature-first, Rules.md §1):
- `lib/core/theme/app_theme.dart` — extend with the v3 palette (Geist font, `--brand-gradient` teal→blue→violet, status token pairs)
- `lib/shell/console_shell.dart` — topbar + rail + mobile bottom nav
- `lib/features/rooms/console/` — one pane file per v3 tab, a `stat_cards.dart` widget lib, `graph_view.dart` (CustomPainter for the orbs/edges), `bubbles.dart`
- Reuse every existing provider/repository — this is a **presentation-layer rebuild**, not a backend change.

### 4b. v3 console build — what has landed (most recent session)

All five workstream items below are implemented on `feature/phase-6-spec-alignment`. Everything reuses existing providers/RPCs — no backend changes were made.

| v3 element | Status | Where |
|---|---|---|
| Geist + GeistMono fonts, gradient palette (`brandGradient` teal→blue→violet), console surface/status tokens, ambient atmosphere (grid + aurora + glow orbs, reduced-motion aware) | ✅ | `pubspec.yaml`, `assets/fonts/Geist*`, `lib/core/theme/app_colors.dart` (§v3 tokens), `lib/shell/ambient_atmosphere.dart`, `app_text_theme.dart` |
| Topbar + rail + cases panel shell (console embeds RoomDetailScreen; standalone route intact) | ✅ | `lib/features/rooms/rooms_screen.dart`, `room_detail_screen.dart` (11 tabs, embedded `embedded:true` mode with v3 room-head) |
| Overview hero + 6 stat tiles + evidence-by-type chart + events chart + coverage meter | ✅ | `lib/features/dashboard/dashboard_screen.dart` — stats from `v_case_statistics` (0026), charts from `v_case_breakdown` (0033); coverage meter is **evidence classified** (Fact/Claim/Finding share from the vault) because the backend has no "evidence↔event link" metric |
| "Waiting on you" attention card with real counts | ✅ | `attentionCountsProvider` + `roomTasksStreamProvider` in `rooms_providers.dart` (open tasks via realtime stream, open contradictions 0025, unverified alibis 0025); wired in `rooms_screen.dart` `_attentionBanner()` |
| Animated connections graph (orbs + flowing dashed edges + legend) | ✅ | `lib/features/connections/connections_screen.dart` — `_GraphView` is now animated (2600 ms flow controller), pulse rings, dashed ring for unknown node types, legend pill; reduced-motion renders static; hit-testing/circular layout preserved |
| Audit Log pane (v3 §13) | ✅ | `lib/features/rooms/audit_pane.dart` (new file — was imported but missing, which broke the build) |
| Summary pane (closed-case snapshot) | ✅ | `lib/features/rooms/summary_pane.dart` (new file) |
| Join / Search / Templates entry points restored in console | ✅ | Cases panel header icon buttons (keys `rooms-join`, `rooms-search`, `rooms-templates`) |

**Not re-verified yet (no terminal in that session):** `flutter analyze` and `flutter test` must be run before merge. `test/app_test.dart` was updated for the console UI (expects `Cases`, `Open a case to start work`, `rooms-join`) and its signed-in test now uses manual `pump()` calls — the ambient atmosphere animates forever by design, so `pumpAndSettle` on the console route will time out. Keep that in mind for any future widget test that renders `RoomsScreen`.

**Still open on the v3 rebuild:** mobile bottom nav, notifications sheet, invite/code-display restyle, discussion/evidence/timeline pane restyles to v3 bubble/row styling, quick-actions grid inside Overview.

---

## 5. Environment / how to run

```bash
# Toolchain
#   Flutter at D:\5th Semester\MAD\flutter (add to PATH)
#   Node 24 + npx (supabase CLI 2.117.0 pinned in package.json)
#   Docker Desktop (ONLY needed for the local pgTAP loop; flaky on this machine)

cd "D:\5th Semester\MAD\CaseThread\case_thread"
flutter pub get
cp .env.example .env        # fill SUPABASE_URL + SUPABASE_ANON_KEY (cloud project hxrztoakimebjcibvkaa)

flutter run -d chrome       # app (web)
flutter test                # 64+ Dart tests
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

---

## 7. Unresolved / deferred

- **Medical domain fields** — deferred behind the SME gate (PRD §10); generic roles seeded only.
- **Anon key rotation** — was briefly in a public commit (audited: anon key only); routine hygiene.
- **Windows Developer Mode** — off; needed before Android device builds (both-platform verification is therefore partial: Chrome verified, Android pending).
- **Vercel deploy** — configured in docs, not yet connected in this environment.
- **AI provider** — GROK chosen (user decision); live real-provider run still needs `GROK_API_KEY` secret + one E2E.
