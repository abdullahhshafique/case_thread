# Offline Sync — Conflict Resolution Policy (Design Gate)

**Status:** Approved design gate — required BEFORE offline-mode build starts (Phases.md §5 risk note, ExecutionPlan.md §6).
**Date:** 2026-09-14
**Scope:** Phase 4 "Offline-first mobile sync" workstream. This document is the gate; building before this is approved violated the phase plan.

---

## 1. Problem

Mobile clients (investigator in the field, student on flaky campus wifi) will go offline mid-session. CaseThread's data model is **multi-writer** (any permitted member can write timeline events, discussion messages, tasks, evidence metadata) and **append-mostly** (audit_log is append-only; timeline_events allows only manual-event edits). A sync engine must decide what happens when the same room diverged on two devices.

**Non-negotiable constraints from prior phases:**
- RLS is the security boundary — a sync engine must never replay a write the original author could no longer perform (e.g., membership revoked while offline).
- `audit_log` is append-only and immutable (0003). No sync design may update or reorder it.
- AI suggestions are service-role-written; offline queue never touches them.
- Redaction is server-enforced (0013 views). Offline caches must never store more than the client was entitled to see at fetch time.

## 2. Policy by data class (the core decision)

| Data class | Conflict policy | Rationale |
|---|---|---|
| **Append-only streams** — discussion_messages, audit-derived timeline events, evidence_items registrations | **No conflict possible** — server is the only writer; offline clients queue THEIR inserts and replay on reconnect | Inserts get server ids/timestamps on arrival; ordering by server `created_at` |
| **Manual timeline events** — editable by permitted roles | **Last-write-wins + visible conflict flag** | Low real-world contention (one author typically edits own events); silent data loss unacceptable → flag, don't hide |
| **Tasks** — status/title/due date/assignee | **Field-level last-write-wins**; status transitions validated server-side at replay | Two members flipping the same task status is the classic case: later server arrival wins; the earlier value's author sees the flip |
| **Room membership / roles / access codes** | **Server-authoritative, NO offline queue** | Security-sensitive; offline approval/rotation requests are dangerous. Offline members only *read* these |
| **Evidence files** | **Upload-only queue**; a queued upload whose author lost `upload_evidence` while offline is rejected at replay with a typed error surfaced in UI | Storage writes already RPC-gated (0009); same gate applies at replay |
| **Reads/caches** | **Stale-until-confirmed**; UI shows an "offline — as of HH:MM" watermark on every pane | Redaction risk: cached rows carry their fetch-time visibility; a member revoked mid-offline sees cache until reconnect, then rows drop on next fetch (RLS re-evaluated) |

**Summary in one line:** *writes queue locally with full author context; on reconnect they replay through the same RPC/RLS paths as live writes; divergent single-field writes resolve last-write-wins and are visibly flagged; security-sensitive writes never queue.*

## 3. Replay protocol (reconnect)

1. Device sends the queued mutation bundle with each mutation's ORIGINAL `queue_id`, `table`, `rpc`, `params`, `queued_at`, and the author's JWT at replay time.
2. Server executes each mutation **in queue order** through the existing sanctioned paths (RPCs / RLS-gated inserts) — no new bypass endpoints.
3. Per-mutation outcomes:
   - **OK** → applied; device drops it from queue.
   - **RLS deny / permission revoked** → typed `PermissionDenied` error; device drops it and records it in the device's local "rejected while offline" list (surfaced in UI with the role-specific message per PRD §6.7).
   - **Conflict (LWW applies)** → server state wins; device drops its copy; the affected row gets `conflict_flag = true` + `conflict_resolved_at` metadata (see §4).
4. After the queue drains, the device re-pulls watermarked deltas (reuses the 0014 activity-feed watermark machinery — same "what changed since X" primitive).

## 4. Conflict visibility (no silent losers)

- `timeline_events.payload` gains an optional `conflict: {lost_value, won_at, actor}` block on LWW losers — manual-event edits only.
- `tasks` rows gain optional `conflict_flag boolean` + `conflict_note text`; UI renders an amber "edited while you were offline" chip (reuse the pending-AI amber per Design.md §1 semantics: *amber = needs your attention*).
- Conflict markers are **mutable advisory metadata only** — any permitted member may clear them (a `clear_conflict` RPC); clearing is audited.

## 5. What is explicitly OUT of scope for v1 offline

- **Merge UIs** (no side-by-side pick-the-winner screens — flag + manual re-edit instead).
- **Offline room creation / joining** (codes are server-generated and hashed; queueing creates security complexity for little value).
- **Conflict-free replicated data types (CRDTs)** — overkill for the write patterns observed in pilot; revisit only if conflict-flag volume in pilot data exceeds ~5% of offline writes.
- **Offline AI runs** (agents need server-side context gathering; impossible offline).

## 6. Test gates (Rules.md §7 — contract tests required)

1. pgTAP: replay path — queued insert by a since-revoked member → denied, not partially applied.
2. pgTAP: LWW — two divergent task updates; later `arrived_at` wins; loser row carries `conflict_flag`.
3. pgTAP: `audit_log` ordering untouched by replay (append-only preserved).
4. Dart: queue serialization round-trip; typed `PermissionDenied` handling surfaces the role-specific message.
5. Field test (Phase-4 DoD): connectivity loss mid-session → queued writes → resync → conflict flag visible on the loser — the exact Phases.md §5 scenario.

## 7. Open items deferred to implementation PRs

- Queue storage engine on-device (Hive/Isar/SQLite) — implementation detail, not policy.
- Max queue size / oldest-drop policy (proposal: cap 500 mutations, drop-oldest with a persistent warning).
- Multi-device-same-user queue interleaving (rare; server replay order by `queued_at` is sufficient).
