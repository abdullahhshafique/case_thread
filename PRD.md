# CaseThread — Product Requirements Document (PRD)

**Status:** Draft v1.0
**Owner:** Product Lead
**Last updated:** 2026-09-10
**Related docs:** [Architecture.md](./Architecture.md) · [Phases.md](./Phases.md) · [Design.md](./Design.md) · [Rules.md](./Rules.md) · [memory.md](./memory.md)

---

## 1. Problem Statement & Context

Any time a group of people need to collaborate around a structured problem — an investigation, a legal matter, a business case, a misconduct hearing, a bug — they run into the same three failures, regardless of domain:

1. **Evidence is scattered.** Documents live in email threads, shared drives, and personal notes. There's no single place that holds "everything we know about this case."
2. **Access is either too loose or too slow.** Either everyone gets a shared folder link with no role boundaries, or IT has to provision enterprise accounts before anyone can collaborate — days or weeks of friction before real work starts.
3. **Nobody can see how the pieces connect.** Who said what, when something contradicts something else, who is connected to whom — this lives in people's heads, not in the tool.

Existing tools solve slices of this for narrow audiences: Kaseware and goCASE serve large investigative agencies with procurement cycles and IT-managed accounts; Cellebrite handles forensic extraction only. None of them serve a legal team, an academic integrity board, and a corporate fraud unit with the *same* lightweight tool.

**Why now:**
- Remote/hybrid collaboration is the default — teams need a shared case room reachable from anywhere, not a filing cabinet.
- LLMs have made domain-tuned assistance (contradiction-checking, entity extraction, anomaly flagging) buildable by a small team as configurable prompts, not a multi-year ML investment.
- Users now expect Discord/Notion-style "generate a code, invite people, start working" onboarding — not a procurement request.

CaseThread solves this with one flexible engine: a **Case Room** with code-based access, role-based permissions, and pluggable domain modules, so the same core serves legal, academic, corporate, medical, and technical teams.

---

## 2. Target Users & Personas

### Persona 1 — Priya, Lead Investigator / Paralegal (Legal & Investigative)
- **Role:** Runs a small legal team or corporate fraud investigation; owns the case end-to-end.
- **Goals:** Centralize evidence, control who sees privileged material, produce a defensible audit trail, export a clean report for filing.
- **Frustrations:** Chasing evidence across email and shared drives; no way to prove chain-of-custody; onboarding a new team member takes an IT ticket.
- **Context:** Time-pressured, moderate technical skill, uses laptop primarily but needs mobile access in the field.

### Persona 2 — Marcus, Academic Integrity Officer (Academic & Student)
- **Role:** Manages misconduct investigations and case-study coursework for a university department.
- **Goals:** Keep a clear timeline of evidence and hearings, compare submitted work for overlap, maintain a fair, auditable process.
- **Frustrations:** Case files live in shared email inboxes; hard to hand off a case mid-semester; no structured way to log a hearing timeline.
- **Context:** Works across academic terms, needs low setup friction (no procurement budget), moderate technical skill.

### Persona 3 — Elena, Analyst / Team Member (cross-domain)
- **Role:** Invited into a case room to do focused work — review evidence, contribute findings, respond to tasks.
- **Goals:** Understand what's expected of her role quickly, know what changed since she last checked in, not be able to accidentally see things outside her clearance.
- **Frustrations:** Being CC'd on everything or nothing; unclear what she's allowed to edit vs. just view.
- **Context:** Often working from mobile between meetings; joins many rooms across different teams.

### Persona 4 — Room Owner / Admin (any domain)
- **Role:** Creates the case room, approves access, manages roles and code rotation.
- **Goals:** Fast setup, confidence that access is locked down, ability to revoke or rotate access instantly if compromised.
- **Frustrations:** Enterprise tools require IT tickets to add/remove a single user.

---

## 3. Success Metrics / KPIs

