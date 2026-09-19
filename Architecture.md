# CaseThread — Architecture

**Status:** Draft v1.0
**Last updated:** 2026-09-10
**Related docs:** [PRD.md](./PRD.md) · [Rules.md](./Rules.md) · [Phases.md](./Phases.md) · [memory.md](./memory.md)

---

## 1. Tech Stack Summary

| Layer | Choice | Notes |
|---|---|---|
| Frontend | **Flutter** (Dart) | Single codebase → Web, Android, iOS |
| Frontend state management | **Riverpod** | Testable, compile-safe, scales better than plain Provider for a larger team |
| Backend | **Supabase** | Postgres, Auth, Realtime, Storage, Edge Functions |
| Database | **Postgres** (via Supabase) | Relational core; graph-style queries via recursive CTEs / `ltree` or `age` extension for entity-relationship map (evaluate in Phase 2) |
| AI layer | **Pluggable LLM adapter** | Supports Anthropic Claude, OpenAI, Google Gemini, xAI Grok behind one interface |
| Hosting (web) | **Vercel** | CI/CD, PR preview deploys for the Flutter web build |
| Hosting (backend) | **Supabase Cloud** | Managed Postgres, Auth, Storage, Realtime, Edge Functions |
| Mobile distribution | **Play Store / App Store** | Phase 4+, gated on store review |
| CI/CD | **GitHub Actions** + Vercel auto-deploy | Lint/test/build on PR, deploy on merge to `main` |

---

## 2. Design Principles & Constraints

- **API-contract driven** — the Flutter client only talks to Supabase through typed request/response contracts; no ad-hoc query strings scattered through UI code.
- **RLS-first security** — permission logic lives in the database (Row Level Security policies), never solely in client code. The UI hides what a role shouldn't see; the database refuses it even if the UI is bypassed.
- **One core, many configs** — domain modules are data (JSON schema + template config), not separate codebases or forked apps.
- **Human-in-the-loop AI** — no AI output writes directly to case-record state; it always lands in a "suggestion" state requiring explicit human action.
- **Offline-tolerant, not offline-first (MVP)** — MVP assumes connectivity but degrades gracefully on brief network loss (local queue + retry). True offline-first is a Phase 4 goal.
- **Boring where it counts** — auth, permissions, and audit logging use well-understood, auditable patterns (Postgres RLS, append-only tables) rather than novel/clever mechanisms, because these are the parts that must be defensible.

---

## 3. High-Level Diagram

```
                    ┌─────────────────────────────────────────┐
                    │              Flutter Client              │
                    │        (Web · Android · iOS)             │
                    │  Riverpod state · typed API contracts    │
                    └───────────────┬───────────────────────────┘
                                    │ HTTPS / WSS
                    ┌───────────────▼───────────────────────────┐
                    │                Supabase                   │
                    │  ┌───────────┐ ┌───────────┐ ┌──────────┐ │
                    │  │   Auth    │ │  Postgres │ │ Storage  │ │
                    │  │ (JWT)     │ │ (+ RLS)   │ │ (files)  │ │
                    │  └───────────┘ └───────────┘ └──────────┘ │
                    │  ┌───────────┐ ┌───────────────────────┐  │
                    │  │ Realtime  │ │   Edge Functions       │  │
                    │  │ (channels)│ │  (AI orchestration,    │  │
                    │  └───────────┘ │   export, webhooks)    │  │
                    │                └───────────┬────────────┘  │
                    └────────────────────────────┼────────────────┘
                                                  │ HTTPS
                          ┌───────────────────────▼────────────────────┐
                          │           AI Adapter Layer (Edge Fn)         │
                          │   Normalizes prompts/responses across:       │
                          │   Claude API · OpenAI API · Gemini · Grok    │
                          └───────────────────────────────────────────────┘

        Hosting: Vercel (Flutter web build, CI/CD) · Supabase Cloud (backend)
```

*(This ASCII diagram is the source of truth for MVP; a polished visual — e.g., a Mermaid or Excalidraw diagram — should be linked here once produced. See Phases.md for the AI-image-generation prompt to create a polished version for the README/LinkedIn assets.)*

---

## 4. Component Breakdown

