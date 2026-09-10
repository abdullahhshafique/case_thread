# CaseThread — Phases

**Status:** Draft v1.0
**Last updated:** 2026-09-10
**Timeline basis:** Larger team, standard 6–12 month startup timeline
**Related docs:** [PRD.md](./PRD.md) · [Architecture.md](./Architecture.md) · [Rules.md](./Rules.md) · [memory.md](./memory.md)

---

## 1. Phase Overview

| Phase | Objective | Target window |
|---|---|---|
| Phase 0 | Planning & foundation (this document set, environment setup) | Weeks 1–2 |
| Phase 1 | Core platform — Case Rooms, access codes, roles, shared core, 2 case-type modules | Months 1–3 |
| Phase 2 | Full template library + redaction + notifications + export | Months 3–5 |
| Phase 3 | AI agent workflows | Months 5–7 |
| Phase 4 | SaaS polish — marketplace, cross-case search, offline mode, mobile store release | Months 7–12 |

---

## 2. Phase 1 — Core Platform

**Goal:** "Create a room, generate a code, invite a teammate, upload evidence, see it in an audit trail" works end-to-end, for Legal/Investigative and Academic case types, on Web + mobile.

**Epic breakdown:**

| Epic | Priority | Notes |
|---|---|---|
| Auth (sign up/in, session mgmt) | P0 | Supabase Auth, email/password |
| Case Room creation + case-type selection | P0 | Legal/Investigative + Academic only |
| Access code generation, rotation, join flow | P0 | Includes rate limiting (Architecture.md §9) |
| Role definitions + RLS permission enforcement | P0 | Full permission matrix per PRD open question |
| Shared core: dashboard, timeline, vault, discussion, tasks, audit log | P0 | |
| Flutter Web + mobile shell (nav, theming per Design.md) | P0 | |
| CI/CD pipeline (GitHub Actions + Vercel) | P0 | |
| RLS contract test suite | P0 | Non-negotiable per Rules.md §7 |

**Definition of Done for Phase 1:**
- All P0 items above shipped and demoable.
- RLS contract tests pass in CI for every defined role in both case types.
- Design/UX review approved against Design.md.
- Architecture review confirms no P0 item required deviating from Architecture.md without a documented decision.
- Demo Day flow (see §7 below) runs end-to-end without manual database intervention.

**Dependencies:** Supabase project provisioned; Design.md finalized before UI build starts; case-type/role matrix (PRD open question) resolved before RLS policies are written.

**Phase-specific risks:** RLS policy complexity underestimated → mitigate with the contract-test-first approach in Rules.md §7; Flutter web performance unknowns → validate early with real devices (Architecture.md §13).

**Resources:** Backend/DB engineer(s) for Supabase schema + RLS; Flutter engineer(s) for client; 1 designer for Design.md execution; 1 PM/product owner.

**Deliverables:** Deployable web build on Vercel staging, mobile build runnable on emulator/device, RLS test suite in CI, updated memory.md.

**Go/No-Go for Phase 2:** Core flows demo cleanly to an outside observer; no known P0 security gap in RLS coverage.

---

## 3. Phase 2 — Full Template Library

**Goal:** Roll out the remaining domain modules (Corporate & Business, Medical & Healthcare, Technical & Engineering) as configs on the existing core; add field-level redaction, notifications, and report export.

**Epic breakdown:**

| Epic | Priority |
|---|---|
| Remaining case-type configs (Corporate, Medical, Technical) | P0 |
| Field-level redaction (per PRD §6.3 edge cases) | P1 |
| Notification/activity feed | P1 |
| PDF/Word export | P1 |
| Entity-relationship map (initial version, recursive-CTE-based) | P1 |

**Definition of Done:** All five case-type categories from the original concept selectable at room creation; redaction verified via RLS contract tests; export produces a correctly-scoped (no privileged-field leakage) PDF/Word file.

**Dependencies on Phase 1:** Shared core and RLS pattern from Phase 1 must be stable — new case types must not require core schema changes (validates the "config not rebuild" architecture principle).

**Risks:** Medical module may surface HIPAA-adjacent handling questions not yet resolved — flag to Product + Legal SME per PRD §10 open questions before building Medical-specific fields.

**Resources:** Same core team; may need a domain SME consult (legal/medical) for realistic field definitions.

**Deliverables:** Updated case-type config library, export service, notification feed, updated memory.md.

**Go/No-Go for Phase 3:** All case types functional; export and redaction pass security review.

---

## 4. Phase 3 — AI Agent Workflows

**Goal:** Ship the workflow builder and the first set of domain-tuned agents, fully human-in-the-loop.

**Epic breakdown:**

| Epic | Priority |
|---|---|
| AI Adapter Layer (provider-agnostic interface) | P0 |
| Workflow builder UI (chain agents visually) | P0 |
| First agents: Contradiction Checker (legal), Financial Anomaly Detector (corporate), Root-Cause Suggester (technical) | P0 |
| Accept/edit/dismiss review flow + audit logging | P0 |
| Remaining agents (Literature Summarizer, Diagnostic Differential Assistant, etc.) | P1 |

