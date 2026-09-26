# CaseThread

**A case-room platform where any team — legal, academic, corporate, medical, or technical — can spin up a private, secure workspace in minutes and manage an entire case in one place.**

## The Problem

Any group collaborating around a structured problem — an investigation, a legal matter, a misconduct hearing — hits the same three failures: **evidence scattered** across email and drives, **access control** that's either too loose or requires an IT ticket, and **no visible connections** between who said what and what contradicts what. Existing tools (Kaseware, goCASE, Cellebrite) serve large agencies with procurement cycles — nobody serves a legal team, an integrity board, and a fraud unit with the same lightweight tool.

CaseThread's answer: **Case Rooms** with code-based access, role-based permissions enforced in the database, and pluggable domain modules on one shared core — evidence vault, case timeline, threaded discussion, tasks, and an immutable audit log.

## How CaseThread Compares

| | Shared folders (Drive/Dropbox) | Enterprise case tools (Kaseware/goCASE) | **CaseThread** |
|---|---|---|---|
| Time to start | Instant | Days–weeks (IT provisioning) | **Minutes (join code)** |
| Role-based access | Manual folder permissions | Yes, admin-managed | **Yes, enforced via Postgres RLS** |
| Immutable audit trail | No | Yes | **Yes, append-only at the DB layer** |
| Case timeline & entity map | No | Partial | **Yes (timeline + recursive-CTE entity map)** |
| AI assistance | No | No | **Yes — human-in-the-loop agents (live)** |
| Cost/complexity | Low | High | **Low (Supabase-backed, single Flutter codebase)** |

## Tech Stack