| Component | Responsibility | Tech | Notes |
|---|---|---|---|
| **Auth module** | Sign up/in, session management, JWT issuance | Supabase Auth | Email/password MVP; SSO is a paid-tier Phase 4 feature |
| **Room service** | Create/join/manage Case Rooms, code generation/rotation | Postgres table + Edge Function for code logic | Codes generated server-side only |
| **Membership & roles service** | Join requests, approval, role assignment, permission checks | Postgres + RLS policies | Source of truth for all permission checks |
| **Vault service** | File upload/download, versioning, hashing | Supabase Storage + Postgres metadata table | Enforces size/type limits from PRD §6.4 |
| **Timeline & audit service** | Append-only event log, timeline rendering | Postgres (append-only table, no UPDATE/DELETE grants) | Immutability enforced at the grant level, not app logic |
| **Discussion/task service** | Threaded comments, `@mentions`, task CRUD | Postgres + Realtime channels | Realtime for live discussion updates |
| **AI workflow panel** | Trigger agents, display suggestions, capture accept/edit/dismiss | Flutter UI + Edge Function orchestration | Calls AI Adapter Layer; never writes directly to case tables |
| **AI Adapter Layer** | Normalize calls across LLM providers; provider fallback/config | Edge Function | Config-driven provider selection (see PRD open question) |
| **Export service** | Compile case summary/timeline/findings → PDF/Word | Edge Function + a document-generation library | Triggered on-demand, not scheduled in MVP; Phase 5 extends to include contradictions, alibis, gaps, investigation status |
| **Notification/activity feed** | Surface "what changed since you last opened this room" | Postgres + Realtime | P1, built in Phase 2 |
| **Investigation intelligence** | Alibis, contradictions, investigation gaps, case statistics | Postgres tables + security-definer RPCs | Phase 5; all writes land as `ai_suggestions` until human accept via review_suggestion() |
| **Case status service** | Investigation lifecycle (open/under_investigation/review/closed) | Postgres column + transition RPC | Additive to room status (case_room.status = room lifecycle); auto-generates closed summary |

---

## 5. Data Model / Schema (Logical)

**Core entities:**

- `users` — Supabase Auth-managed identity; `profiles` table extends it with display name, avatar.
- `case_rooms` — id, name, case_type, owner_id, access_code_hash, code_rotated_at, created_at, status (active/archived).
- `room_members` — room_id, user_id, role, status (pending/approved/revoked), joined_at.
- `roles` — case_type-scoped role definitions and their permission matrix (JSONB permission grid, evaluated in RLS policies).
- `evidence_items` — id, room_id, uploader_id, filename, storage_path, file_hash, version, uploaded_at.
- `timeline_events` — id, room_id, type (manual/system/ai_suggestion), actor_id (nullable for system), payload (JSONB), occurred_at, created_at.
- `audit_log` — id, room_id, actor_id, action_type, object_type, object_id, metadata (JSONB), created_at. **Append-only; no UPDATE/DELETE grants for any role.**
- `discussion_messages` — id, room_id, author_id, body, mentions (array), created_at.
- `tasks` — id, room_id, title, assignee_id, due_date, status, linked_evidence_id (nullable).
- `ai_suggestions` — id, room_id, agent_type, input_ref, output (JSONB), status (pending/accepted/edited/dismissed), reviewed_by, reviewed_at. **All AI output lands here first — never directly in case tables (human-in-the-loop).**
- `entities` / `entity_relationships` — for the entity-relationship map; `entities` (id, room_id, type [person/org/location/evidence/vehicle], name, attributes JSONB), `entity_relationships` (from_entity_id, to_entity_id, relationship_type, room_id).
- `alibis` — id, room_id, entity_id, claimed_window_start/end, claim_text, source, status (verified/partially_verified/conflict/insufficient_data), status_reason, created_by, verified_by, created_at, verified_at. **Verified only via `verify_alibi()` RPC.**
- `alibi_evidence_links` — id, alibi_id, evidence_item_id/timeline_event_id (polymorphic), relation (supports/conflicts). Exactly one of evidence_item_id/timeline_event_id populated.
- `contradictions` — id, room_id, source_type (manual/ai_suggestion), ai_suggestion_id (nullable), conflicting_detail, relevant_time/location, flagged_reason, status (open/resolved/dismissed), linked_task_id, flagged_by, resolved_by, created_at, resolved_at.
- `contradiction_sources` — id, contradiction_id, evidence_item_id/timeline_event_id/alibi_id (polymorphic). Exactly one populated per row.
- `investigation_gaps` — id, room_id, gap_type, description, source_type (manual/ai_suggestion), ai_suggestion_id (nullable), status (open/in_progress/resolved), linked_task_id, created_by, created_at, resolved_at.
- `case_closed_summaries` — id, room_id (unique), summary_json (JSONB), generated_at, generated_by. Auto-generated when investigation_status → closed.
- `case_rooms.investigation_status` — (open/under_investigation/review/closed) additive to room status (case_room.status = room lifecycle).

