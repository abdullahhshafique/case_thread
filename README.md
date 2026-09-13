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
| Case timeline & entity map | No | Partial | **Yes (timeline now, entity map Phase 2)** |
| AI assistance | No | No | **Human-in-the-loop agents (Phase 3)** |
| Cost/complexity | Low | High | **Low (Supabase-backed, single Flutter codebase)** |

## Tech Stack

![Flutter](https://img.shields.io/badge/Flutter-3.47-0D1526?style=flat-square&logo=flutter)
![Supabase](https://img.shields.io/badge/Supabase-Postgres%20%2B%20RLS-0D1526?style=flat-square&logo=supabase)
![Vercel](https://img.shields.io/badge/Deploy-Vercel-0D1526?style=flat-square&logo=vercel)
![Riverpod](https://img.shields.io/badge/State-Riverpod-0D1526?style=flat-square)

- **Flutter** — one codebase → Web, Android, iOS
- **Supabase** — Postgres with Row-Level Security as the real permission boundary, Auth, Storage, Realtime
- **Riverpod** — testable, compile-safe state management
- **Provider-agnostic AI adapter layer** (Phase 3) — Claude, GPT, Gemini, or Grok behind one interface, always human-in-the-loop
- **GitHub Actions + Vercel** — CI on every PR, preview deploys

## Status

**Phases 1–2 COMPLETE.** All five case-type domains (Legal, Academic, Corporate, Technical, Medical) run on one config-driven core; field-level redaction enforced in the database; watermark-based activity feed; permission-gated case export; entity-relationship map with transitive chains. The full MVP works end-to-end against the live backend: sign up → create room → join by code → owner approval → role-scoped access → evidence vault → realtime timeline/discussion/tasks → immutable audit trail. Demo-day flow rehearsed live. The core Case Room loop + evidence vault work end-to-end against the live backend: sign up → create room (server-generated, rotatable access code) → join by code (rate-limited, owner-approved) → role-scoped access → evidence upload (sha256 chain-of-custody, duplicate-name auto-versioning, permission-gated at both RPC and storage layers) → immutable audit trail. Full schema with Row-Level Security on every table (enforced in Postgres, not the UI), Legal/Investigative + Academic case types as config data, rooms UI with Vault/Timeline/Discussion/Tasks/Members tabs (realtime updates, @mentions), auto-generated case timeline from system events, role-scoped UI that hides what the database would refuse. 98 RLS contract tests (pgTAP) + 59 Dart tests green in CI. See [Phases.md](./Phases.md) for the roadmap and [ExecutionPlan.md](./ExecutionPlan.md) for the sprint-by-sprint plan.

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

### Database tests (RLS contract suite)

The pgTAP suite in `supabase/tests/db/` is the non-negotiable security gate (Rules.md §7). It runs in CI on every push, and locally with Docker:

```bash
# One-time: install Docker Desktop, then from the project root
npx supabase start --exclude studio,imgproxy,edge-runtime,logflare,vector,realtime,storage-api
npx supabase db reset   # applies all migrations in order to local Postgres
npx supabase test db    # runs the pgTAP suite with full pg_prove output
```

Local Postgres listens on port **65432** (not the CLI default 54322 — this machine's Hyper-V reserves 54262–54361). `supabase stop` shuts the stack down when done.

> History: this suite was developed against a blind 4-minute CI loop, which caught nothing until Docker enabled the exact same `db reset + test db` loop locally. Prefer the local loop for RLS work; CI is the confirmation gate, not the debugger.

## Documentation

- [PRD.md](./PRD.md) — problem, personas, KPIs, requirements
- [Architecture.md](./Architecture.md) — tech stack, data model, security model
- [Phases.md](./Phases.md) — phased roadmap (Phase 1–4)
- [ExecutionPlan.md](./ExecutionPlan.md) — sprint-by-sprint execution plan
- [Design.md](./Design.md) — design system (tokens, typography, components)
- [Rules.md](./Rules.md) — binding coding/security/testing standards
- [memory.md](./memory.md) — living project state summary

## License

All rights reserved. This code is publicly visible for portfolio/demonstration purposes; no license is granted for reuse, modification, or redistribution without permission.
