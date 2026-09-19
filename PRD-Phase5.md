# CaseThread — PRD Addendum: Phase 5 "Investigation Intelligence Layer"

**Status:** Draft v0.1 — new, unreviewed
**Owner:** Product Lead
**Last updated:** 2026-09-17
**Related docs:** [PRD.md](./PRD.md) · [Architecture.md](./Architecture.md) · [Architecture-Phase5.md](./Architecture-Phase5.md) · [Phases-Phase5.md](./Phases-Phase5.md) · [Design.md](./Design.md) · [memory.md](./memory.md)

> **Why this document exists:** `DOC-20260915-WA0014.pdf` ("CaseThread — Complete Project Understanding") describes a set of investigation-analysis features that are not present anywhere in PRD.md, Architecture.md, Phases.md, ExecutionPlan.md, Rules.md, or Design.md, even though those six docs are otherwise a complete and already-built (Phase 1–4) product spec. This addendum is scoped to **only** the material from the PDF that is genuinely missing — it does not restate anything already covered. Section numbers below (`PDF §n`) refer to the source PDF.

---

## 1. What's Missing — Summary

The current product (per README.md/memory.md) is a case-room platform with rooms, RBAC, an evidence vault, a timeline, an audit log, discussion, tasks, an entity/relationship map, five domain AI agents that post to `ai_suggestions`, redaction, export, cross-case search, offline sync, version history, and a template marketplace — all shipped through Phase 4.

The PDF describes CaseThread as an **investigation-support system** built around a specific analytical loop:

> `PDF §5` Scattered information → organized case → reconstructed timeline → connected entities → **alibi verification** → **contradiction detection** → **missing puzzle pieces / investigation gaps** → optional AI → human review → **clear case summary**.

