# CaseThread — End-to-End Demo & Setup Guide

> **Purpose:** Walk a teammate through every step of setting up, logging in, and demonstrating CaseThread on Chrome (Windows + VS Code). Includes all accounts, room codes, case details, and the full demo flow.

**Last updated:** 2026-09-17 · **Version:** 1.1 · **Covers:** All features through Phase 5 (investigation intelligence: alibis, contradictions, gaps, dashboard, case status, AI consent)

---

## Table of Contents

- [1. Project Overview](#1-project-overview)
- [2. Prerequisites](#2-prerequisites)
- [3. VS Code Setup (Windows)](#3-vs-code-setup-windows)
- [4. Environment Configuration](#4-environment-configuration)
- [5. Local Database Setup (Docker)](#5-local-database-setup-docker)
- [6. Supabase Cloud Setup](#6-supabase-cloud-setup)
- [7. Demo Accounts & Passwords](#7-demo-accounts--passwords)
- [8. Room Codes & Case Details](#8-room-codes--case-details)
- [9. Running the App on Chrome](#9-running-the-app-on-chrome)
- [10. Full Demo Flow (Two-Device Walkthrough)](#10-full-demo-flow-two-device-walkthrough)
- [11. Feature Deep-Dive](#11-feature-deep-dive)
- [12. Testing & Verification Commands](#12-testing--verification-commands)
- [13. Troubleshooting](#13-troubleshooting)
- [14. Quick Reference Card](#14-quick-reference-card)

---

## 1. Project Overview

CaseThread is a **case-room collaboration platform** where teams (legal, academic, corporate, medical, technical) can:

- **Create a private room** with a case type and access code — no IT provisioning
- **Invite teammates** via join code with role-based permissions
- **Upload evidence** to a versioned vault with audit trail
- **Track changes** via immutable audit log and mirrored timeline
- **Discuss** with @mentions in realtime
- **Manage tasks** with status tracking and assignments
- **Search** across all cases (Phase 4)
- **Work offline** with conflict resolution (Phase 4)
- **View version history** of tasks and events (Phase 4)
- **Track alibis, contradictions, and investigation gaps** in a dedicated Analysis tab (Phase 5)
- **View case dashboard statistics** — live counts of evidence, people, events, contradictions, gaps, AI findings (Phase 5)
- **Manage the investigation status lifecycle** — open → under investigation → review → closed, with auto-generated closed summary (Phase 5)
- **AI consent step** — every agent run asks for explicit consent showing what data will be accessed (Phase 5)

**Architecture:** Flutter (Web + Android + iOS) → Supabase (Postgres + RLS + Auth + Realtime + Storage) → Vercel (CI/CD)

**Key principles:**
- RLS (Row Level Security) is the boundary — not the UI layer
- All case types are pure config — zero core schema changes when adding new types
- Every write goes through server-side validated RPCs
- Audit log is append-only (immutable)

---

## 2. Prerequisites

| Tool | Version | Download |
|---|---|---|
| **Flutter SDK** | 3.47.2 | [flutter.dev](https://docs.flutter.dev/get-started/install) — SDK lives at `D:\5th Semester\MAD\flutter` on this machine |
| **Dart** | Bundled with Flutter | — |
| **Node.js** | 18+ | [nodejs.org](https://nodejs.org/) |
| **npm** | Bundled with Node | — |
| **Docker Desktop** | Latest | [docker.com](https://www.docker.com/products/docker-desktop/) |
| **Deno** | 2.9.6 | Installed via winget — path: `C:\Users\Aadi\AppData\Local\Microsoft\WinGet\Packages\DenoLand.Deno_Microsoft.Winget.Source_8wekyb3d8bbwe\deno.exe` (not on PATH — use full path) |
| **supabase CLI** | 2.117.0 | `npm install -g supabase` or `npx supabase` |
| **Git** | Latest | [git-scm.com](https://git-scm.com/) |
| **Chrome** | Latest | Already installed for web testing |
| **VS Code** | Latest | [code.visualstudio.com](https://code.visualstudio.com/) |

### PATH Setup (Critical on Windows)

```powershell
# Add Flutter to PATH (run every new shell session or add to profile):
$env:PATH += ";D:\5th Semester\MAD\flutter\bin"

# Verify:
flutter --version
```

---

## 3. VS Code Setup (Windows)

### Recommended Extensions

| Extension | Purpose |
|---|---|
| **Flutter** (Dart Code) | Flutter SDK management, hot reload, device tools |
| **Dart** (Dart Code) | Dart language support, analysis |
| **SQL** (e.g., SQLTools) | Query Supabase DB when needed |
| **GitLens** | Enhanced git blame, history |

### VS Code Workspace Settings

Create `.vscode/settings.json` in the repo root (already created — add if missing):

```json
{
  "editor.formatOnSave": true,
  "dart.flutterSdkPath": "D:\\5th Semester\\MAD\\flutter",
  "terminal.integrated.defaultProfile.windows": "Git Bash",
  "files.eol": "\n",
  "editor.tabSize": 2,
  "[dart]": {
    "editor.formatOnSave": true
  }
}
```

### Opening the Project

```powershell
# In VS Code:
code .
# Or: File → Open Folder → select case_thread/
```

---

## 4. Environment Configuration

### .env File

The `.env` file already exists in the repo root (gitignored — never committed). It contains:

```env
# Supabase project connection
SUPABASE_URL=https://hxrztoakimebjcibvkaa.supabase.co
SUPABASE_ANON_KEY=[see .env — value not shown in docs]

# AI provider (currently mock — set real key for production)
GROK_API_KEY=[set via npx supabase secrets set — value in .env only]
```

> **Security notes:**
> - The `SUPABASE_ANON_KEY` (publishable key) is safe in the client — RLS enforces access control
> - **NEVER** put the service-role key in `.env` or commit it
> - Web builds CANNOT read `.env` — they use `--dart-define` flags (see Section 9)

### Verify Configuration

```powershell
# Check .env exists:
cat .env

# Check Flutter is on PATH:
flutter --version

# Check Docker is running:
docker ps
```

---

## 5. Local Database Setup (Docker)

This is the **primary local development path** — all migrations and tests run here.

### One-Time Setup

```powershell
# 1. Start Supabase local stack (exclude pg_meta — it's chronically unhealthy)
npx supabase start --exclude studio,imgproxy,edge-runtime,logflare,vector,realtime,storage-api,postgres-meta

# 2. Reset database (applies all 31 migrations in order, seeds demo data)
npx supabase db reset

# 3. Run pgTAP test suite (should show 224/224 PASS — 166 through Phase 4 + 58 Phase 5)
npx supabase test db
```

> **Port note:** Windows Hyper-V reserves ports 54262–54361. The local stack auto-configures to use DB port **65432** (shadow 65420, pooler 65429).

### If Docker Desktop Stops Unexpectedly

```powershell
# Relaunch Docker Desktop:
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
# Wait 30 seconds, then retry the commands above
```

### Resetting Between Tests

```powershell
npx supabase db reset
```

This wipes all data and re-applies migrations from scratch — safe and fast (~10 seconds).

---

## 6. Supabase Cloud Setup

If testing against the cloud dev project instead of local Docker:

### Link & Push

```powershell
# Authenticate (one-time):
npx supabase login

# Link to the project:
npx supabase link --project-ref hxrztoakimebjcibvkaa

# Push all migrations to cloud:
npx supabase db push --include-all
```

### Cloud Database Credentials

In Supabase Dashboard → Project Settings → Database:
- Use the **connection string** from the Dashboard for direct DB access
- The project ref is `hxrztoakimebjcibvkaa`

### Cloud AI Function Secret

```powershell
# Set when ready (function runs in MOCK mode until this is set):
npx supabase secrets set AI_PROVIDER=grok GROK_API_KEY=<x.ai key>
```

---

## 7. Demo Accounts & Passwords

### Seeded Demo Users (apply via `supabase db reset`)

All demo users have password: **`demo1234`**

| # | Email | Password | Display Name | Role | Room | Status |
|---|---|---|---|---|---|---|
| 1 | `priya@casethread.demo` | `demo1234` | **Priya Sharma** | Lead Investigator | Contract Dispute — Riverbend Ltd | Owner (approved) |
| 2 | `elena@casethread.demo` | `demo1234` | **Elena** | Analyst | Contract Dispute — Riverbend Ltd | Member (approved) |
| 3 | `marcus@casethread.demo` | `demo1234` | **Marcus Reid** | Integrity Officer | CHEM-201 Integrity Hearing | Owner (approved) |

> **Important:** Email confirmation is disabled for the demo project. If signing up new users in dev, disable confirmation in Supabase Dashboard → Authentication → Providers, or wait for rate limit (429 `over_email_send_rate_limit`).

### Test Project Emails (for RLS contract tests — no password, ephemeral)

These are created dynamically during `npx supabase test db` and destroyed after each test session:
- `priya@example.com`, `elena@example.com`, `marcus@example.com` (room tests)
- `lead@example.com`, `analyst@example.com`, `observer@example.com`, `outsider@example.com` (content tests)
- `vault-lead@example.com`, `vault-analyst@example.com`, `vault-observer@example.com`, `vault-outsider@example.com` (vault tests)
- 40+ more across test files (not needed for manual demo)

---

## 8. Room Codes & Case Details

### Demo Room Access Codes

| Room Name | Case Type | Access Code | Owner | UUID |
|---|---|---|---|---|
| **Contract Dispute — Riverbend Ltd** | Legal / Investigative | **`RIVERBND`** | Priya Sharma | `b1000000-0000-4000-8000-000000000001` |
| **CHEM-201 Integrity Hearing** | Academic | **`CHEM201`** | Marcus Reid | `b1000000-0000-4000-8000-000000000002` |

> Access codes are stored as SHA-256 hashes only — never plaintext. The alphabet uses 8 unambiguous uppercase chars: `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no 0/O/1/I).

### All Case Types (5 total)

| Case Type | Owner Default Role | Description |
|---|---|---|
| **Legal / Investigative** | Lead Investigator | Contract disputes, fraud cases, investigations |
| **Academic** | Integrity Officer | Honor code, academic integrity hearings |
| **Corporate & Business** | Fraud Lead | Corporate fraud, compliance matters |
| **Technical & Engineering** | Incident Commander | SRE incidents, engineering incidents |
| **Medical & Healthcare** | Case Review Lead | Clinical review, medical cases (SME-gated) |

### All Roles per Case Type (Key Roles Shown)

| Role | Case Type | Tiered? |
|---|---|---|
| Lead Investigator | Legal | YES |
| Analyst | Legal | No |
| Legal Counsel | Legal | YES |
| Integrity Officer | Academic | YES |
| Panel Member | Academic | No |
| Fraud Lead | Corporate | YES |
| Internal Auditor | Corporate | No |
| Incident Commander | Technical | YES |
| SRE Responder | Technical | No |
| Case Review Lead | Medical | YES |
| Clinician | Medical | No |

### Permission Grid (8 dimensions)

Each role has 8 permissions: `view_case`, `edit_case`, `upload_evidence`, `comment`, `approve_ai_findings`, `manage_members`, `export_reports`, `view_privileged`

**Example — Legal Lead Investigator:** all 8 = YES (maximum power)
**Example — Legal Observer:** only `view_case` = YES (read-only)

---

## 9. Running the App on Chrome

### Pre-Launch Check

```powershell
# Format check:
dart format .

# Analysis (must be zero warnings):
flutter analyze

# Unit tests:
flutter test
```

### Launch on Chrome (Web)

```powershell
# Method 1: With .env (non-web platforms read .env automatically)
flutter run -d chrome

# Method 2: With --dart-define (REQUIRED for web — .env is not available at runtime)
flutter run -d chrome --dart-define=SUPABASE_URL=https://hxrztoakimebjcibvkaa.supabase.co --dart-define=SUPABASE_ANON_KEY=[from .env or Supabase Dashboard]
```

### Launch on Desktop (Windows)

```powershell
flutter run -d windows
```

### Release Build

```powershell
flutter build web --release
# Output: build/web/ — deploy to Vercel, GitHub Pages, or any static host
```

### What You'll See

1. **Setup screen** (if no Supabase config detected) — shows instructions
2. **Rooms hub** (after sign-in) — your list of case rooms, search icon, marketplace icon
3. **Room detail** (after selecting a room) — 7 tabs: Vault, Timeline, Discussion, Tasks, AI, Members, Analysis — plus a Quick Actions bar above the tabs

---

## 10. Full Demo Flow (Two-Device Walkthrough)

> **This is the main demo.** Requires two browser windows/devices. Use two Chrome profiles or two incognito windows.

### DEVICE 1 — Sign in as Priya (Room Owner)

#### Step 1: Sign In

1. Open Chrome → navigate to `http://localhost:3000` (or wherever Flutter web is running)
2. Click **"Sign In"**
3. Enter:
   - **Email:** `priya@casethread.demo`
   - **Password:** `demo1234`
4. Click **"Sign In"**
5. You land on the **Rooms Hub** — you see **"Contract Dispute — Riverbend Ltd"**

> **What just happened behind the scenes:** Supabase Auth verified credentials → session created → app fetched room list → displayed rooms where Priya is a member.

#### Step 2: View the Room

1. Click on **"Contract Dispute — Riverbend Ltd"**
2. You see 7 tabs: **Vault**, **Timeline**, **Discussion**, **Tasks**, **AI**, **Members**, **Analysis**
3. Above the tabs is the **Quick Actions bar** — pill-shaped chips (Evidence, Event, Statement, Task, Person, Alibi, Contradiction, Gap) that jump straight to the matching tab

#### Step 3: Explore Pre-Seeded Data

**Vault tab:**
- Evidence file: **`riverbend-contract.pdf`** (482 KB, version 1)
- Click it to see details — all metadata is tracked

**Timeline tab:**
- Shows all events for this room (audit entries are mirrored here)
- Pre-seeded: room created, evidence uploaded events

**Discussion tab:**
- Message from Priya: *"Kickoff: @Elena please review the termination clause by Friday."*
- Uses @mentions — Elena will get a notification

**Tasks tab:**
- Task: **"Review the signed contract clauses"** (status: In Progress, assigned to Elena)
- Click a task to toggle status — this now goes through offline queue

**Members tab:**
- Priya Sharma — Lead Investigator (Owner)
- Elena — Analyst

#### Step 4: Demonstrate Version History (Phase 4)

1. Go to the **Tasks** tab
2. Find "Review the signed contract clauses"
3. Click the **History** button (icon) on the task tile
4. A bottom sheet slides up showing the version history:
   - **v1**: Task created
   - Shows actor, timestamp, and change details

#### Step 5: Demonstrate Offline Banner

1. Look at the top of the room detail screen
2. If disconnected from Supabase, an amber **"Offline — as of HH:MM"** banner appears
3. The banner is hidden when online

#### Step 5b: Demonstrate Analysis Tab — Investigation Intelligence (Phase 5)

1. Click the **Analysis** tab (7th tab, or tap the **Alibi / Contradiction / Gap** Quick Action chips)
2. You see three nested sub-tabs: **Alibis**, **Contradictions**, **Gaps**
3. **Alibis** — record a claimed alibi (person, time window, claim text); verify it against evidence with a status + required human-readable reason (verified / partially verified / conflict / insufficient data). Note: no guilt-implying copy anywhere
4. **Contradictions** — flag a conflict between two sources manually, or review one raised by an AI agent; resolve or dismiss with a resolution note (Lead-tier)
5. **Gaps** — log what the case does NOT yet establish; convert a gap into a task with one tap (gap → task links the two and moves the gap to in-progress)
6. Each sub-tab has its own Quick Action chips that refresh the list and switch the sub-tab

#### Step 5c: Demonstrate AI Consent Dialog (Phase 5)

1. Go to the **AI** tab
2. Click any **agent run button** (including the new Case Completeness Review agent)
3. An **"AI consent"** dialog appears first — it states what data the agent will access (timeline events, evidence items, entities, members) and that the server only reads what you can already see
4. Click **Continue** to run, or **Cancel** to abort
5. The same consent dialog appears before running any **workflow** (multi-agent chain)

#### Step 5d: Demonstrate Case Dashboard & Investigation Status (Phase 5)

1. The case dashboard shows live statistics per room: evidence, people, locations, events, contradictions, gaps, unverified alibis, AI findings — served by the `v_case_statistics` view (RLS-scoped, no cross-room leaks)
2. The **investigation status** lifecycle (separate from the room's active/archived status): `open → under_investigation → review → closed`
3. Only the owner can transition status (`transition_investigation_status` RPC)
4. On transition to **closed**, a **case-closed summary** snapshot is auto-generated and stored immutably
5. Exported case reports now include investigation status, contradictions, alibis, and gaps

### DEVICE 2 — Sign in as Elena (Room Member)

> Open a second Chrome window (or incognito) for a separate session.

#### Step 6: Sign In

1. Open a second Chrome window
2. Navigate to the same app URL
3. Click **"Sign In"**
4. Enter:
   - **Email:** `elena@casethread.demo`
   - **Password:** `demo1234`
5. Land on Rooms Hub

#### Step 7: Join the Room

1. Click **"Join Room"** (or similar button)
2. Enter access code: **`RIVERBND`**
3. Select your role: **Analyst**
4. Submit join request
5. **Device 1:** Priya sees Elena's join request in the Members tab — click **"Approve"**

> **What just happened:** Elena's request went through `join_room()` RPC which checks the hashed access code, creates a `room_members` row with her role, and triggers RLS checks.

#### Step 8: Explore the Room as Elena

- Elena can see the room content (view_case = YES for Analyst)
- Elena can upload evidence (upload_evidence = YES for Analyst)
- Elena can create tasks, comment
- Elena **cannot** manage members, export reports, or view privileged data
- Elena sees the **offline banner** if network drops

### Demonstrate Offline Sync (P4-S3)

#### Step 9: Show Offline Write Queue

1. On Device 2 (Elena), open Chrome DevTools → Network tab
2. Set browser to **Offline** (DevTools → Network → Offline checkbox)
3. Try to create a task or post a message
4. The app queues the write locally (SharedPreferences, max 500 items)
5. Show the **OfflineBanner** and queue depth counter
6. **Reconnect** (uncheck Offline)
7. The queued write **replays automatically** — the task/message appears

#### Step 10: Show LWW Conflict Resolution

1. Both Device 1 (Priya) and Device 2 (Elena) edit the same task/Timeline event while offline
2. When reconnecting, the **LWW (Last Write Wins)** logic runs:
   - Server compares `client_value_at` timestamps
   - The **loser** gets a **ConflictChip** (amber indicator) on the task/event tile
3. Click the ConflictChip → shows who won and why
4. Click **"Acknowledge"** to clear the conflict flag

### Demonstrate Cross-Case Search (P4-S2)

#### Step 11: Search Across All Cases

1. On any device, click the **🔍 Search** icon in the app bar (rooms hub or any room)
2. Type at least 2 characters — e.g., `"contract"` or `"Elena"`
3. Results appear (debounced 350ms, max 50 results):
   - Room name matches
   - Discussion body snippets
   - Task title matches
   - Evidence filename matches
4. Click any result → deep-links into the relevant room
5. Results are **RLS-scoped** — you only see what your permissions allow (no cross-room leaks for non-members)

### Demonstrate Version History (P4-S4)

#### Step 12: View Timeline Event History

1. Open the room where Elena is a member
2. Go to **Timeline** tab
3. Find a **manual event** (user-created, not AI-generated)
4. Click the **"History"** text button
5. A bottom sheet shows:
   - v1: Event created (if manual)
   - v2+: Edits with before/after values
   - Actor name and timestamp for each version

### Demonstrate Template Marketplace (P4-S1, already merged)

#### Step 13: Create from Template (if templates exist)

1. From Rooms Hub, click the **Marketplace** icon (if UI includes it)
2. Browse published templates
3. Select a template → creates a new room with the template's case type config, roles, and slug-prefixed roles
4. The original draft stays private; only the published version is shared

---

## 11. Feature Deep-Dive

### A. Authentication Flow

```
Sign Up → Email + Password → Supabase Auth → Session created → Rooms Hub
Sign In → Email + Password → Supabase Auth → Validate → Rooms Hub
Sign Out → Destroy session → Setup screen
```

### B. Room Creation

```
Pick case type → generate access code (8-char, unambiguous alphabet) →
hash code (SHA-256) → insert room → create default roles →
insert room_members (owner = your role) → redirect to Room Detail
```

### C. Evidence Upload

```
Select room → Vault tab → Upload → file →
validate (RLS: upload_evidence permission) →
store in Supabase Storage (bucket) → create evidence_item row →
append audit entry → mirror to timeline
```

### D. Audit Trail

```
Every action → append_audit() RPC (security definer) →
audit_log row (immutable — no update/delete) →
trigger mirrors to timeline_events
```

### E. AI Suggestions (Phase 3, consent step added Phase 5)

```
User clicks agent run → AI CONSENT DIALOG (Phase 5: shows what data
will be accessed, requires explicit confirmation) →
Agent workflow runs → suggestion created (pending) →
shown in AI tab with amber badge → Lead: Accept / Edit / Dismiss →
review_suggestion() RPC → audit entry logged → timeline event created
```

### F. Offline Sync (P4-S3)

```
Write operation → try live → if fails, queue in SharedPreferences
→ on reconnect → replay queue in order →
each mutation: check membership/permissions → LWW compare →
apply or flag conflict → audit entry written
```

### G. Cross-Case Search (P4-S2)

```
User types query (≥2 chars) → debounce 350ms →
search_cases() RPC → prefix full-text (tsquery with :*) →
searches: room names, discussion bodies (via v_timeline),
task titles, evidence filenames → results RLS-scoped →
display snippets, deep-link on click
```

### H. Version History (P4-S4)

```
list_versions(object_kind, target_id) RPC →
queries audit_log with row_number() →
Tasks: v1 = created, v2+ = updates →
Timeline: v1 = event itself, v2+ = edits →
Returns: version, action, detail (before/after), actor, timestamp
```

### I. Template Marketplace (P4-S1)

```
Draft template → author-private → publish →
publish_template() RPC → MATERIALIZES into real config rows:
case_types + slug-prefixed roles → server validates all invariants →
Room from template uses unchanged create_case_room RPC
```

### J. Investigation Intelligence (Phase 5)

```
Analysis tab → three sub-tabs: Alibis / Contradictions / Gaps →
Alibi: record claim (person + time window) → verify_alibi() RPC →
status + required human-readable reason + evidence links →
Contradiction: flag manually or from AI suggestion →
contradiction_decision() RPC → resolve / dismiss / create linked task →
Gap: log what the case does NOT establish →
gap_create_task() RPC → task created + gap auto-moves to in_progress →
All writes RLS-gated (member read, edit_case write) + audited
```

### K. Case Dashboard & Status Lifecycle (Phase 5)

```
v_case_statistics() view (security_invoker) → RLS-scoped counts:
evidence, people, locations, events, contradictions, gaps,
unverified alibis, AI findings → no cross-room leaks →
Investigation status: open → under_investigation → review → closed →
transition_investigation_status() RPC (owner-only) →
on →closed: case_closed_summaries row auto-inserted (immutable snapshot) →
export_case_report v2 includes status + contradictions + alibis + gaps
```

---

## 12. Testing & Verification Commands

### Complete Verification Sequence

```powershell
# 1. Format
dart format .

# 2. Static analysis (MUST be zero warnings)
flutter analyze

# 3. Dart unit tests
flutter test

# 4. Local database tests (Docker stack required)
npx supabase test db
# Expected: 224/224 pgTAP PASS (166 through Phase 4 + 58 Phase 5)

# 5. AI adapter contract tests (Deno)
deno test --no-check --allow-env supabase/functions/ai-agent/index.test.ts
# Expected: 9/9 PASS

# 6. Web release build
flutter build web --release
```

### Test Coverage by Feature

| Feature | pgTAP Tests | Dart Tests | Status |
|---|---|---|---|
| RLS Core (Phase 1) | 75 | 59 | ✅ |
| Evidence Vault (Phase 2) | 58 | 42 | ✅ |
| Room Content (Phase 2) | 65 | 55 | ✅ |
| Phase 2 Exit | 98 | 59 | ✅ |
| AI/Workflows (Phase 3) | 121 | 73 | ✅ |
| Phase 3 Exit | 121 | 73 | ✅ |
| Marketplace (P4-S1) | 137 | 82 | ✅ |
| Cross-Case Search (P4-S2) | 10 | new | ✅ |
| Offline Sync (P4-S3) | 12 | new | ✅ |
| Version History (P4-S4) | 7 | new | ✅ |
| RLS: Alibis (P5) | 10 | new | ✅ |
| RLS: Contradictions (P5) | 10 | new | ✅ |
| RLS: Investigation Gaps (P5) | 10 | new | ✅ |
| Cross-Table Leak (P5) | 8 | new | ✅ |
| Statistics View (P5) | 11 | new | ✅ |
| Investigation Status (P5) | 9 | new | ✅ |
| **Phase 5 Exit** | **224** | **82+ (4 new model suites)** | **✅ ALL GREEN** |

### Key Test Files

**pgTAP (SQL — run via `npx supabase test db`):**
- `supabase/tests/db/rls_case_rooms_test.sql` — Room visibility, join flow
- `supabase/tests/db/rls_evidence_storage_test.sql` — Storage policies, versioning
- `supabase/tests/db/rls_room_content_test.sql` — Permissions gating
- `supabase/tests/db/cross_case_search_test.sql` — 10 assertions: member-scoped search, redaction boundary, RLS deny proof
- `supabase/tests/db/offline_sync_test.sql` — 12 assertions: LWW conflict, clear_conflict, replay deny
- `supabase/tests/db/version_history_test.sql` — 7 assertions: task/timeline versions, RLS deny
- `supabase/tests/db/rls_alibis_test.sql` — 10 assertions: member read, edit_case insert/update, non-member deny, status_reason CHECK
- `supabase/tests/db/rls_contradictions_test.sql` — 10 assertions: manual + ai_suggestion sources, lead resolve, non-lead deny
- `supabase/tests/db/rls_investigation_gaps_test.sql` — 10 assertions: gap CRUD, gap→task conversion, empty-title reject
- `supabase/tests/db/rls_cross_table_leak_test.sql` — 8 assertions: no cross-room leaks via alibi_evidence_links / contradiction_sources
- `supabase/tests/db/statistics_view_test.sql` — 11 assertions: correct counts, non-member room invisible, bigint types
- `supabase/tests/db/investigation_status_test.sql` — 9 assertions: default open, owner-only transitions, closed summary auto-generated

**Dart Unit Tests:**
- `test/features/search/search_test.dart` — SearchHit parsing, SearchQueryState
- `test/features/offline/offline_queue_test.dart` — Queue serialization, replay outcomes, security constraints
- `test/features/history/version_history_test.dart` — VersionEntry parsing
- `test/features/alibis/alibi_test.dart` — Alibi parsing, AlibiStatus round-trip
- `test/features/contradictions/contradiction_test.dart` — Manual + AI-suggestion parsing, enum round-trips
- `test/features/investigation_gaps/gap_task_test.dart` — InvestigationGap parsing, GapStatus round-trip
- `test/features/dashboard/dashboard_test.dart` — CaseStatistics, CaseClosedSummary, InvestigationStatus

---

## 13. Troubleshooting

| Problem | Solution |
|---|---|
| `flutter` not found | Run `$env:PATH += ";D:\5th Semester\MAD\flutter\bin"` in your shell |
| `deno` not found | Use full path: `C:\Users\Aadi\AppData\Local\Microsoft\WinGet\Packages\DenoLand.Deno_Microsoft.Winget.Source_8wekyb3d8bbwe\deno.exe` |
| `npx supabase start` fails (ports) | Ensure Docker Desktop is running; check ports 65432/65420/65429 not in use |
| `npx supabase test db` stops at pg_meta | Add `postgres-meta` to exclude list (health checks fail) |
| Sign-in fails for demo users | Check Supabase Dashboard → Auth → Providers → ensure email confirmation is OFF for dev |
| Sign-up rejects `@example.com` | Dev project blocks example.com — use `@casethread.demo` instead |
| App shows setup screen | `.env` not found or empty — verify SUPABASE_URL and SUPABASE_ANON_KEY |
| `.stream()` no-ops (realtime) | Table not in `supabase_realtime` publication — migrations include guarded `create publication` |
| Web build missing env | Use `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` |
| Analyze shows warnings | Fix all warnings — CI gates on zero warnings |
| `pgTAP` fails with exact error match | `throws_ok` matches exact full error string; use `is()` only on scalar subqueries |
| Docker Desktop stopped | Relaunch `C:\Program Files\Docker\Docker\Docker Desktop.exe` |
| Flutter SDK not on PATH | Add to profile: `echo '$env:PATH += ";D:\5th Semester\MAD\flutter\bin"' >> $PROFILE` |

---

## 14. Quick Reference Card

### Login Credentials

| Email | Password | Room | Role |
|---|---|---|---|
| `priya@casethread.demo` | `demo1234` | Contract Dispute — Riverbend Ltd | Owner / Lead Investigator |
| `elena@casethread.demo` | `demo1234` | Contract Dispute — Riverbend Ltd | Member / Analyst |
| `marcus@casethread.demo` | `demo1234` | CHEM-201 Integrity Hearing | Owner / Integrity Officer |

### Room Codes

| Room | Code | Case Type |
|---|---|---|
| Contract Dispute — Riverbend Ltd | `RIVERBND` | Legal |
| CHEM-201 Integrity Hearing | `CHEM201` | Academic |

### Supabase Configuration

| Item | Value |
|---|---|
| Project Ref | `hxrztoakimebjcibvkaa` |
| URL | `https://hxrztoakimebjcibvkaa.supabase.co` |
| Local DB Port | 65432 |

### Key Commands

```powershell
# Full verification gate
dart format . && flutter analyze && flutter test && npx supabase test db && deno test --no-check --allow-env supabase/functions/ai-agent/index.test.ts && flutter build web --release

# Local DB reset + test
npx supabase db reset && npx supabase test db

# Cloud push
npx supabase link --project-ref hxrztoakimebjcibvkaa && npx supabase db push --include-all

# Run on Chrome
flutter run -d chrome --dart-define=SUPABASE_URL=https://hxrztoakimebjcibvkaa.supabase.co --dart-define=SUPABASE_ANON_KEY=[from .env]

# Run on Windows desktop
flutter run -d windows
```

### Feature Verification Checklist

- [ ] Sign in as `priya@casethread.demo` / `demo1234` → Rooms Hub loads
- [ ] Sign in as `elena@casethread.demo` / `demo1234` → Join with code `RIVERBND`
- [ ] Priya approves Elena's join request
- [ ] Elena can view vault, tasks, discussion, timeline
- [ ] Elena can upload evidence (if upload_evidence = YES)
- [ ] Elena cannot manage members (manage_members = NO for Analyst)
- [ ] Offline banner appears when network disconnected
- [ ] Offline write queues and replays on reconnect
- [ ] LWW conflict chip appears on concurrent edits
- [ ] Search icon → type query → results appear and deep-link
- [ ] Task History button → version sheet opens
- [ ] Template marketplace → publish → room-from-template works
- [ ] Analysis tab shows Alibis / Contradictions / Gaps sub-tabs (Phase 5)
- [ ] Quick Action chips jump to the correct tab (Phase 5)
- [ ] AI agent run shows consent dialog before executing (Phase 5)
- [ ] Workflow run shows consent dialog before executing (Phase 5)
- [ ] Alibi verification requires a status reason (no bare status) (Phase 5)
- [ ] Gap → task conversion creates the task and moves gap to in-progress (Phase 5)
- [ ] Case dashboard statistics visible to members, invisible for non-member rooms (Phase 5)
- [ ] Investigation status transitions owner-only; closed generates a summary (Phase 5)
- [ ] Exported report includes investigation status, contradictions, alibis, gaps (Phase 5)

---

> **For teammates:** If anything doesn't work as described, check `memory.md` for known issues and gotchas. The local Docker loop (`npx supabase start` → `npx supabase db reset` → `npx supabase test db`) is the fastest way to verify database changes.