**Definition of Done:** At least 3 agents functional end-to-end against at least one real provider; every suggestion is visibly distinct from confirmed case data; every accept/edit/dismiss decision is logged in the audit trail; provider swap (e.g., Claude → Gemini) requires no core logic changes, only config.

**Dependencies:** AI Adapter Layer design finalized (Architecture.md §AI layer); LLM provider default decision resolved (PRD open question).

**Risks:** Prompt injection via malicious evidence content — mitigated by treating all AI output as unprivileged (Architecture.md §9); provider cost/rate-limit unknowns — mitigate by defaulting to a free/cheap tier in dev and gating expensive calls behind explicit user action, not automatic triggers.

**Resources:** 1–2 engineers focused on the AI Adapter Layer and agent prompt design; product input on agent output quality review.

**Deliverables:** AI Adapter Layer, workflow builder, 3+ working agents, updated memory.md.

**Go/No-Go for Phase 4:** Agent suggestion acceptance rate (PRD §3 KPI) trending above the 40% target in pilot usage, or a clear plan to improve it.

---

## 5. Phase 4 — SaaS Polish

**Goal:** Template marketplace, cross-case search, offline-first mobile, mobile app store release, and initial paid-tier groundwork.

**Epic breakdown:**

| Epic | Priority |
|---|---|
| Template marketplace (design/share custom case-type templates) | P2 |
| Cross-case search | P2 |
| Offline-first mobile sync | P2 |
| Version history on documents/notes | P2 |
| Mobile app store submission (iOS/Android) | P1 |
| Paid tier groundwork (billing integration, SSO, compliance export) | P2 |

**Definition of Done:** Offline mode verified on at least one field-test scenario (loss of connectivity mid-session, successful resync); marketplace supports at least template creation + sharing within a workspace; mobile builds pass store review.

**Dependencies:** Stable Phase 1–3 core; app store developer accounts provisioned ahead of submission (external dependency, review timelines outside team control).

**Risks:** Offline sync conflict resolution is inherently complex — scope a clear conflict-resolution policy (e.g., last-write-wins with a visible conflict flag) before building rather than during; app store review delays — submit early, treat review time as a hard external dependency.

**Resources:** Full team; may need dedicated mobile release engineer for store submission logistics.

**Deliverables:** Marketplace, cross-case search, offline mode, published mobile apps, updated memory.md.

**Go/No-Go:** Product decision point — proceed to monetization/billing work, or extend polish based on pilot feedback.

---

## 6. Phase Retrospective Log

*(Placeholder — update after each phase closes.)*

| Phase | What went well | What went poorly | Changes for next phase |
|---|---|---|---|
| Phase 0 | — | — | — |
| Phase 1 | *(pending)* | | |
| Phase 2 | *(pending)* | | |
| Phase 3 | *(pending)* | | |
| Phase 4 | *(pending)* | | |

---

## 7. Demo Day Plan (reference)

Reused from the original concept as the acceptance test for Phase 1's Definition of Done — a single ~90-second flow:

1. Create a Case Room (pick case type, get a private code).
2. Second device joins with a role, no IT setup.
3. Upload evidence to the vault.
4. *(Phase 3+)* AI agent flags a contradiction, clearly marked as a suggestion.
5. *(Phase 3+)* Lead approves it, logged in the audit trail.
6. *(Phase 2+)* Export a PDF report.

In Phase 1, steps 4–6 are stubbed/skipped since AI and export ship in later phases — Phase 1's demo proves steps 1–3 plus a visible, populated audit log.

---

## 8. GitHub Deployment & README Guidance

- **License:** this is a **public repository, all rights reserved** (not open-source licensed) — the README must include a clear `## License` section stating "All rights reserved. This code is publicly visible for portfolio/demonstration purposes; no license is granted for reuse, modification, or redistribution without permission," rather than an MIT/Apache badge.
- **README structure to build:**
  1. Project title + one-line positioning (§13 of the original concept doc).
  2. **Hero visual** — an architecture or product-flow image/animated SVG near the top (see §9 below for generation prompts).
  3. Problem/why-now summary (condensed from PRD.md §1).
  4. Feature highlights with the "How CaseThread Compares" table (from the concept doc §4).
  5. **Workflow pipeline visual** — the AI agent workflow or the Case Room lifecycle, placed inline near the relevant section.
  6. Tech stack badges (Flutter, Supabase, Vercel).
  7. **Result/stat card image** — a visual summarizing KPIs or demo-day results once available (placeholder until real pilot data exists).
  8. Setup/local dev instructions.
  9. Links to PRD.md, Architecture.md, Design.md for anyone wanting depth.
  10. License section (per above).
- **Image placement convention:** store generated images/SVGs/GIFs under `/docs/assets/` in the repo, reference them in the README with relative paths (`![Architecture Overview](./docs/assets/architecture-overview.svg)`) so they render correctly on GitHub.
- **Animated SVG/GIF usage:** best suited for the workflow pipeline (showing the suggestion → human-approval loop) since motion communicates the human-in-the-loop story better than a static diagram; keep static images for the architecture diagram and stat card for clarity/loading speed.