**Relationships (summary):**
- A `case_room` has many `room_members`, `evidence_items`, `timeline_events`, `audit_log` entries, `discussion_messages`, `tasks`, `ai_suggestions`, `entities`.
- A `room_member` maps one `user` to one `case_room` with exactly one active `role`.
- `ai_suggestions` reference `timeline_events` once accepted (an accepted suggestion becomes a timeline event, logged in `audit_log`).

**Database choice rationale:** Postgres (via Supabase) for relational integrity on rooms/roles/permissions, with either recursive queries or a graph extension (e.g., Apache AGE) evaluated in Phase 2 once real entity-relationship volume/query patterns exist — avoids introducing a second database technology before it's justified.

---

## 6. API Design

MVP uses **Supabase's auto-generated REST/RPC layer** (PostgREST) for straightforward CRUD, backed entirely by RLS, plus **Edge Functions** for anything requiring server-side orchestration (code generation, AI calls, export).

| Endpoint (logical) | Method | Auth | Purpose |
|---|---|---|---|
| `/rooms` | POST | JWT required | Create a Case Room |
| `/rooms/:id/join` | POST | JWT required | Submit a join request with a code |
| `/rooms/:id/members/:memberId/approve` | POST | JWT + Owner/Admin role | Approve a pending join request |
| `/rooms/:id/code/rotate` | POST | JWT + Owner/Admin role | Rotate access code |
| `/rooms/:id/evidence` | POST/GET | JWT + role permission check | Upload/list evidence |
| `/rooms/:id/timeline` | GET | JWT + role permission check | Fetch timeline |
| `/rooms/:id/audit-log` | GET | JWT + role permission check | Fetch audit trail (view-only, never writable via API) |
| `/rooms/:id/agents/:agentType/run` (Edge Fn) | POST | JWT + role permission check | Trigger an AI agent |
| `/rooms/:id/suggestions/:id/decision` | POST | JWT + Lead-tier role | Accept/edit/dismiss an AI suggestion |
| `/rooms/:id/export` (Edge Fn) | POST | JWT + role permission check | Generate PDF/Word export |
| `/rooms/:id/alibis` | GET/POST | RLS (members read, edit_case write) | List/create alibis |
| `/rooms/:id/alibis/:id/verify` | POST | RLS (edit_case) | Verify alibi via `verify_alibi()` |
| `/rooms/:id/contradictions` | GET/POST | RLS (members read, edit_case manual write, approve_ai_findings update) | List/flag/resolve contradictions |
| `/rooms/:id/gaps` | GET/POST | RLS (members read, edit_case write) | List/create investigation gaps |
| `transition_investigation_status` | RPC | RLS (edit_case) | Transition investigation status; generates closed summary on →closed |
| `gap_create_task` | RPC | RLS (edit_case) | Convert a gap to a task |
| `v_case_statistics` | RPC | authenticated | Room statistics (counts by category, RLS-scoped) |

- **Authentication:** Supabase Auth issues short-lived JWTs; refresh tokens handled by the Supabase client SDK.
- **Authorization:** every table has RLS policies keyed off `room_members.role` and the case type's permission matrix — this is the actual enforcement point, not the API layer.
- **Versioning strategy:** Edge Functions are versioned by route prefix (`/v1/...`) from day one; PostgREST auto-generated endpoints are versioned implicitly by schema migrations (breaking schema changes ship as additive columns/views, not destructive changes, wherever possible).