| Metric | Definition | Target (Phase 1–2) |
|---|---|---|
| Time-to-first-room | Signup → first Case Room created | < 3 minutes |
| Time-to-invite | Room created → second member joined | < 5 minutes |
| Room activation rate | % of created rooms with ≥1 evidence item uploaded within 48h | > 60% |
| Weekly Active Rooms (WAR) | Rooms with any activity in a 7-day window | Track weekly, target growth |
| AI suggestion acceptance rate | % of AI-flagged items a human accepts/edits vs. dismisses outright | > 40% (signals usefulness, not noise) |
| Task completion rate | % of created tasks marked done within their case's lifecycle | Track as UX health signal |
| Report export usage | % of closed/near-closed cases that use PDF/Word export | > 50% |
| NPS (post-Phase 2 pilot) | Standard NPS survey to pilot users | > 30 |
| Cross-role permission incidents | Reported cases of a role seeing data it shouldn't | 0 (hard requirement) |

---

## 4. User Stories / Use Cases (Prioritized)

**P0 — Must have for MVP**
- As a **Room Owner**, I want to create a Case Room and select a case type so that my team has a dedicated, isolated workspace.
- As a **Room Owner**, I want a private, rotatable access code so that only people I intend to invite can join.
- As an **invitee**, I want to enter a code and select/be assigned a role so that I can join a room without an admin manually provisioning my account.
- As a **Room Owner**, I want to approve or deny join requests so that I control who is actually inside the room.
- As any **member**, I want to upload evidence/documents to a shared vault so that the team has one source of truth.
- As any **member**, I want to see an immutable audit log of who did what, when, so that the case remains defensible.
- As a **Lead**, I want role-based permissions enforced so that a Reviewer or Observer cannot edit or see privileged fields.
- As any **member**, I want a case timeline so that I can see how events and evidence relate chronologically.

**P1 — Should have, targeted for Phase 2–3**
- As an **Analyst**, I want an AI agent to flag contradictions in statements so that I can focus my review on what matters.
- As a **Lead**, I want to accept/edit/dismiss AI-generated findings so that nothing enters the record without human sign-off.
- As any **member**, I want an entity/relationship map so that I can see how people, orgs, and evidence connect.
- As a **Room Owner**, I want field-level redaction (e.g., hide witness contact info from Viewers) so that sensitive data stays scoped correctly even within a room.
- As a **Lead**, I want to export a case summary to PDF/Word so that I can file it or share it outside the platform.
- As any **member**, I want a notification/activity feed so that I know what changed since I last opened the room.

**P2 — Nice to have, later phases**
- As a **Room Owner**, I want to search across all my cases for a person/company so that I can spot cross-case patterns.
- As a **team**, I want to design and share our own case-type template so that we can reuse our own workflow.
- As a **field investigator**, I want offline-first mobile mode so that I can keep working without connectivity and sync later.
- As any **member**, I want version history on documents/notes so that nothing is silently overwritten.

---

## 5. Scope & Out-of-Scope

### In scope for MVP (Phase 1, see Phases.md)
- Case Room creation, access codes, role-based join flow, owner approval
- Shared core: dashboard, timeline, document vault, discussion thread, task list, immutable audit log
- Two domain modules: **Legal/Investigative** and **Academic**
- Web + mobile (Flutter) client, Supabase-backed auth/data/storage
- Basic role-based access control (RBAC) at the room level

### Explicitly out of scope for MVP
- AI agent workflows (Phase 3)
- Field-level redaction beyond basic role gating (Phase 2+)
- Cross-case search (Phase 4)
- Template marketplace (Phase 4)
- Offline-first mobile sync (Phase 4)
- Formal compliance certification (SOC 2, HIPAA, GDPR audits) — the system is *designed toward* these, not certified (see PRD §9 in the original concept and Architecture.md §Security)
- Payment/billing integration (business model is directional; no paid tier is built in MVP)

---

## 6. Functional Requirements

