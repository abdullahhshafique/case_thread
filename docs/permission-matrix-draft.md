# CaseThread — Permission Matrix (DRAFT)

**Status:** ⚠️ **DRAFT — pending domain-SME review** (ExecutionPlan.md §1, item P1)
**Last updated:** 2026-09-10
**Seed data:** `supabase/migrations/0004_case_types_and_role_seeds.sql` — **this document and that migration must change together**
**Owner of sign-off:** Product Lead + Legal domain SME (PRD.md §10)

> RLS policies in `0005_rls_core_policies.sql` are built against this grid. The SME review is a **merge gate**: policy changes that rely on this matrix may be drafted and tested, but the grid must be signed off before Phase 1 exit (not before development — see ExecutionPlan.md §1 note).

---

## 1. Permission dimensions

From PRD §6.3 — the eight keys evaluated in RLS via `user_room_permission()`:

| Key | Meaning |
|---|---|
| `view_case` | See the room and its content |
| `edit_case` | Edit case details, create manual timeline events and tasks |
| `upload_evidence` | Add files to the vault |
| `comment` | Post in the discussion thread, @mention members |
| `approve_ai_findings` | Accept/edit/dismiss AI suggestions (Lead-tier) |
| `manage_members` | Approve/deny join requests, change roles, rotate code |
| `export_reports` | Generate PDF/Word case export |
| `view_privileged` | See privileged/redacted fields within the room |

**Owner override:** the room owner always holds `manage_members` on their own room regardless of their role's grid (enforced in `room_members` update policy: owner-scoped, not permission-key-scoped). This is why `manage_members` is `true` for the Lead-tier roles and still separately enforced for owners.

## 2. Legal / Investigative — role grid

Role set taken verbatim from PRD §6.3.

| Permission | Lead Investigator | Analyst | Legal Counsel | Reviewer | Observer | Client |
|---|---|---|---|---|---|---|
| `view_case` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `edit_case` | ✅ | ✅ | ✅ | — | — | — |
| `upload_evidence` | ✅ | ✅ | ✅ | — | — | ✅ |
| `comment` | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| `approve_ai_findings` | ✅ | — | ✅ | — | — | — |
| `manage_members` | ✅ | — | — | — | — | — |
| `export_reports` | ✅ | — | ✅ | — | — | — |
| `view_privileged` | ✅ | — | ✅ | — | — | — |
| **Lead-tier?** | **yes** | no | **yes** | no | no | no |

**Reasoning (for SME review):**
- **Analyst** gets no `view_privileged` — privileged material stays with legal/leads; analysts work the general evidence pool.
- **Client** can upload + comment (clients submit their own documents) but never see privileged strategy.
- **Reviewer** is read + comment only — an oversight function, not a work function.
- **Observer** is the strictest: pure visibility (PRD persona Elena's "not able to see things outside her clearance").

## 3. Academic — role grid (PROPOSED)

PRD leaves the exact Academic role names open (PRD.md §10). This is a proposed mapping from the misconduct-hearing process; **the SME review should confirm or rename.**

| Permission | Integrity Officer | Panel Member | Advisor | Respondent | Witness |
|---|---|---|---|---|---|
| `view_case` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `edit_case` | ✅ | — | ✅ | — | — |
| `upload_evidence` | ✅ | — | ✅ | ✅ | ✅ |
| `comment` | ✅ | ✅ | ✅ | ✅ | — |
| `approve_ai_findings` | ✅ | — | ✅ | — | — |
| `manage_members` | ✅ | — | — | — | — |
| `export_reports` | ✅ | — | ✅ | — | — |
| `view_privileged` | ✅ | — | — | — | — |
| **Lead-tier?** | **yes** | no | **yes** | no | no |

**Proposed reasoning:**
- **Integrity Officer** = the academic equivalent of Lead Investigator (persona Marcus, PRD §2).
- **Respondent** (the accused student) can see the case and submit their evidence — a fairness requirement for academic integrity processes — but not edit the case record.
- **Witness** can submit evidence but not see discussion (deliberation privacy).
- **Advisor** is faculty support with Lead-tier AI-approval rights but no privileged visibility.

## 4. Open questions for SME review

| # | Question | Current draft answer |
|---|---|---|
| 1 | Should Academic Panel Members see AI suggestions before the hearing? | Yes (view only — `view_case` covers `ai_suggestions` reads) |
| 2 | Does the Respondent see the full audit trail, or a filtered version? | Full (member-scoped, same as other members) |
| 3 | Legal `client` upload — should uploaded items be quarantined until reviewed? | Not modeled yet; flag for Phase 2 redaction work |
| 4 | Academic `advisor` `view_privileged: false` — correct? | Yes per draft; SME to confirm |
| 5 | Should `observer` see the audit log at all? | Yes currently (any member sees the room's audit trail — it's the defensibility promise) |

## 5. Change log

| Date | Change | Author |
|---|---|---|
| 2026-09-10 | Initial draft, both case types, seeded as migration 0004 | ZCode (AI-assisted), per ExecutionPlan.md Sprint 2 |