---

## 7. Data Flow — Critical Paths

**Login:**
`Client → Supabase Auth (email/password) → JWT issued → stored in secure client storage → attached to all subsequent requests`

**Join room:**
`Client submits code → Edge Fn validates code hash + room status → creates pending room_members row → Realtime notifies Owner → Owner approves → RLS now grants that user row-level access → Client receives updated permission set`

**AI agent workflow:**
`Member triggers agent from workflow panel → Edge Fn gathers data scope (timeline events, evidence items, entities, members — scoped by RLS as the calling user) → Edge Fn discloses scope to caller BEFORE provider call (AI consent, PRD §19) → user confirms → Edge Fn calls AI Adapter Layer → Adapter normalizes request to configured provider (Claude/GPT/Gemini/Grok) → response written to ai_suggestions (status=pending) → Realtime pushes to timeline UI as a visually-distinct suggestion → Lead-role member accepts/edits/dismisses → decision + resulting timeline_event + audit_log entry written atomically (single transaction)`

**Investigation status transition:**
`Member triggers status transition → `transition_investigation_status` RPC validates permission → if →closed, auto-generates `case_closed_summaries` row with JSONB snapshot → audit_log entry recorded`

**Export (Phase 5 extended):**
`Lead triggers export → Edge Fn compiles case summary + timeline + findings + contradictions + alibis + investigation gaps + investigation status → renders PDF/Word → returns signed download URL (Storage, time-limited) → audit_log entry recorded`

---

## 8. State Management Strategy

- **Frontend (Flutter):** Riverpod for all app state — `AsyncNotifier`/`StreamNotifier` providers wrapping Supabase Realtime subscriptions for live data (discussion, timeline, audit log); plain `Notifier` providers for local UI state (form state, navigation state). No global mutable singletons outside Riverpod's container.
- **Backend:** Supabase handles session state (JWT + refresh token); no custom server-side session store needed in MVP. Realtime channels are scoped per-room (`room:{id}`) to avoid over-broadcasting.
- **Caching:** client-side cache of recently-viewed rooms/timelines via Riverpod's built-in provider caching + `keepAlive` where appropriate; no separate cache layer (e.g., Redis) introduced until Phase 2+ load data justifies it.

---

## 9. Security Architecture

- **Transport:** TLS everywhere (enforced by Vercel + Supabase defaults).
- **Encryption at rest:** Supabase-managed Postgres encryption at rest; Storage buckets encrypted at rest.
- **RBAC enforcement point:** Postgres RLS policies, keyed off `room_members.role` joined against the case type's permission matrix — this is the real security boundary, not the Flutter UI.
- **Access codes:** stored as a hash (never plaintext) in `case_rooms`; rate-limited join attempts (per-IP and per-user) to resist brute-forcing an 8-character code space.
- **Field-level redaction (Phase 2):** implemented as column-level views or JSONB field masking in the query layer per role, not a client-side hide.
- **Input sanitization:** all user text (discussion, task titles, evidence metadata) sanitized before rendering to prevent injection into any HTML rendering surface (export-to-PDF, web display).
- **Secrets:** LLM provider API keys and Supabase service-role keys live only in Edge Function environment variables — never shipped to the Flutter client, never committed to the repo (see Rules.md §Security Rules).
- **Threat model basics (MVP scope):** primary threats are (1) unauthorized room access via code guessing — mitigated by code entropy + rate limiting; (2) privilege escalation via a compromised low-trust role — mitigated by RLS being the sole enforcement point, tested explicitly (see Rules.md §Testing Rules); (3) AI prompt injection via malicious evidence content — mitigated by treating all AI output as an unprivileged suggestion requiring human sign-off, never auto-applied.

---

## 10. Deployment & Infrastructure