### 6.1 Case Room Creation & Access
- User must be authenticated to create a room.
- Room creation requires: room name, case type (from supported list), owner assignment (defaults to creator).
- System generates a unique access code (format: 8-character alphanumeric, case-insensitive, excludes ambiguous characters like `0/O`, `1/I`).
- Owner can rotate the code at any time; rotating immediately invalidates the old code for new join attempts (does not remove existing members).
- **Edge case:** if a code collision occurs on generation, regenerate silently — never surface a collision to the user.
- **Edge case:** rotating a code while a join request is pending on the old code — the pending request remains valid; only *new* join attempts use the new code.

### 6.2 Join & Role Selection
- User enters a code → system validates it exists and is active → user selects a requested role from the case type's allowed role list (or the room configuration restricts self-selection and requires an admin-assigned role).
- Join request enters a **pending** state until the Owner/Admin approves or denies it.
- **Validation:** invalid/expired code → clear error, no information leaked about whether the code ever existed.
- **Validation:** rate-limit join attempts per user/IP to prevent code brute-forcing (see Architecture.md §Security).
- **Edge case:** user already a member attempts to rejoin with the code — system recognizes existing membership and routes them straight into the room.

### 6.3 Roles & Permissions
- Each case type defines an allowed role set (e.g., Legal: Lead Investigator, Analyst, Legal Counsel, Reviewer, Observer, Client).
- Each role has a permission matrix across: view case, edit case, upload evidence, comment, approve AI findings, manage members, export reports, view privileged/redacted fields.
- Permission checks are enforced server-side (Supabase RLS policies), never only in the UI (see Architecture.md §Security).
- **Edge case:** a member's role is changed mid-session — their permitted actions must update on next request; in-flight actions that are no longer permitted should fail gracefully with a clear message, not silently no-op.

### 6.4 Evidence & Document Vault
- Supported upload types (MVP): PDF, DOCX, PNG/JPG, TXT, common audio formats (metadata only in MVP; playback UI is P1).
- File size limit (MVP): 50MB per file — configurable per deployment.
- Every upload is logged to the audit trail with uploader, timestamp, and file hash.
- **Edge case:** duplicate filename upload — system appends a version suffix, does not overwrite.
- **Edge case:** upload failure mid-transfer — partial file must not be visible to other members; retry is user-initiated.

### 6.5 Timeline & Audit Log
- Audit log entries are append-only; no UI path exists to edit or delete a log entry (immutability enforced at the database layer, not just the UI).
- Every state-changing action (create, edit, delete, role change, AI suggestion, approval) produces an audit entry with actor, timestamp, action type, and affected object.
- Timeline is derived from a mix of manually-added events and system-logged events; manually-added events are editable by permitted roles, but edits are themselves logged.

### 6.6 Discussion & Tasks
- Threaded discussion scoped to the room; mentions (`@member`) trigger a notification.
- Tasks have: title, assignee, due date (optional), status (open/in progress/done), linked evidence (optional).

### 6.7 Error States (general)
- Network loss mid-action: client queues the action locally (where feasible) and retries; user is shown a non-blocking "syncing" indicator, never a silent failure.
- Permission-denied action: clear, specific message ("Your role — Observer — can't upload evidence in this room") rather than a generic 403.
- Session expiry: user is prompted to re-authenticate without losing unsaved form input where technically feasible.

---

## 7. Non-Functional Requirements

| Category | Requirement |
|---|---|
| **Performance** | Initial page/app load < 2.5s on broadband; room dashboard interaction < 200ms perceived latency for cached data |
| **Availability** | Target 99.5% uptime for MVP/pilot phase (Supabase + Vercel SLAs as the practical ceiling) |
| **Security** | TLS in transit everywhere; encryption at rest via Supabase-managed Postgres encryption; RBAC enforced via Row Level Security, not client-side only |
| **Accessibility** | WCAG 2.1 AA minimum across web client; AAA for primary text contrast where feasible (see Design.md) |
| **Browser/device support** | Latest 2 versions of Chrome, Safari, Firefox, Edge; iOS 16+; Android 10+ (API 29+) |
| **Scalability** | Architecture must support horizontal growth in rooms/users without redesign through Phase 2; specific load targets to be set once pilot usage data exists |
| **Data residency** | GDPR-aware: user data region-tagged where the hosting layer allows; clear data export/deletion path per user request |
| **Auditability** | All audit log writes must be tamper-evident (append-only, no destructive UI/API path) |

