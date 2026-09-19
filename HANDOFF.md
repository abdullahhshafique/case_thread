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
| Phase 6 | Spec alignment to the v3 HTML console (`C:\Users\Aadi\Downloads\casethread-v3.html`) | 🟢 ~90% — v3 console built + local gates green (analyze 0, 116/116 Dart); pushed 8d2901e; **CI run pending**; remaining = v3 UI polish (see §4b) |
| Phase 4 remainder (S5+) | App-store release, billing groundwork, template marketplace UI polish | ⬜ 0% |

**Overall: ≈85% of the planned roadmap is built.** The backend (34 migrations, 26 pgTAP test files, RPCs, RLS on every table) is substantially complete. The Flutter client implements all of it, plus the v3 Investigation Console shell. The remaining work is (a) the CI run validating the pushed phase-6 branch, (b) merging the pending branches to main, (c) v3 UI polish panes (§4b), (d) Phase 4's P2 tail.

---

## 2. Repo layout — branches and what's in them

```
main                        = Phase 1+2+3 merged (PRs #1, #2). CI green.
feature/phase-4-s2-s4       = cross-case search, offline sync, version history. CI GREEN (908893d) → MERGE ME
feature/phase-5-investigation-intelligence = alibis/contradictions/gaps/dashboard. CI RED (minor test-context fixes)
feature/phase-6-spec-alignment = Phase-6 spec alignment + v3 console rebuild. PUSHED 8d2901e (2026-09-19, history scrubbed of the p6j.txt secret); CI run pending (checkout here)
```

**DB migrations: 0001–0034** (all applied to cloud `hxrztoakimebjcibvkaa`).
**pgTAP tests: 26 files, 220 tests** (98 were green at the Phase-3 boundary; the Phase-4/5/6 session's new test files introduced fixture-context bugs now mostly fixed).
**Dart: 116 tests, analyze 0.**

---

## 3. IMMEDIATE NEXT STEPS (in order)

### Step 1 — Get `feature/phase-6-spec-alignment` CI green (the branch is checked out)

**Already fixed and pushed** (commit 0093efa): `entity_type` CHECK constraint conflict (0027/0034), missing room creation in 4 test files, impersonation-context bugs, LWW test semantics, jsonb access in case_breakdown, non-member INSERT..SELECT row-count semantics, version-history outsider not-found.

**Resolution state (2026-09-19):** all four previously-flagged failures are fixed on the branch. Items 1–3 were fixed at 0093efa; item 4 (offline_sync paren) was verified fixed in the file on 2026-09-19 — both `clear_conflict` assertions correctly end `)))`. Important context: the remote sat at f7c1f28 until 2026-09-19 (the 0093efa push had actually been blocked by GitHub Push Protection — see §4b), so CI never validated these fixes until the 8d2901e push. If `rls-tests` still fails, apply the patterns below to the failing file.

**Fix pattern for any remaining test failures** (the recurring bug class — fixture/setup SQL running while a session is impersonated):
- `select tests.unimpersonate();` before any direct `INSERT` into app tables, member fixtures, or evidence fixtures (0005/0009 RLS denies impersonated sessions).
- Non-member `INSERT..SELECT` tests: RLS hides the room from the source SELECT → 0 rows land → assert `count(*) = 0` ("nothing lands"), NOT `throws_ok`.
- pgTAP `is()` over an empty result set silently emits NO test line → plan/run mismatch. Use scalar-subquery `is((select ...), expected, ...)`.
- `now()` is transaction-stable: everything in one test txn shares one timestamp. Force LWW/watermark boundaries with `now() - interval '1 hour'` etc.
- Capture timeline fixtures with `and event_type = 'manual'` (0010 mirrors system events into the same txn; `occurred_at` ties make unfiltered captures non-deterministic).
- jsonb: `v_case_breakdown(...)` returns a jsonb scalar — access keys with `(bd -> 'key')`, not `bd.key`.

**Now:** the branch is already pushed (8d2901e, history scrubbed). Watch the CI run for it → green → `git checkout main && git merge --squash feature/phase-6-spec-alignment && git commit && git push`. If `rls-tests` goes red, apply the §6 fix patterns to the failing file.

### Step 2 — Merge the pending CI-green branches
- `feature/phase-4-s2-s4` (908893d) — CI green, just squash-merge.
- `feature/phase-5-investigation-intelligence` — after rebase onto updated main + CI green.

### Step 3 — Cloud resync (migrations ✅; seed hardened, rerun pending)
`npx supabase db push --include-all` reported **"Remote database is up to date"** (2026-09-19) — the cloud migrations table already records 0001–0034 (this doc's old "0017+hotfixes" estimate was stale). The 2026-09-19 data check: 14 rooms, investigation tables live, `v_case_breakdown` deployed — but **Riverside Robbery was never seeded to cloud** (the seed had only ever run via local `db reset`; a cloud rerun died on the `elena@casethread.demo` email conflict because cloud's demo users were created through the app with different UUIDs than the seed's fixed ones). Fix: `seed.sql` now resolves every demo-user reference through `public.demo_user_id(email, fixed_id)` and uses a targetless `on conflict do nothing` on the `auth.users` insert — rerun-safe on both fresh resets and cloud. **Action: `npx supabase db query --linked --file supabase/seed.sql`, then re-run the data check (`riverside_seeded` should be 1).**

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

**Verified 2026-09-19:** `flutter analyze` — 0 issues; `flutter test` — **116/116** (app_theme_test expectations updated to Geist/GeistMono per the v3 font switch). Pushed as **8d2901e** — but only after GitHub Push Protection blocked the first push: commit 0093efa had included `p6j.txt` (a pasted CI log containing a Supabase secret key at line 594). History was rewritten with `git filter-branch` (file removed from all commits), the branch force-pushed, and the local backup ref + reflogs pruned. **The flagged key must still be rotated** (Supabase Dashboard → Settings → API) — treat it as burned. `test/app_test.dart`'s signed-in test uses manual `pump()` calls on the console route — the ambient atmosphere animates forever by design, so `pumpAndSettle` on `RoomsScreen` will time out. Keep that in mind for future widget tests.

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
- **Supabase secret key exposure (2026-09-19)** — a service-tier key printed in a pasted CI log (`p6j.txt:594`) was committed in 0093efa. Push protection blocked it from ever reaching GitHub; history was scrubbed (filter-branch + force-push 8d2901e; local backup ref + reflogs expired). The key itself must still be **ROTATED** (Dashboard → Settings → API) — treated as burned.
- **Windows Developer Mode** — off; needed before Android device builds (both-platform verification is therefore partial: Chrome verified, Android pending).
- **Vercel deploy** — configured in docs, not yet connected in this environment.
- **AI provider** — GROK chosen (user decision); live real-provider run still needs `GROK_API_KEY` secret + one E2E.