- **Environments:** `dev` (local Supabase + local Flutter run), `staging` (Supabase staging project + Vercel preview deploy per PR), `prod` (Supabase prod project + Vercel production deploy on merge to `main`).
- **CI/CD (GitHub Actions):** on every PR — lint (`dart analyze`), run unit/widget tests, run Supabase migration dry-run; on merge to `main` — deploy web build to Vercel, apply Postgres migrations to the Supabase prod project via the Supabase CLI.
- **Mobile builds:** Android/iOS builds triggered manually or on release tags in Phase 4, ahead of store submission.
- **Configuration:** environment-specific config (Supabase URL/anon key, feature flags) injected via environment variables at build time — never hardcoded (see Rules.md §Security Rules).

---

## 11. Error Handling & Resilience

- **Client-side:** network failures during writes are queued locally and retried with exponential backoff; user sees a non-blocking sync indicator (per PRD §6.7).
- **Edge Functions:** all external calls (AI providers, export rendering) wrapped with timeouts and a single retry on transient failure; on exhausted retries, the function returns a typed error the client can render meaningfully (not a raw stack trace).
- **AI provider degradation:** if the configured LLM provider is unavailable/rate-limited, the AI Adapter Layer should — where configured — fall back to a secondary provider, or clearly surface "AI unavailable" without blocking any core (non-AI) room functionality.
- **Logging/monitoring:** structured logs from Edge Functions (see Rules.md §Logging Rules) shipped to Supabase's log explorer in MVP; a dedicated observability tool (e.g., Sentry) is a Phase 2 addition once pilot usage justifies the cost.

---

## 12. Testing Strategy

| Level | Scope | Tooling |
|---|---|---|
| Unit | Business logic (permission matrix evaluation, code generation, data transforms) | `flutter test` (Dart), Edge Function unit tests |
| Widget/component | Flutter UI components in isolation | `flutter_test` |
| Integration | Client ↔ Supabase interactions against a local/staging Supabase instance | `flutter test` (integration profile) + Supabase local dev stack |
| E2E | Full user flows: create room → join → upload → AI suggestion → export | Patrol or `integration_test` package across a real device/emulator |
| RLS/contract tests | Every RLS policy has an explicit "this role can" / "this role cannot" test | SQL test suite (pgTAP or equivalent) run in CI against Supabase local — and locally via Docker Desktop (`npx supabase db reset` + `npx supabase test db`) before any push |
| AI adapter tests | Contract tests per provider (request/response shape), mocked provider responses | Unit tests with fixture responses, no live API calls in CI |

RLS/contract tests are treated as **non-negotiable** given the product's confidentiality promise — see Rules.md §Testing Rules for required coverage.

---

## 13. Technical Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Supabase is a single point of failure (auth, db, storage, realtime all on one vendor) | Full outage if Supabase is down | Accepted for MVP given team size/timeline; document as an explicit assumption (PRD §9); revisit multi-region/backup strategy in Phase 2+ |
| Entity-relationship graph queries become slow at scale on plain Postgres | Poor UX on the relationship map for large cases | Start with recursive CTEs; evaluate Apache AGE or a dedicated graph DB only once real query patterns/volume justify it |
| Multi-provider AI adapter adds complexity vs. a single vendor | Slower Phase 3 delivery, more edge cases in error handling | Ship with one provider wired end-to-end first (config-driven), add the others incrementally behind the same interface |
| Flutter web performance on low-end/older browsers | Poor first impression for non-technical users | Validate early in Phase 1 with real-device testing; keep initial bundle lean (see Rules.md §Performance Rules) |
| RLS policy bugs silently over- or under-restrict access | Confidentiality breach or broken UX | Mandatory RLS contract tests in CI (§12); code review checklist requires explicit RLS review on any schema change (Rules.md §Code Review Checklist) |

---

## 14. Migration Path / Backward Compatibility

CaseThread is greenfield — no existing system to migrate from. Forward-compatibility principles to preserve optionality:
- Schema changes are additive by default (new columns/tables, not destructive renames) so that rolling deploys don't break in-flight clients.
- The AI Adapter Layer's provider-agnostic interface is designed explicitly so that no core logic depends on a single LLM vendor's API shape — swapping/adding a provider should never require touching room/permission/audit logic.
- Domain modules are config, not code, specifically so new case types (insurance fraud, incident response, etc.) never require a schema migration for the core tables — only new rows in the case-type/role-definition config tables.
