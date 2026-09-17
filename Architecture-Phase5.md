# CaseThread — Architecture Addendum: Phase 5 "Investigation Intelligence Layer"

**Status:** Draft v0.1 — new, unreviewed
**Last updated:** 2026-09-17
**Related docs:** [Architecture.md](./Architecture.md) · [PRD-Phase5.md](./PRD-Phase5.md) · [Phases-Phase5.md](./Phases-Phase5.md) · [Rules.md](./Rules.md)

> This document specifies **only** the additions needed to support PRD-Phase5.md. It assumes the Phase 1–4 architecture (Architecture.md) is unchanged and stable, and follows the same design principles already in place: RLS-first security, human-in-the-loop AI, append-only audit, additive-only schema changes (Architecture.md §2, §14).

---

## 1. Design Principles Carried Forward (no change)

- **RLS-first** — every new table gets its own RLS policies keyed off `room_members.role`, same as every existing table.
- **Human-in-the-loop AI** — the new AI Case Completeness Review agent follows the exact same contract as the five existing agents: it writes only to `ai_suggestions`, never directly to a case-record table.
- **Additive-only migrations** — no existing column is renamed or repurposed. `case_rooms.status` (active/archived) is untouched; a new column carries the investigation lifecycle (§2.5).
- **Config over code** — where an investigation-gap/alibi "type" needs to be extensible per case type, prefer a lookup table or config row over a hardcoded enum, consistent with the case-types-as-config pattern that held through Phase 2 and Phase 4 (memory.md Phase 2/Phase 4 retros).

---

## 2. Data Model Additions (Logical)

All new tables are room-scoped (`room_id` FK to `case_rooms`) and follow the existing naming convention (`snake_case`, Rules.md §1).

### 2.1 `alibis`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `room_id` | uuid FK | |
| `entity_id` | uuid FK → `entities` | the person the alibi belongs to |
| `claimed_window_start` / `claimed_window_end` | timestamptz | |
| `claim_text` | text | free-text description of the claim |
| `source` | text | e.g. which statement/evidence the claim came from |
| `status` | enum | `verified` / `partially_verified` / `conflict` / `insufficient_data` |
| `status_reason` | text | required whenever status ≠ null — the "why," never a bare status (PRD-Phase5.md §4.2) |
| `created_by` / `verified_by` | uuid FK → `users` | |
| `created_at` / `verified_at` | timestamptz | |

### 2.2 `alibi_evidence_links`

Join table: `alibi_id`, `evidence_item_id` (or `timeline_event_id`), `relation` (`supports` / `conflicts`). Lets the UI show exactly which evidence backs a given status, per PRD-Phase5.md §4.2's "never a bare status" requirement.

### 2.3 `contradictions`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `room_id` | uuid FK | |
| `source_type` | enum | `manual` / `ai_suggestion` |
| `ai_suggestion_id` | uuid FK, nullable | set only when `source_type = ai_suggestion`, links back to the originating `ai_suggestions` row for traceability |
| `conflicting_detail` | text | the specific thing that conflicts |
| `relevant_time` / `relevant_location` | nullable | |
| `flagged_reason` | text | why this was flagged |
| `status` | enum | `open` / `resolved` / `dismissed` |
| `resolution_note` | text, nullable | |
| `linked_task_id` | uuid FK → `tasks`, nullable | set if "Create Task" was used |
| `flagged_by` / `resolved_by` | uuid FK → `users` | |
| `created_at` / `resolved_at` | timestamptz | |

### 2.4 `contradiction_sources`

Join table: `contradiction_id`, and a polymorphic reference to the conflicting items (`evidence_item_id` / `timeline_event_id` / `alibi_id`, each nullable — exactly one populated per row). A contradiction typically has 2+ rows here (the two-or-more conflicting sources).