---

## 9. AI Image/Asset Generation Prompts

Pick 2–3 of these depending on what's ready to show; all are written to be portable across image-generating LLM tools.

**1. Architecture overview diagram (static, recommended)**
> "Create a clean, modern technical architecture diagram for a SaaS product called CaseThread. Show a Flutter client (Web, Android, iOS icons) connecting via HTTPS/WSS to a Supabase backend box containing four sub-components: Auth, Postgres+RLS, Storage, and Realtime, plus a separate Edge Functions box labeled 'AI Adapter Layer' connecting outward to four small provider icons labeled Claude, GPT, Gemini, and Grok. Use a navy (#0D1526) background, slate blue-gray boxes, white text, and a single muted teal accent color (#4FA8A0) for connecting lines and highlights. Flat, minimal, rounded rectangles, no drop shadows, no 3D effects, generous whitespace, suitable for a GitHub README on a dark theme. Export as SVG."

**2. Workflow pipeline / human-in-the-loop animation (animated SVG or GIF, recommended)**
> "Create a simple animated SVG/GIF showing a 4-step horizontal pipeline: (1) 'Evidence Uploaded' icon, arrow to (2) 'AI Agent Analyzes' icon (subtle pulsing to suggest processing), arrow to (3) 'Suggestion Flagged' icon in amber/gold (#E8B04B) to show a pending state, arrow to (4) 'Human Approves' icon in muted teal (#4FA8A0) with a checkmark, which then connects to a final 'Logged in Audit Trail' icon. Use a navy background (#0D1526), flat minimal line-icon style, smooth 2–3 second loop, no realistic imagery, no text-heavy labels beyond short captions under each step. Optimize for embedding in a GitHub README (small file size, seamless loop)."

**3. Result/stat card (static, use once pilot/demo data exists)**
> "Create a clean stat-card graphic for a SaaS product README, dark navy background (#0D1526), showing 3–4 large bold numbers with short labels beneath each — e.g., 'Time-to-first-room: <3 min', 'Case types supported: 5', 'Roles per room: up to 6', 'Codebase: 1 (Flutter, Web+Android+iOS)'. Use a single muted teal accent (#4FA8A0) for the numbers, off-white (#EDEFF3) for labels, minimal geometric divider lines between stats, no icons or illustrations, clean sans-serif typography (Inter or similar), suitable as a wide banner image for a GitHub README."

**4. Product mockup / screenshot placeholder (optional, once UI exists)**
> "Create a realistic browser-window mockup showing a dark-themed case-management dashboard UI called CaseThread: left sidebar with room navigation, center panel showing a case timeline with a few entries (one marked with an amber 'AI suggestion' badge), right panel showing team member avatars with role labels. Use navy (#0D1526) background, slate surfaces (#1B2436), teal accent (#4FA8A0) for primary buttons/active states, amber (#E8B04B) only for the pending-AI-suggestion badge, Inter font. Clean, professional SaaS aesthetic, no clutter."

---

## 10. LinkedIn Post Template

Use once Phase 1 (or a meaningful milestone) is demoable. Fill in bracketed placeholders with real specifics before posting.

```
🧵 [THE HOOK]
Built CaseThread — a case-room platform where any team (legal, academic,
corporate, medical, or technical) can spin up a private, secure workspace
in minutes, invite the right people with a join code, and manage an
entire case — evidence, timeline, and AI-assisted insight — in one place.

[THE PROBLEM]
Most case-management tools are built for one domain and require IT to
provision accounts before anyone can start working. That's fine for a
large agency with a procurement budget — it's useless for a legal team,
a student integrity board, or a fast-moving fraud unit that needs to be
collaborating in the next five minutes, not next week.

[THE TECH / PROCESS]
→ Flutter — one codebase shipping to Web, Android, and iOS
→ Supabase — Postgres, Auth, Realtime, and Row-Level Security doing the
   real permission enforcement, not just the UI
→ A provider-agnostic AI adapter layer — Claude, GPT, Gemini, or Grok,
   swappable behind one interface, always human-in-the-loop
→ Vercel + GitHub Actions for CI/CD

[THE RESULT]
[X] weeks in, [what's shipped — e.g., "the core Case Room flow — create,
join, upload evidence, see it all in an immutable audit trail — works
end-to-end across web and mobile."] Biggest lesson so far: [one real
learning, e.g., "building the permission model in the database (RLS)
instead of the UI made every later feature safer by default."]

[CALL TO ACTION]
If you've built or used a tool like this — what's the one feature that
made the difference between "another shared folder" and something your
team actually trusted with sensitive case data? Would love to hear it.

#SaaS #Flutter #Supabase #BuildInPublic #ProductDevelopment
```

**Hashtag notes:** swap `#ProductDevelopment` for something more specific to the milestone if useful (`#LegalTech`, `#EdTech`, `#AIAgents`) — keep to 3–5 total per the original brief.
