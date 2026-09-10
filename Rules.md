# CaseThread — Rules

**Status:** Draft v1.0
**Last updated:** 2026-09-10
**Related docs:** [PRD.md](./PRD.md) · [Architecture.md](./Architecture.md) · [Phases.md](./Phases.md)

This document is binding for all contributors — human and AI-assisted. When in doubt, prefer the stricter interpretation.

---

## 1. Coding Standards

- **Language:** Dart (Flutter) for client code; SQL/PLpgSQL for Postgres/Supabase; TypeScript for Edge Functions.
- **Formatting:** `dart format` enforced pre-commit (no manual formatting debates); default line length 80 unless a wider limit is explicitly configured project-wide.
- **Linting:** `flutter analyze` must pass with zero warnings before a PR is opened; use the `flutter_lints` recommended set as the baseline, extended with project-specific rules as they're identified.
- **Naming conventions:** `UpperCamelCase` for classes/widgets, `lowerCamelCase` for variables/functions, `snake_case` for Postgres tables/columns and file names.
- **Function/widget length:** prefer functions under ~40 lines and widgets under ~150 lines; if a `build()` method is growing past that, extract sub-widgets.
- **File organization:** one public widget/class per file where practical; group by feature (`features/case_room/...`), not by type (`widgets/`, `models/` sprawled flat).

---

## 2. Commit & Branching Convention