None of the bolded stages above exist as first-class product concepts today. Contradiction detection exists only as one AI agent scoped to the Legal domain (`Contradiction Checker`, per README/Phases.md §4) — the PDF treats it as a core, always-available capability, not a domain add-on. The rest (alibi verification, investigation gaps, the dashboard's statistics, the Fact/Claim/Finding/Unknown model, case status/closed summary, quick actions) do not exist in any form.

---

## 2. Traceability — PDF Section → Gap → Where It's Specified

| PDF § | Concept | Current coverage | Disposition |
|---|---|---|---|
| §3 | "Alibi verification and contradiction detection" as core product identity | Not present | New — §4 below |
| §7 | Fact / Claim / Finding / Unknown classification model | Not present | New — §4 below |
| §8–9 | Case Dashboard with statistics + graphs (evidence, people, locations, events, contradictions, gaps, unverified alibis, AI findings) | Dashboard exists only as an unspecified nav item (Architecture.md §4 component table lists it with no content spec) | New — §5 below |
| §10 | Case Timeline sourced from CCTV/statements/phone-location records/vehicles | `timeline_events` table exists (Architecture.md §5) but no `vehicle` entity type or event-source typing | Extend — see Architecture-Phase5.md §2 |
| §11 | Case Timeline ≠ Audit Log | **Already solved** — `timeline_events` vs `audit_log` are distinct tables with a mirror trigger (memory.md, Sprint 5) | No action |
| §14 | Alibi Verification (Verified / Partially Verified / Conflict / Insufficient Data) | Not present | New — §4 below |
| §15 | Contradiction Detection as a first-class, cross-domain feature with review/resolve/dismiss/create-task | Exists only as one domain-scoped AI agent | New — §4 below |
| §16 | Investigation Gaps / Missing Puzzle Pieces ("Major feature") | Not present at all | New — §4 below |
| §17 | AI Case Completeness Review agent | Not among the five shipped agents (Contradiction Checker, Financial Anomaly Detector, Root-Cause Suggester, Literature Summarizer, Diagnostic Differential Assistant) | New — §4 below |
| §19 | Explicit, controlled consent before sending case data to an external AI service | Agent runs are user-triggered (Architecture.md §7), but there is no documented per-room/per-run consent or data-scoping control | New — §6 below |
| §21 | Investigation gaps convertible to tasks | Not present (gaps don't exist yet) | New — §4 below |
| §22 | Case Status (Open / Under Investigation / Review / Closed) + structured Closed Summary | `case_rooms.status` is `active/archived` only — a different axis (room lifecycle, not investigation lifecycle) | New — §4 below (additive field, not a replacement) |
| §23 | Report export content: gaps, contradictions, alibis, entities | Export service exists (Architecture.md §4/§7) but its content list predates these features | Extend — see Architecture-Phase5.md §4 |
| §24 | Cross-case **pattern matching** (locations, entities, timelines, methods, vehicles) as a Phase 5+/optional feature | P4-S2 shipped RLS-scoped **full-text** search (memory.md) — narrower than the pattern-matching the PDF describes | Flagged, not built here — §7 below |
| §25 | Template marketplace should be de-prioritized/removed | A full marketplace (draft → publish → materialize) shipped in P4-S1 | **Conflict** — §7 below |
| §27 | "CaseThread is primarily a mobile application" | Current docs frame it as Web + mobile with equal weight (ExecutionPlan.md §2.3 "both-platform rule") | **Conflict** — §7 below |
| §32–33 | "Analysis" nav grouping (Alibis/Contradictions/Gaps) + Quick Actions bar | Not present | New — §5 below |
| §35 | MUST/SHOULD/ONLY-IF-TIME scope classification | Not present in current Phases.md | Carried into Phases-Phase5.md |

---

## 3. Problem Statement (addendum)

CaseThread's shared core already answers *"what do we know, and who's allowed to see it?"* It does not yet answer the questions the PDF identifies as the actual differentiator (§34): *"what does the evidence we have actually show, what does it contradict, and what haven't we found yet?"* Right now that analytical work happens entirely in a human's head, or — for the Legal domain only — in a single opaque AI agent whose output is just another `ai_suggestion` indistinguishable in kind from an anomaly flag or a literature summary. There's no durable record of "this alibi was checked and conflicts," no explicit "this case has 3 known gaps," and no case-wide view of any of it.

---

## 4. New Concepts & Functional Requirements

### 4.1 Fact / Claim / Finding / Unknown model (PDF §7)

Every piece of case information should be classifiable into exactly one of four kinds, surfaced consistently in the UI (badge/label, not color alone — per Design.md §1 "never rely on color alone"):

| Kind | Definition | Example |
|---|---|---|
| **Fact / Record** | Supported directly by evidence | "CCTV shows Vehicle V01 at Riverside Road, 8:42 PM" |
| **Claim / Statement** | Something a person asserts | "Ali says he was home 8:30–9:00 PM" |
| **System Finding** | Produced by comparing information (human or AI) | "Claimed location conflicts with the CCTV record" |
| **Unknown / Investigation Gap** | Something the case does not establish | "Driver of Vehicle V01 is unknown" |

- Applies to `evidence_items`, `timeline_events`, and the new `alibis`/`contradictions`/`investigation_gaps` objects (schema in Architecture-Phase5.md §2).
- **Must** be explicit in the UI wherever it's shown — an Unknown must never be rendered in a way that implies guilt or certainty (Rules.md §11 spirit extends here: AI/system output is never dressed up as more certain than it is).

### 4.2 Alibi Verification (PDF §14)

- A member with edit-case permission can record a **claimed alibi** for a person (entity), with a time window and free-text description.
- The system (manually by a human, or via the AI Case Completeness Review agent — §4.5) compares the claim against available evidence/timeline entries and assigns a status:
  - **Verified** — supporting evidence found, no conflict.
  - **Partially Verified** — some but not full coverage of the claimed window.
  - **Conflict** — contradicting evidence found (e.g., CCTV places the person/vehicle elsewhere).
  - **Insufficient Data** — not enough evidence either way.
- Every status carries a human-readable explanation and links to the supporting/conflicting evidence — never a bare status with no "why."
- Status changes are logged to the audit trail like any other case-record write (Rules.md §6, §11).
- **Must never** be rendered as a guilt determination (PDF §4/§14/§36) — copy follows Design.md §9's tone rules ("explain why it's a conflict," not "this proves X lied").

### 4.3 Contradiction Detection — elevated to a first-class feature (PDF §15)

Today this is one Legal-domain AI agent. The PDF's version is domain-agnostic and always available, not just AI-triggered:

- Any member with the right permission can **manually flag** two statements/evidence items as contradictory, or the system can surface one automatically (AI agent output feeds into the same object, not a separate one).
- A contradiction record shows: the two (or more) conflicting sources, the specific conflicting detail, relevant time/location, and why it was flagged.
- **Workflow:** a Lead-tier member can **review → resolve, dismiss, or create a task** from a contradiction (mirrors the existing AI-suggestion accept/edit/dismiss pattern in Rules.md §11, but as a case-record object in its own right, not only an `ai_suggestions` row).
- AI-sourced contradictions still land as `ai_suggestions` first (per existing human-in-the-loop rule) and only become a `contradictions` row on acceptance; manually-flagged contradictions write directly (by a permitted human) since no AI output is involved.

### 4.4 Investigation Gaps / Missing Puzzle Pieces (PDF §16)

Described in the source material as the single most important missing feature — do not treat as optional.

- A gap is a structured record of **what the case does not yet establish** — not a vague "problems" flag. Examples from PDF §16: unknown driver, unverified location window, conflicting witness descriptions, missing CCTV, evidence not linked to a known person/event.
- Gaps can be created manually or suggested by the AI Case Completeness Review agent (still human-reviewed before becoming a case-record gap, per the existing human-in-the-loop rule).
- **Must** turn uncertainty into something actionable: every gap has a one-click **"Create Task"** action that pre-fills a task from the gap (e.g., Gap: "driver unknown" → Task: "identify Vehicle V01 driver," per PDF §21).
- Gaps have a status: Open, In Progress (linked task exists), Resolved.

### 4.5 AI Case Completeness Review (PDF §17)

A sixth agent type, distinct from the five existing domain agents (which stay domain-scoped): this one is cross-domain and specifically reviews the room's overall completeness — timeline gaps, unidentified people, a witness-mentioned person not yet added as an entity, an event with no supporting evidence. Same human-in-the-loop contract as every other agent (Rules.md §11): it may only ever propose, never write directly to case-record tables; output lands in `ai_suggestions` and a Lead-tier human accepts/edits/dismisses.

### 4.6 Case Status & Closed Summary (PDF §22)

- Add an **investigation status** distinct from the existing `case_rooms.status` (active/archived, which is a room-lifecycle flag, not an investigation-lifecycle one): `Open → Under Investigation → Review → Closed`. This is additive — it does not replace or repurpose the existing field (Architecture.md §14 additive-migration principle).
- On transition to **Closed**, generate a structured summary: case overview, people, evidence, major events, reconstructed timeline, confirmed findings, contradictions, unresolved gaps, relationships, and investigation status.
- **Must not** present a false legal conclusion (PDF §22, §36) — closed-summary copy is descriptive, never a verdict.

### 4.7 Case Dashboard & Statistics (PDF §8–9)

- Case info block: name, ID, status (both the room-lifecycle and new investigation-lifecycle status), lead, team, date opened.
- Stat tiles: evidence count, people count, locations count, events count, contradictions count, investigation gaps count, unverified-alibi count, AI-findings count.
- Graphs: evidence by type, events over time, investigation status breakdown, evidence/event coverage. Graphs must be meaningful, not decorative (PDF §9) — each one should answer a specific question a Lead would actually ask.

### 4.8 Quick Actions & Navigation (PDF §32–33)

- New top-level nav grouping: **Analysis** (Alibis, Contradictions, Investigation Gaps), alongside the existing Dashboard/Evidence/Timeline/Connections/Discussion/Tasks.
- Quick Actions bar: Add Evidence, Add Event, Add Person, Add Statement, Verify Alibi, Review Contradiction, Review Investigation Gaps, Create Task.

---

## 5. User Stories (new, prioritized per PDF §35's scope classification)

**P0 — must have for Phase 5**
- As a **Lead**, I want a dashboard that shows how complete my case is (evidence, gaps, unresolved contradictions) so I know where to focus next.
- As an **Analyst**, I want to record and check a person's alibi against the evidence so I can document whether it holds up, with the reasoning visible.
- As any **member**, I want to flag two pieces of evidence/statements as contradictory — not just wait for an AI agent to catch it in one domain.
- As a **Lead**, I want the system to show me what the case is still missing, not just what it has, so gaps don't get lost.
- As any **member**, I want a one-click way to turn a gap into a task.

**P1 — should have**
- As a **Lead**, I want an AI agent that reviews the whole case for completeness (not just contradictions) so I don't have to remember to check everything manually.
- As a **Lead**, I want to move a case through a status lifecycle (Open → Closed) and get a structured closed summary I can export.
- As any **member**, I want statistics/graphs on the dashboard that update as the case changes.

**P2 — only if time remains**
- As a **Room Owner**, I want cross-case pattern matching (not just full-text search) against older/closed cases (PDF §24) — explicitly out of scope for Phase 5 itself; see §7.

---

## 6. Non-Functional / Cross-Cutting Requirements

- **Explicit AI consent (PDF §19):** every AI agent run (including the new Case Completeness Review agent) must show the member *what room data will be sent to the external provider* before the call is made, not just a generic "run agent" button. This is stricter than what's currently documented (Architecture.md §7 describes the call happening on trigger, but not a pre-flight data-scope disclosure).
- **No guilt inference, anywhere (PDF §4, §14, §36):** alibi conflicts, contradictions, and gaps are always framed as "the evidence shows X" / "this is unresolved," never as a probability of guilt. This extends Design.md §9's existing voice/tone rule and should be treated as a hard content-review gate for Phase 5 UI copy.
- **Auditability:** every write to `alibis`, `contradictions`, `investigation_gaps`, and case-status transitions must produce an audit_log entry, consistent with the existing rule that all state-changing actions are audited (Rules.md §6, PRD.md §6.5).
- **Permissions:** who can create/resolve/dismiss an alibi/contradiction/gap must be added to the existing per-role permission matrix (PRD.md §10 open question — the matrix is already an open item; Phase 5 adds new dimensions to it rather than being blocked entirely by its resolution).

---

## 7. Open Conflicts With Existing Docs — Need a Product Decision

These are not gaps to fill; they're places where the PDF and the already-built product actively disagree. Flagging rather than resolving unilaterally.

1. **Mobile-first vs. Web+mobile.** PDF §27: *"CaseThread is primarily a mobile application."* Current docs (README, PRD §7, ExecutionPlan §2.3 "both-platform rule") treat Web and Android as equally weighted, with Vercel web hosting as a first-class deployment target. Reconciling these is a product decision, not a documentation gap — it would affect Design.md's breakpoint priorities and ExecutionPlan.md's DoD criteria if changed.
2. **Template marketplace.** PDF §25: *"Templates/template marketplace are not a priority. They should be removed or strongly de-emphasized."* The team already shipped a full marketplace in P4-S1 (draft → publish → materialize, per memory.md). Recommend: do not remove already-tested, shipped functionality based on a doc written before it existed — but this should be an explicit decision on record (memory.md §6 Pending Decisions), not silently ignored.
3. **Cross-case analysis depth.** PDF §24 describes pattern-matching across locations/entities/timelines/methods/vehicles as a Phase 5-or-later, optional stretch feature — notably *not* the same thing as the full-text search already shipped in P4-S2. If genuine cross-case pattern matching is wanted, it should be scoped as its own future phase (Phase 6+), not folded into Phase 5's investigation-intelligence work.

---

## 8. Glossary Additions

| Term | Definition |
|---|---|
| **Fact/Claim/Finding/Unknown** | The four-way classification applied to case information (§4.1). |
| **Alibi Verification** | The recorded comparison of a claimed alibi against available evidence, with a Verified/Partially Verified/Conflict/Insufficient Data status (§4.2). |
| **Contradiction** | A first-class case-record object capturing a conflict between two or more sources, reviewable/resolvable/dismissable independent of which agent (or human) raised it (§4.3). |
| **Investigation Gap** | A structured record of something the case has not yet established, convertible into a task (§4.4). |
| **Investigation status** | The Open/Under Investigation/Review/Closed lifecycle field, additive to the existing `case_rooms.status` (§4.6). |
