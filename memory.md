# CaseThread — Project Memory

**Last updated:** 2026-09-11 (Sprint 3 complete, merged to main)
**Update this file at the end of every work session — it's the fastest way for anyone (including a resuming AI assistant) to get back up to speed.**

---

## 1. Current Project State Summary

**Sprints 0–6 complete and merged to `main` (6680137).** The full Phase 1 core works end-to-end: auth → create room (server-generated, rotatable code) → join by code (rate-limited, owner-approved) → role-scoped access → evidence vault (sha256, auto-versioning, dual-layer permission denials) → timeline/discussion/tasks with realtime + @mentions → immutable audit trail. 75/75 pgTAP RLS contract tests + 59/59 Dart tests, analyze 0, CI green — locally (Docker loop) and in CI. Sprint 6 proved the one-core-many-configs architecture: the Academic case flow runs on pure config data with ZERO migrations; role-scoped UI gating now hides what the DB would refuse (vault/discussion/tasks). **Standing infrastructure:** Docker Desktop; local stack DB on port **65432** (Hyper-V reserves 54262–54361 — never 543xx defaults); `npx supabase start --exclude studio,imgproxy,edge-runtime,logflare,vector,realtime,storage-api` → `db reset` → `test db`. **Next:** Sprint 7 (final Phase-1 sprint): error-handling audit, seed/demo data, demo-day rehearsal (create → join → upload → populated audit log) on Chrome + Android, Phase-1 retro, Phase-2 Go/No-Go.

---

## 2. Recently Completed Tasks

| Date | Task | Note |
|---|---|---|
| 2026-09-10 | Refined product concept finalized | Original "investigator's app" reframed as a universal Case Room platform (see original concept doc) |
| 2026-09-10 | PRD.md drafted | Personas, KPIs, prioritized user stories, functional/non-functional requirements defined |
| 2026-09-10 | Architecture.md drafted | Flutter + Supabase + provider-agnostic AI adapter architecture locked in |
| 2026-09-10 | Rules.md, Phases.md, Design.md drafted | Coding standards, phased roadmap (6–12mo), navy/slate/teal design system all defined |
| 2026-09-10 | ExecutionPlan.md drafted | Operational companion to Phases.md: Phase 0 exit checklist, 2-week sprint process (both-platform DoD rule), Sprint 0–7 detail for Phase 1, sprint-level Phase 2–3, gate summary, risk register |
| 2026-09-10 | Sprint 0 scaffold built | Feature-based `lib/` structure, Design.md tokens (`lib/core/theme/`), typed errors (`lib/core/errors/`), env config (`lib/core/config/`), fonts (Inter + JetBrains Mono, OFL bundled), CI (`.github/workflows/ci.yml`), pinned deps in pubspec |
| 2026-09-10 | Sprint 1 auth built | `features/auth/` domain/data/presentation, Supabase sign-up/in/out, setup screen for unconfigured state, rooms placeholder, router guards; 20 tests green |
| 2026-09-11 | Sprint 2 schema + harness built | Migrations 0002–0006 (core tables, audit immutability, Legal+Academic seeds, RLS policies, rate limiting), pgTAP suite in `supabase/tests/db/`, CI `rls-tests` gate, typed Dart models + CaseTypeRepository, profile fetch wiring; 29 tests green; branch `feature/sprint-2-schema` pushed (bb8ae90) |
| 2026-09-11 | Sprint 3 rooms + join flow complete, merged to main | Migrations 0007–0008 (room-service RPCs, append_audit, owner-default roles, co-member profiles policy, member FK), rooms UI (list/create/join/detail), router routes; live E2E verified; 3 SQL runtime bugs fixed via E2E (pgcrypto schema-qual, OUT-param name collision, missing FK) |
| 2026-09-11 | RLS suite green: 47/47 | Docker Desktop installed → local `db reset`+`test db` loop (2s iterations) unblocked everything after ~7 blind CI attempts. Real policy hole found+fixed (owner vs membership). pgTAP 3.36 semantics documented in §8. Squash-merged to main e2a3649, CI green |
| 2026-09-12 | Sprint 4 evidence vault complete, merged to main | Migration 0009 (bucket + storage RLS + register_evidence RPC; direct INSERT removed), vault UI with tabs/upload/progress; 75/75 pgTAP (7 mirror + 10 academic-config tests); 55/59 Dart (13 content + 4 permission contracts). The rls suite covers: profiles, audit immutability, room/join lifecycle, permission-gated writes across all content tables, all 0007 RPCs, and the vault.
| 2026-09-12 | Sprint 5 timeline/discussion/tasks complete, merged to main | 0010 (mirror + audits) + 0011 (embed FKs) live-verified; 5-tab UI with realtime; 65/65 pgTAP + 55/55 Dart; CI green |
| 2026-09-12 | Sprint 6 config validation + UI gating complete, merged to main | Academic flow zero-migration proof; RoomPermissions; gated vault/discussion/tasks; 75/75 pgTAP + 59/59 Dart; CI green |

---

## 11. Deployment Log

| Timestamp | Environment | Version | Notes |
|---|---|---|---|
| 2026-09-10 | GitHub (private repo) | bb8ae90 base | Sprint 0–1 pushed by user; CI active |
| 2026-09-11 | GitHub `feature/sprint-2-schema` | bb8ae90 → caf6919 | Sprint 2 commits + 0002 fix; CI `rls-tests` first run (result unconfirmed — check Actions) |
| 2026-09-11 | Supabase dev cloud `hxrztoakimebjcibvkaa` | migrations 0001–0006 | Applied via `npx supabase db push --include-all` after expression-index fix; 14 tables, RLS armed, seeds present; GoTrue v2.196.0 |
| 2026-09-11 | Supabase dev cloud | 0007 + 0008 + policy hotfixes | Room-service RPCs applied; request_room_join recreated (OUT-param rename); owner-visibility policy on room_members + case_rooms patched directly (recorded-migration hotfixes — fresh envs get them via the migration files) |
| 2026-09-11 | GitHub `main` | e2a3649 | Sprint 2+3 squash-merged; CI green on both jobs (flutter + rls-tests) |
| 2026-09-11 | Local (Docker) | stack running | DB port 65432; 47/47 pgTAP locally; standing infra for future sprints |
| 2026-09-12 | Supabase dev cloud | 0009 applied | Evidence bucket + storage RLS + register_evidence live; vault E2E verified |
| 2026-09-12 | GitHub `main` | 3699093 | Sprint 4 squash-merged; CI green on both jobs |
| 2026-09-12 | Supabase dev cloud | 0010 + 0011 | Mirror + embed FKs live; task→timeline E2E verified |
| 2026-09-12 | GitHub `main` | 0bfbf4d | Sprint 5 squash-merged; CI green |
| 2026-09-12 | GitHub `main` | eba905b → 6680137 | Sprint 6 squash-merged + docs; CI green |