- **Branching:** `main` is always deployable. Feature branches: `feature/<short-description>`, fixes: `fix/<short-description>`, chores: `chore/<short-description>`.
- **Commit format:** [Conventional Commits](https://www.conventionalcommits.org/) — `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`. Example: `feat(rooms): add code rotation endpoint`.
- **PRs:** must reference the relevant Phase/epic (see Phases.md); no direct pushes to `main`.
- **Merge strategy:** squash-merge to keep `main` history readable; PR title becomes the squash commit message (must itself follow Conventional Commits format).

---

## 3. Documentation Standards

- **Inline comments:** explain *why*, not *what* — the code should read clearly enough that "what" is self-evident. Comment non-obvious business rules (e.g., "why this role can't see this field") and any workaround for a known limitation.
- **DartDoc:** required on all public classes/methods in shared/core packages (anything outside a single feature's private implementation). Not required on private widgets/helpers unless the logic is non-obvious.
- **External docs:** architectural decisions that affect more than one feature belong in Architecture.md, not scattered in code comments — link to the relevant section from the code where useful.

---

## 4. Dependency Management

- New packages require a one-line justification in the PR description: what it does, why an existing dependency or a small in-house utility isn't sufficient.
- **No frivolous micro-dependencies** (left-pad-style) — if it's under ~30 lines of logic, write it in-house.
- Pin exact versions in `pubspec.yaml` / `package.json` (no unbounded `^` ranges for anything touching auth, crypto, or the Supabase client) to avoid silent breaking upgrades.
- License check required before adding any new dependency — GPL/AGPL-licensed packages are disallowed given the proprietary, all-rights-reserved nature of this repo (see Phases.md §License).

---

## 5. Error Handling Patterns

- **Typed errors, always.** No bare `throw Exception('something broke')` — define domain-specific error types (`RoomNotFoundError`, `PermissionDeniedError`, `CodeExpiredError`, etc.) so the UI layer can react meaningfully.
- **Never throw across the Edge Function → client boundary** — Edge Functions catch all internal errors and return a structured error response (`{ code, message }`); the client never has to parse a stack trace.
- **UI error boundaries:** every screen that fetches remote data wraps it in an error boundary showing a specific, human-readable message (see PRD §6.7) — never a blank screen or a raw exception string.
- **Logging format:** structured JSON logs with a `trace_id` correlating client action → Edge Function → database call, so a single user-reported issue can be traced end-to-end.

---

## 6. Logging & Observability Rules

- **What to log:** action type, actor (user id, not name/email), room id, timestamp, outcome (success/failure), trace id.
- **What never to log:** raw evidence content, full document text, access codes (plaintext or hash), passwords/tokens, or any field marked privileged/redacted in the permission matrix.
- **Levels:** `error` (needs attention), `warn` (degraded but functioning, e.g., AI provider fallback triggered), `info` (normal state-changing actions), `debug` (dev-only, stripped from prod builds).
- **PII prohibition:** logs must not contain personally identifying information beyond internal user IDs — this is a hard rule given the legal/medical-adjacent data this product handles.

---

## 7. Testing Rules

- **Required coverage:** any code touching permissions, room access, or the audit log requires an explicit test proving both the "allowed" and "denied" case — no permission-related PR merges without this.
- **RLS policies:** every new or modified RLS policy requires a corresponding test in the SQL test suite (see Architecture.md §12) before merge — this is non-negotiable given the product's confidentiality promise.
- **Test file naming:** mirror the source file with a `_test` suffix (`room_service.dart` → `room_service_test.dart`).
- **Mocking policy:** mock only external I/O (network calls, LLM provider APIs, file storage) — never mock the business logic under test itself. AI provider calls are always mocked/fixture-based in CI; no live API calls in automated tests.

---

## 8. Accessibility Rules

- Semantic widget structure — use Flutter's `Semantics` widget and built-in accessible components rather than reinventing controls with raw `GestureDetector`s.
- Minimum contrast ratio 4.5:1 for normal text, 3:1 for large text (WCAG AA), per Design.md's defined palette.
- All interactive elements must be reachable and operable via keyboard (web) and screen reader (all platforms) — no mouse/touch-only interactions.
- Minimum touch target size 44x44 logical pixels (see Design.md §Accessibility Design).
- Every form input has an associated, programmatically-linked label — no placeholder-text-only labeling.

---

## 9. Performance Rules

- **Web bundle size:** track and budget the initial Flutter web bundle; flag any single PR that grows it by more than ~10% without justification.
- **Lazy loading:** route-level code splitting for anything not needed on first paint (e.g., the AI workflow panel, export flow).
- **Images:** compress/resize on upload where feasible; never render a full-resolution original in a thumbnail context.
- **List rendering:** use lazy/virtualized list widgets (`ListView.builder`, not `ListView` with a fully-materialized children list) for timelines, audit logs, and evidence vaults, which can grow large.

---

## 10. Security Rules

- **Never commit secrets.** API keys (Supabase service role, LLM provider keys) live only in environment variables / the CI secret store — never in code, never in a committed `.env` file (a `.env.example` with placeholder values is fine).
- **Environment variables:** all environment-specific config is injected at build/deploy time (see Architecture.md §Deployment); no hardcoded URLs or keys per environment scattered in source.
- **CORS:** Supabase project CORS settings restricted to known deployed origins (Vercel prod/staging URLs, local dev origin) — never wildcard `*` in production.
- **API key rotation:** LLM provider and Supabase service-role keys rotated on any suspected compromise and on a routine schedule (define exact cadence once Phase 2 ops practices are set — tracked as an open item).
- **Client trust boundary:** the Flutter client is never trusted with anything requiring server-side authority (permission decisions, audit writes, code generation) — these always go through RLS-protected queries or Edge Functions.

---

## 11. AI Assistance Boundaries

These rules apply both to CaseThread's own in-product AI agents (contradiction checker, etc.) and to AI coding assistants (e.g., Claude Code) used by the team to build CaseThread itself.

**For in-product AI agents:**
- An agent may propose a finding; it may never write directly to `timeline_events`, `audit_log`, or any case-record table — only to `ai_suggestions`, which requires human review to promote.
- An agent must never be given write access to room membership, roles, or access codes.
- Agent prompts/config are versioned and reviewed like code — no silent prompt changes in production.

**For AI coding assistants working on this codebase:**
- May suggest code changes, write tests, and draft documentation.
- **Must not** modify production configuration files (environment configs, Supabase migration files targeting `prod`, CI/CD deploy configs) without explicit human review and approval — draft only.
- **Must not** invent API endpoints, database columns, or third-party integrations that don't exist in Architecture.md — if something is missing, flag it as an open question rather than fabricating it.
- **Must always** include error handling consistent with §5 above — no happy-path-only code suggestions for anything touching permissions, payments (future), or data writes.
- **Must not** weaken or remove an RLS policy, permission check, or audit log write without an explicit human-reviewed justification in the PR description.

---

## 12. Code Review Checklist

Every reviewer must verify, before approving:

- [ ] Does this PR touch permissions/RLS? If so, are both allow and deny cases tested?
- [ ] Are there tests at all, and do they follow the naming convention (§7)?
- [ ] Does any new/changed audit log write remain append-only (no UPDATE/DELETE path introduced)?
- [ ] Are errors typed and handled per §5 — no bare exceptions surfacing to the client?
- [ ] Any new dependency justified per §4 (license, necessity)?
- [ ] Any secret, key, or environment-specific value accidentally hardcoded?
- [ ] Does the UI change meet the accessibility rules in §8 (contrast, labeling, touch targets)?
- [ ] Does the code follow the naming/formatting standards in §1 (or does CI lint/format check pass)?
- [ ] If this PR touches an AI agent, does its output still land only in `ai_suggestions`, never directly in case-record tables?

---

## 13. Environment-Specific Behaviour

- **Feature flags:** new/risky features ship behind a flag (simple config table or environment variable in MVP; a dedicated flagging service is a later-phase addition if needed) so they can be enabled per-environment without a redeploy.
- **Debug mode:** verbose/debug logging only compiles into `dev`/`staging` builds; stripped from `prod` builds entirely (see §6).
- **Mock data:** a seed script provides realistic mock case rooms/data for local development and demo environments — mock data must never be reachable from a production build/environment.
