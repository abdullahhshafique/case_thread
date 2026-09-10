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

**Sprint 0–1 complete (Phase 1 in progress).** Feature-based app scaffold with the full Design.md token system (dark navy/slate/teal), Supabase auth (sign-in/sign-up), routing guards, setup flow for unconfigured environments, and a 20-test suite running in CI. See [Phases.md](./Phases.md) for the roadmap and [ExecutionPlan.md](./ExecutionPlan.md) for the sprint-by-sprint plan.

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