---

## 8. User Flow Summaries

1. **Room creation flow:** Sign up/in → "Create Case Room" → select case type → name room → room created with generated code → owner lands on empty dashboard.
2. **Join flow:** Receive code (out-of-band, e.g., verbally or via message) → "Join Room" → enter code → select requested role → pending state → owner approves → member lands in room with role-scoped view.
3. **Evidence-to-audit flow:** Member uploads document → system stores file, creates vault entry, writes audit log entry → entry appears in team discussion feed (optional) and timeline.
4. **AI-assisted flow (Phase 3):** Member triggers an agent from the workflow panel → agent processes room data → finding posted to timeline as a **suggestion** (visually distinct) → Lead-role member accepts/edits/dismisses → decision logged in audit trail.
5. **Export flow:** Lead selects "Export Report" → system compiles case summary, timeline, and approved findings → PDF/Word generated → download link provided.

Detailed flow diagrams (sequence/state diagrams) live in Architecture.md §Data Flow.

---

## 9. Assumptions & Dependencies

- **Supabase** is assumed available and within its published SLAs/limits for auth, Postgres, storage, and realtime; a Supabase outage is a full-product outage in MVP (no fallback planned until Phase 2+).
- **Flutter** web build performance on low-end devices is assumed acceptable; to be validated in Phase 1 with real device testing.
- **LLM providers** (Claude, GPT, Gemini, Grok — see Architecture.md §AI layer) are accessed via their public APIs; provider outage/rate-limit degrades AI features gracefully but must not block core case-room functionality.
- **Regulatory constraint:** no formal legal/medical/compliance certification is claimed at MVP stage; language throughout the product and marketing must say "designed for" / "readiness path," never "certified" or "compliant," until an actual audit occurs (see PRD §5 out-of-scope and Architecture.md §Security).
- Mobile app store distribution (Play Store/App Store) is a Phase 4+ dependency, gated on Apple/Google review timelines outside our control.

---

## 10. Open Questions

| Question | Owner | Needed by |
|---|---|---|
| Exact permission matrix per role, per case type (full grid) | Product + Legal domain SME | Before Phase 1 dev freeze |
| File size/type limits for medical imaging in future Medical module | Product | Phase 2 planning |
| Which LLM provider is default at demo day vs. left fully user-configurable | Eng lead (AI layer) | Before Phase 3 kickoff |
| Data retention policy (how long is a closed case room retained?) | Product + Legal SME | Before Phase 2 |
| Paid tier feature gating specifics (§8 Business Model in concept doc) | Product + Founders | Before any billing work begins (Phase 4+) |
| Do Observer/Client roles get mobile push notifications, or web-only? | Product + Design | Phase 2 design review |

---

## 11. Glossary

| Term | Definition |
|---|---|
| **Case Room** | An isolated, private workspace for a single case; the core unit of the product. |
| **Access code** | A unique, rotatable code required to request joining a Case Room. |
| **Role** | A named permission set assigned to a member within a room (e.g., Lead Investigator, Observer). |
| **Domain module** | A case-type-specific set of fields, templates, and AI agents layered on top of the shared core. |
| **Shared core** | The features every Case Room has regardless of case type (dashboard, timeline, vault, audit log, etc.). |
| **Agent / AI agent** | A configurable LLM-backed workflow step (e.g., Contradiction Checker) that produces a suggestion, never a final decision. |
| **Human-in-the-loop** | The requirement that all AI output is reviewed and explicitly accepted/edited/dismissed by a permitted human role before it's treated as part of the case record. |
| **Audit log / audit trail** | The append-only, immutable record of every state-changing action in a room. |
| **RLS (Row Level Security)** | Supabase/Postgres mechanism enforcing per-row access rules at the database layer. |
| **RBAC** | Role-Based Access Control. |