![Flutter](https://img.shields.io/badge/Flutter-3.47-0D1526?style=flat-square&logo=flutter)
![Supabase](https://img.shields.io/badge/Supabase-Postgres%20%2B%20RLS-0D1526?style=flat-square&logo=supabase)
![Vercel](https://img.shields.io/badge/Deploy-Vercel-0D1526?style=flat-square&logo=vercel)
![Riverpod](https://img.shields.io/badge/State-Riverpod-0D1526?style=flat-square)

- **Flutter** — one codebase → Web, Android, iOS
- **Supabase** — Postgres with Row-Level Security as the real permission boundary, Auth, Storage, Realtime
- **Riverpod** — testable, compile-safe state management
- **AI adapter layer** (Edge Function) — Claude, GPT, Gemini, or Grok behind one interface; swapping providers is a config flip (`AI_PROVIDER`), never a core-logic change
- **pdf + printing** — client-side PDF case-report generation and OS save/share (download on web)
- **GitHub Actions + Vercel** — CI on every PR, preview deploys

## AI Agent Workflows (live)

![Human-in-the-loop AI workflow](./docs/assets/workflow-pipeline.svg)

Agents analyze a room's timeline and evidence, then flag findings as **pending suggestions** — visually distinct (amber) from confirmed case data. Nothing an agent produces can touch the case record: only a Lead-tier human can **accept**, **edit**, or **dismiss** a finding, and every decision lands in the immutable audit trail atomically with the resulting timeline event. Domain agents ship as versioned config data (not code): Contradiction Checker (legal), Financial Anomaly Detector (corporate), Root-Cause Suggester (technical), Literature Summarizer (academic), Diagnostic Differential Assistant (medical), Case Completeness Reviewer (cross-domain). The workflow builder chains agents into saved pipelines — every step still produces its own pending suggestion for individual review. Since the UX Parity update, agents can also be run **scoped to a single evidence item** from the evidence detail sheet.

## Feature Highlights (complete as of 2026-09-24)

**Core platform (Phases 1–4)**
- Auth, Case Rooms with server-hashed access codes, join-by-code with role picking, owner approval, code rotation
- Evidence vault with sha256 chain-of-custody hashing, auto-versioning, Fact/Claim/Finding/Unknown classification
- Realtime timeline (manual + system + AI events), threaded discussion with @mentions, tasks
- Immutable append-only audit log; watermark-based activity feed with notifications sheet
- Five case-type domains (Legal, Academic, Corporate, Technical, Medical) as pure config rows — zero core-schema deviation
- Field-level redaction via security-barrier views; export with privileged-field scoping
- Entity-relationship map (recursive CTE) with the animated v3 Connections graph
- Template marketplace (draft → publish → materialize), cross-case RLS-scoped search, offline-first sync with LWW conflict flags, version history over the audit log

**Investigation intelligence (Phase 5)**
- Alibi verification (with evidence links), contradiction tracking, investigation gaps (gap → task)
- Live case dashboard: 6 stat tiles, evidence-by-type + 14-day event charts, classification coverage meter
- Investigation status lifecycle (open → under_investigation → review → closed) with auto-generated closed summary
- AI consent disclosure before every agent run

**v3 Investigation Console + UX Parity (Phases 6–7, client-requested)**
- Geist typography, topbar/rail/cases shell, mobile bottom nav, notifications sheet, invite copy-link, chat bubbles, vault search + type chips, timeline restyle
- **Light theme** with WCAG-AA-checked palette, system-follow + manual override, persisted across restarts
- **Debug tools** (debug builds): one-tap demo sign-in and a role-permission override pill for instant role testing
- **Overview enrichment**: shared case-briefing card (with editor for edit_case holders), three attention alert cards (contradictions / gaps / alibis) that deep-link into the Analysis sub-tabs, and a verified-alibi donut ring
- **Export overhaul**: bottom sheet with formatted **PDF report** (save/share/print; download on web) plus Markdown-to-clipboard — same compiled, RLS-scoped report document
- **Evidence detail sheet**: full chain-of-custody metadata, per-item AI analysis, and **Verify-Alibi** flow that attaches the evidence id to the verification record (required status reason, audit-logged)
- **Discussion enhancements**: star + pin messages (persisted per user per room, pinned strip above the thread) and **Extract-to-case** (writes a real timeline event classified `claim`)
- **Demo seeding**: idempotent `supabase/seed_demo.sql` seeds the full Riverside Robbery #2291 case (briefing, evidence, tasks, contradiction, alibis, gaps, timeline) — access code `DEMO1234`
- **Presence & role dots**: role-colored avatar dots everywhere (lead = blue, analyst = violet, forensic = cyan…), and per-member "Active 5m ago" watermarks in the Members pane

## Status

**All planned phases + the UX Parity PRD (phases 1–7) are COMPLETE (2026-09-24).** 43 migrations, RLS on every table, 27 pgTAP test files (232 declared tests) + 28 Dart test files + 9 Deno provider contract tests. The v3 Investigation Console is merged to `main` (tagged `v0.1.0`); the UX Parity work (light theme, debug tools, briefing card/editor, alert cards + donut, PDF export sheet, evidence detail AI + verify-alibi, discussion pin/star/extract, demo seed, presence dots) is code-complete in the working tree — run the local gates (`flutter analyze`, `flutter test`) and apply migrations 0042–0043 + `seed_demo.sql` to your database before demoing. See [Phases.md](./Phases.md) for the roadmap, [HANDOFF.md](./HANDOFF.md) for exact current state, and [ExecutionPlan.md](./ExecutionPlan.md) for the sprint-by-sprint plan.

## Local Development

Prerequisites: Flutter 3.47.x ([install](https://docs.flutter.dev/get-started/install)), a [Supabase](https://supabase.com) project (free tier works).

```bash
flutter pub get

# Configure (non-web): copy .env.example → .env, fill in your values
# from Supabase Dashboard → Project Settings → API
cp .env.example .env

# Run on Android emulator / desktop
flutter run

# Run on web (config via dart-define — web can't read .env)
flutter run -d chrome \
  --dart-define=SUPABASE_URL=YOUR_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_KEY
```

Quality gates before any PR (Rules.md):

```bash
dart format .
flutter analyze   # zero warnings required
flutter test
```

### Database setup & tests (RLS contract suite)

The pgTAP suite in `supabase/tests/db/` is the non-negotiable security gate (Rules.md §7). It runs in CI on every push, and locally with Docker:

```bash
# One-time: install Docker Desktop, then from the project root
npx supabase start --exclude studio,imgproxy,edge-runtime,logflare,vector,realtime,storage-api
npx supabase db reset   # applies all migrations in order to local Postgres
npx supabase test db    # runs the pgTAP suite with full pg_prove output
```

Local Postgres listens on port **65432** (not the CLI default 54322 — this machine's Hyper-V reserves 54262–54361). `supabase stop` shuts the stack down when done.

**Demo data:** apply migrations `0042_room_briefing.sql` + `0043_presence_watermarks.sql`, then run `supabase/seed_demo.sql` in the Supabase SQL editor (replace the `demo_user_id` in its `config` CTE with your user's `auth.users` id). Join the demo room with code `DEMO1234`.

### AI adapter contract tests (Edge Function)

The provider adapter (mock / grok / openai / anthropic / gemini) is contract-tested with stubbed `fetch` — no live vendor calls, no keys:

```bash
deno test --no-check --allow-env supabase/functions/ai-agent/index.test.ts
```

## Documentation

- [PRD.md](./PRD.md) — problem, personas, KPIs, requirements
- [Architecture.md](./Architecture.md) — tech stack, data model, security model, UX Parity as-built notes
- [Phases.md](./Phases.md) — phased roadmap (Phases 0–6 + UX Parity 1–7)
- [ExecutionPlan.md](./ExecutionPlan.md) — sprint-by-sprint execution plan
- [Design.md](./Design.md) — design system (tokens, typography, components, light theme)
- [Rules.md](./Rules.md) — binding coding/security/testing standards
- [HANDOFF.md](./HANDOFF.md) — exact current state for the next developer
- [CASETHREAD_DEMO_GUIDE.md](./CASETHREAD_DEMO_GUIDE.md) — full setup + demo walkthrough
- [DEMO_CASE_STUDY.md](./DEMO_CASE_STUDY.md) — team case study (Meridian Bank Insider Fraud #3310): four role accounts, room code, seeded case, 20-minute demo script
- [memory.md](./memory.md) — living project state summary

## License

All rights reserved. This code is publicly visible for portfolio/demonstration purposes; no license is granted for reuse, modification, or redistribution without permission.
