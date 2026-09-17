# CaseThread — Phase 5: Investigation Intelligence Layer

**Status:** Draft v0.1 — not yet scoped/started (memory.md §5: *"Phase 5 has not been scoped"*)
**Last updated:** 2026-09-17
**Related docs:** [Phases.md](./Phases.md) · [PRD-Phase5.md](./PRD-Phase5.md) · [Architecture-Phase5.md](./Architecture-Phase5.md) · [ExecutionPlan.md](./ExecutionPlan.md) · [memory.md](./memory.md)

> Phases.md covers Phase 0–4, all complete. This document proposes Phase 5, scoped entirely from the features identified as missing in PRD-Phase5.md. It follows the same table structure as Phases.md so it can be appended there directly once reviewed.

---

## 1. Objective

Ship the investigation-analysis layer described in `DOC-20260915-WA0014.pdf` but absent from the shipped product: Fact/Claim/Finding/Unknown classification, a real Dashboard with statistics/graphs, Alibi Verification, first-class Contradiction Detection, Investigation Gaps, an AI Case Completeness Review agent, and Case Status/Closed Summary — all human-in-the-loop, all additive to the existing schema.

**Prerequisite:** the three Open Conflicts in PRD-Phase5.md §7 (mobile-first framing, template-marketplace stance, cross-case pattern-matching depth) should get an explicit product decision before or at Phase 5 kickoff — none of them block the epics below technically, but leaving them unresolved risks the same kind of drift that produced this gap in the first place.

---

## 2. Epic Breakdown

| Epic | Priority | Notes |
|---|---|---|
| Fact/Claim/Finding/Unknown classification on evidence + timeline | P0 | Additive nullable column (Architecture-Phase5.md §2.9); no backfill required to ship |
| Investigation Gaps (manual creation, status, gap→task) | P0 | The PDF's "major feature" (§16) — sequence first given how central it is to the product story |
| Alibi Verification (claim, evidence links, status+reason) | P0 | |
| Contradiction Detection elevated to first-class object + review workflow | P0 | Existing Contradiction Checker agent's output now lands here (via `ai_suggestion_id` traceability) instead of being a standalone Legal-only feature |
| Case Dashboard + statistics view + graphs | P0 | Depends on the above three existing as queryable objects — sequence last within P0 |
| AI Case Completeness Review agent | P1 | Sixth agent, cross-domain; same human-in-the-loop contract as the existing five |
| Case Status lifecycle + Closed Summary generation/export | P1 | Additive `investigation_status` field; extends existing export service |
| Analysis nav section + Quick Actions bar | P1 | UI-only, depends on P0 epics existing to link to |
| Explicit AI data-sharing consent step | P1 | Applies to all six agents, not just the new one — touches the existing AI workflow panel |

**Not in this phase (see PRD-Phase5.md §7):** cross-case pattern matching beyond existing full-text search; any mobile-first restructuring; any change to the template marketplace's existing scope.

---

## 3. Definition of Done

- All P0 epics shipped and demoable end-to-end: a member can flag a contradiction, verify an alibi, log a gap, convert it to a task, and see all four reflected on the dashboard.
- New tables (`alibis`, `alibi_evidence_links`, `contradictions`, `contradiction_sources`, `investigation_gaps`, `case_closed_summaries`) each have explicit allow/deny RLS contract tests (Rules.md §7) — non-negotiable, same standard applied to every prior phase.
- `v_case_statistics` verified not to leak redacted-field counts (Architecture-Phase5.md §6).
- No case-record write from the AI Case Completeness Review agent bypasses `ai_suggestions` — verified the same way the existing five agents were (Rules.md §11, already-proven pattern).
- No UI copy for alibi/contradiction/gap status implies a guilt conclusion — a content-review pass against Design.md §9's tone rules, treated as a hard gate, not a nice-to-have.
- The three Open Conflicts (PRD-Phase5.md §7) have a recorded decision in memory.md §6, even if the decision is "no change."

---

## 4. Dependencies

- Phase 1–4 core stable (already true — Phase 4 exit was 166/166 pgTAP, 82 Dart, 9 Deno, per memory.md).
- `entities`/`entity_relationships` (Phase 2) and `ai_suggestions` (Phase 3) patterns are reused directly — no new architectural pattern is introduced, which keeps risk low relative to prior phases.
- Full permission matrix (PRD.md §10, still an open item as of memory.md §6) needs new rows for the alibi/contradiction/gap actions — this can proceed against a draft matrix the same way Phase 1 did (ExecutionPlan.md §1, "draft-matrix" allowance), but the SME-review gate still applies before the corresponding RLS policies merge to `main`.

---

## 5. Risks

| Risk | Trigger | Mitigation | Owner |
|---|---|---|---|
| Guilt-implying UI copy slips through | Any alibi/contradiction/gap-facing screen | Explicit content-review gate in DoD (§3); reuse Design.md §9 tone rules as the checklist | Product + Design |
| `investigation_status` confused with existing `status` (active/archived) in code or UI | Anywhere both fields are surfaced together | Name them distinctly in the UI ("Investigation status" vs "Room status"); pgTAP test asserting both columns are independently settable | Backend eng |
| Sixth agent's cross-domain scope creates prompt-injection surface across all case types at once (not just one domain) | Phase 5 agent design | Same mitigation as Phase 3 (Architecture.md §9: all AI output treated as unprivileged) — no new mitigation needed, but worth explicit re-verification given the broader scope | AI-layer eng |
| Open Conflicts (§1) left undecided, causing rework later | Ongoing | Force a decision at kickoff, not mid-phase | Product Lead |

---

## 6. Resources

Same team shape as Phase 2–4 (Architecture.md §4/Phases.md resource notes): backend/DB engineer(s) for the new tables + RLS, Flutter engineer(s) for the Analysis tab/Dashboard/Quick Actions, 1 designer for the new status badges/graph treatments (extends Design.md §1 palette — likely one or two new token values for alibi/gap status, since the existing pending/success/error tokens don't cleanly cover "Partially Verified" or "Insufficient Data").

---

## 7. Deliverables

Migration files continuing from `0025`, RLS contract test suite additions, `features/alibis/`, `features/contradictions/`, `features/investigation_gaps/`, `features/dashboard/` (Flutter, feature-based per Rules.md §1), sixth agent config row, updated export service, updated memory.md.

---

## 8. Go/No-Go for Phase 6 (if any)

All P0 + P1 epics shipped, DoD (§3) fully met, and the three Open Conflicts resolved and recorded. Phase 6 candidates (not scoped here) would be whatever remains from PRD-Phase5.md §5's P2 tier — namely genuine cross-case pattern matching, if the product decision in §7/Open-Conflicts lands in favor of building it.