### 2.5 `investigation_gaps`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `room_id` | uuid FK | |
| `gap_type` | text | free-form or a config-table lookup (e.g. `unknown_person`, `unverified_location`, `missing_evidence`, `unlinked_event`) — keep open-ended rather than a rigid enum, per §1 config-over-code |
| `description` | text | |
| `source_type` | enum | `manual` / `ai_suggestion` |
| `ai_suggestion_id` | uuid FK, nullable | same traceability pattern as `contradictions.ai_suggestion_id` |
| `status` | enum | `open` / `in_progress` / `resolved` |
| `linked_task_id` | uuid FK → `tasks`, nullable | |
| `created_by` | uuid FK → `users` | |
| `created_at` / `resolved_at` | timestamptz | |

### 2.6 `case_rooms` — additive column

Add `investigation_status` enum (`open` / `under_investigation` / `review` / `closed`), default `open`, **alongside** the existing `status` (active/archived) column — the two are orthogonal axes (room lifecycle vs. investigation lifecycle) and neither replaces the other (per PRD-Phase5.md §4.6 and Architecture.md §14's additive-only rule).

### 2.7 `case_closed_summaries`

Generated (not hand-written) on transition to `investigation_status = closed`. Store as a JSONB snapshot rather than a live-computed view, so a closed case's summary is stable even if underlying data changes later (e.g., a task is edited post-closure).

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `room_id` | uuid FK, unique | one summary per room, regenerated on re-close if reopened+reclosed |
| `summary_json` | jsonb | overview, people, evidence, major events, timeline, confirmed findings, contradictions, unresolved gaps, relationships, status — per PRD-Phase5.md §4.6 |
| `generated_at` | timestamptz | |
| `generated_by` | uuid FK → `users` | |

### 2.8 `entities` — extend `type` enum

Existing `entities.type` supports `person/org/location/evidence` (Architecture.md §5). Add `vehicle` to satisfy PDF §10/§13's vehicle-as-entity examples (CCTV → Event → Vehicle → Location → Person). This is a single enum-value addition, not a schema restructure.

### 2.9 `evidence_items` / `timeline_events` — extend with classification

Add a `classification` enum column (`fact` / `claim` / `finding` / `unknown`) to both tables, nullable (existing rows unclassified by default, backfillable later) — implements the Fact/Claim/Finding/Unknown model (PRD-Phase5.md §4.1) without breaking either table's existing contract.

### 2.10 Case statistics

Prefer a **Postgres view** (`v_case_statistics`, `security_invoker` — same redaction-safe pattern already used for other views per memory.md Phase 2 retro) over a materialized view for MVP, since case rooms are small enough that a live aggregate query is cheap; revisit materialization only if dashboard load becomes a measured problem. The view aggregates counts (evidence, people, locations, events, contradictions, gaps, unverified alibis, ai_suggestions) scoped by `room_id`, respecting the same RLS boundary as the underlying tables (a `security_invoker` view inherits the caller's row visibility, so it can't be used to leak redacted counts).

---

## 3. New Agent Type — AI Case Completeness Review

Added to the existing agent-config table (the same versioned-config-row pattern used for the five current agents, per README.md/Phases.md §4) as a sixth entry: `case_completeness_review`. Unlike the domain-scoped agents, this one is cross-domain — its config has no `case_type` restriction. Same contract as every other agent (Rules.md §11):

- Writes only to `ai_suggestions` (never to `alibis`, `contradictions`, `investigation_gaps`, or `timeline_events` directly).
- A Lead-tier member accepts/edits/dismisses each suggestion individually; acceptance is what actually creates the `investigation_gaps` or `alibis` row (or updates a `contradictions` row), in the same atomic decision+audit transaction pattern already used for other agent output (Architecture.md §7).

---

## 4. API Additions (logical, PostgREST + Edge Functions per existing pattern)

| Endpoint (logical) | Method | Auth | Purpose |
|---|---|---|---|
| `/rooms/:id/alibis` | POST/GET | JWT + role permission | Create/list alibis |
| `/rooms/:id/alibis/:alibiId/verify` (Edge Fn or RPC) | POST | JWT + role permission | Run/record a verification pass, write status + reason |
| `/rooms/:id/contradictions` | POST/GET | JWT + role permission | Create/list contradictions (manual path) |
| `/rooms/:id/contradictions/:id/decision` | POST | JWT + Lead-tier role | Resolve/dismiss/create-task-from |
| `/rooms/:id/gaps` | POST/GET | JWT + role permission | Create/list investigation gaps |
| `/rooms/:id/gaps/:id/create-task` | POST | JWT + role permission | One-click gap → task (PRD-Phase5.md §4.4) |
| `/rooms/:id/agents/case_completeness_review/run` (Edge Fn) | POST | JWT + role permission | Trigger the new agent — same shape as existing agent-run endpoint |
| `/rooms/:id/status` | POST | JWT + Owner/Lead role | Transition `investigation_status`; triggers closed-summary generation on `→ closed` |
| `/rooms/:id/closed-summary` | GET | JWT + role permission | Fetch the generated `case_closed_summaries` row |
| `/rooms/:id/statistics` | GET | JWT + role permission | Fetch `v_case_statistics` for the dashboard |

Export service (`/rooms/:id/export`, existing) extends its compiled content to include contradictions, alibis, and gaps alongside the current summary/timeline/findings (PRD-Phase5.md §4.6/§2 row for PDF §23).

---

## 5. Data Flow — New Critical Paths

**Manual contradiction flag:**
`Member selects 2+ sources → submits conflicting_detail + reason → RLS-protected insert into contradictions + contradiction_sources → audit_log entry`

**AI-sourced contradiction/gap (human-in-the-loop):**
`Member triggers Case Completeness Review agent → Edge Fn gathers RLS-scoped room data → AI Adapter Layer call (existing, Architecture.md §7) → response written to ai_suggestions (status=pending) → Realtime pushes to Analysis tab as a suggestion → Lead accepts/edits/dismisses → on accept: contradictions or investigation_gaps row created + audit_log entry, in one transaction (mirrors the existing AI-suggestion-acceptance pattern exactly)`

**Alibi verification:**
`Member records claim → member (or agent-assisted) compares against evidence_items/timeline_events → status + status_reason + alibi_evidence_links written → audit_log entry`

**Gap → task:**
`Member clicks "Create Task" on a gap → pre-filled task created (linked_evidence/gap reference) → investigation_gaps.linked_task_id set → investigation_gaps.status → in_progress → audit_log entry`

**Case closure:**
`Lead transitions investigation_status → closed → Edge Fn compiles summary_json from current case state → case_closed_summaries row written (insert, not update, if a prior closure exists — keep history) → audit_log entry`

---

## 6. Security & Testing

- Every new table gets explicit allow/deny RLS contract tests before merge, per Rules.md §7 — no exception for these tables.
- `v_case_statistics` must be verified in a pgTAP test to confirm it does **not** leak counts across redacted fields (same redaction-boundary test pattern used for search in P4-S2, per memory.md).
- `alibi_evidence_links` and `contradiction_sources` inherit visibility from their parent evidence/timeline rows — a role that can't see a given evidence item must not be able to see it referenced in an alibi/contradiction link either. This needs its own explicit deny-case test, since it's a new kind of cross-table leak risk not covered by existing suites.
- Migration numbering continues sequentially from the current highest (`0024`, per memory.md §11) — do not renumber or reuse.

---

## 7. Optional: Rive for Dashboard/Analysis Motion

Design.md §7 already specifies durations/easing but not tooling. If the team wants more polished motion for the new Dashboard (stat tiles, graph transitions) or the Analysis tab (a pulsing "processing" state while the Case Completeness Review agent runs, an animated state change when a gap moves to "resolved"), Rive is a reasonable option for Flutter — it renders as a lightweight, code-driven vector animation rather than a baked video/GIF, which fits Design.md's flat/minimal illustration style (§8) and keeps bundle size low (Rules.md §9). This is optional polish, not a Phase 5 requirement — flagging it because it was raised, not because it blocks anything above.
