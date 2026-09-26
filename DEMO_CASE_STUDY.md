# CaseThread Case Study — "Meridian Bank Insider Fraud #3310"

> **Purpose:** a complete, self-contained demo case anyone on the team can run to see every CaseThread feature in one place — team roles and permissions, the evidence vault, the force-directed entity map, alibis, contradictions, gaps, AI human-in-the-loop review, discussion, export, and the investigation lifecycle.
>
> **Setup time:** ~10 minutes. **Demo time:** 15–20 minutes.

---

## 1. The Story (read this aloud to set the scene)

Between **3 and 17 September 2026**, six personal loans totalling **Rs 4.2M** were approved at **Meridian Bank's Gulberg branch** using forged income documents. Internal audit noticed a pattern: every fraudulent approval happened **3–6 minutes after** a vault access event by loan officer **Farhan Malik**. The suspected ring:

- **Farhan Malik** — the insider. Approves the loans, accesses the vault to swap in forged files.
- **Sana Iqbal** — the runner. Not a bank employee; handles the documents and pickups outside the branch.
- **Hassan Raza** — branch manager, cooperative witness.

The hook for the demo: **the vault log and the CCTV contradict each other** — the log puts Farhan in the vault at 19:48–20:02 on 9 Sept, but a CCTV still places him at a warehouse 11 km away at 19:55. Either the badge reader's clock is wrong, or someone cloned his access. Working theory (Ehtesham's, classified `claim`): clock skew — the raw badge-reader data will settle it.

---

## 2. Team, Logins & Roles

**Each member signs up once through the app** (Sign Up screen, email + password). The seed script then finds them **by email** — so use these exact addresses.

| Member | Email | Password | Role in the room | What this role can do (demo beats) |
|---|---|---|---|---|
| **Abdullah** | `abdullah@casethread.demo` | `demo1234` | **Lead Investigator** (owner) | Everything: approve/deny AI findings, export reports, manage members, rotate the access code, edit the briefing, resolve contradictions |
| **Zainab** | `zainab@casethread.demo` | `demo1234` | **Analyst** | Edit case data, upload evidence, work tasks/gaps — but **cannot** approve AI findings or export (show the denied export button) |
| **Ehtesham** | `ehtesham@casethread.demo` | `demo1234` | **Legal Counsel** | Like an analyst plus AI-review and export; his review of the WhatsApp export is a live task |
| **Qirat** | `qirat@casethread.demo` | `demo1234` | **Reviewer** | **Read-only** — no edit, no comment, no upload. Perfect for showing RLS-gated UI: she sees no composer, no upload FAB, no edit pencils |

**Room code:** `MERIDIAN7` · **Case type:** legal · **Room:** *Meridian Bank Insider Fraud #3310*

Abdullah joins by creating the room (or everyone joins via **Join** → code `MERIDIAN7` → pick the role listed above — owner approves from the Members tab). The seed script pre-approves all four memberships, so signing up and running the script is enough.

---

## 3. One-Time Setup (10 minutes)

Prerequisites: the app running (`flutter run -d chrome --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…` — see README) and access to the Supabase SQL editor.

1. **Sign up the four accounts** through the app UI, one per browser profile or in sequence (email confirmation may need to be disabled in Dashboard → Authentication → Providers for dev).
2. **Open the SQL editor** and run **`supabase/seed_case_study.sql`** top to bottom.
3. The script prints a verification row at the end. Confirm:
   `members = 4, entities = 6, evidence = 5, tasks = 4, alibis = 3, contradictions = 1, gaps = 3, ai_pending = 1, messages = 4, relationships = 9`.
4. Sign in as Abdullah → the room *Meridian Bank Insider Fraud #3310* appears in the cases panel. Everyone else joins with `MERIDIAN7` (or just refreshes — membership is already approved).

The script is **idempotent** — safe to re-run; it refreshes the briefing and status without duplicating anything.

---

## 4. The 20-Minute Demo Script

Sign in as **Abdullah** first (owner sees everything).

### Act 1 — Overview (3 min)
- **Case briefing** card: the whole story in one paragraph. Tap the ✏️ pencil (owner/edit_case only) to live-edit it.
- **Six stat tiles** + **coverage meter** + evidence-by-type and 14-day event charts — all real data from the seeded case.
- **Three alert cards**: `1 Contradiction`, `3 Gaps`, `Alibis 1 conflict · 1 partial/insufficient · 1 verified`. Tap the contradiction card → it **deep-links straight into the Analysis → Contradictions sub-tab**.
- **Alibi donut**: shows 1-of-3 verified.

### Act 2 — Evidence vault (4 min)
- Five classified items: hover/see the Fact/Claim/Finding badges.
- Tap **`cctv-vault-corridor-0909.png`** → **evidence detail sheet**: metadata, sha256 chain-of-custody, uploader.
- **Verify-Alibi inside the evidence sheet**: from the CCTV item, mark Farhan's alibi **Conflict** — the sheet demands a **reason** (type: "CCTV places him at the warehouse at 19:55, inside the claimed branch window") and attaches the evidence id to the verification. Watch the Overview donut and alert cards update.
- Sign in as **Zainab** (second browser profile) → she can upload but the export button is gone. Sign in as **Qirat** → no composer, no upload, no edit affordances anywhere (RLS-first UI gating).

### Act 3 — Analysis (4 min)
- **Contradictions**: the vault-log vs CCTV conflict, with both evidence sources linked. Open "Why connected?" from the map or the source list.
- **Alibis**: all four statuses represented (Farhan conflict, Sana insufficient, Hassan verified with reason + verifier + timestamp).
- **Gaps**: three open gaps → use **gap → task** to convert one into a task live.

### Act 4 — AI human-in-the-loop (3 min)
- **AI tab**: one **amber pending suggestion** from the *Contradiction Checker* ("Impossible dual presence…"). Only **Abdullah or Ehtesham** can act: **Accept** it (watch it land on the Timeline as an AI event + an audit entry), **Edit** it, or **Dismiss** it. Zainab cannot even see the review buttons.
- Live run (optional, needs the Edge Function deployed + consent step): run *Contradiction Checker* from the AI tab, or **Evidence → detail → "Analyze this evidence"** scoped to one item.

### Act 5 — Connections map (3 min) ← the showpiece
- **Force-directed graph** settles with physics; **drag a node** and watch the case re-balance.
- **Hover** Farhan → his 1-hop neighborhood stays bright, everything else dims.
- **Pinch/scroll zoom + pan**; tap an **edge** for the "Why connected?" sheet.
- **Filter chips**: hide `location` nodes; hide the `present_at` relationship type.
- **Local-graph mode** (crosshair): focus Farhan, 2 hops — the ring around the suspect.
- **Search-jump**: type "warehouse" → jump to the Model Town node.
- **Import template** (Abdullah/Ehtesham): `Import entity template` → published templates with entity seeds materialize a whole cast in one transaction.

### Act 6 — Discussion + export + lifecycle (3 min)
- **Discussion**: seeded thread; **long-press a message** → **Star**, **Pin to top** (pinned strip), or **Extract to case timeline** (Zainab/Abdullah — lands as a `claim` timeline event). @-mention chips above the composer.
- **Export** (Abdullah/Ehtesham): share icon → **PDF report** (downloads/saves) or **Markdown copy** — the report includes contradictions, alibis, gaps and status.
- **Members tab**: role-colored dots + "Active Xm ago" presence; owner approves pending joins here.
- **Lifecycle**: Abdullah transitions the investigation status (Overview ⋮ or Summary) — closing generates the **closed summary**.

### Act 7 — Governance (1 min)
- **Audit Log tab**: every action above is recorded, append-only — accept-edits, exports, verifications, imports.

---

## 5. Case Contents Reference (what the seed creates)

| Object | Details |
|---|---|
| **Room** | Meridian Bank Insider Fraud #3310 · legal · `under_investigation` · code `MERIDIAN7` |
| **Members** | Abdullah (lead_investigator, owner) · Zainab (analyst) · Ehtesham (legal_counsel) · Qirat (reviewer) |
| **Relationships (9)** | employed_by ×2 (Farhan, Hassan → Meridian Bank) · supervises (Hassan → Farhan) · has_access_to (Farhan → Vault Room) · present_at ×2 (Farhan, Sana → Warehouse) · contacted + accomplice_of (Sana ↔ Farhan) · files_moved_to (Vault Room → Warehouse, the working theory) |
| **Entities (6)** | Farhan Malik & Sana Iqbal (person/suspects), Hassan Raza (person/witness), Vault Room & Model Town Warehouse (locations), Meridian Bank (org) |
| **Evidence (5)** | vault-access-log (fact) · loan-applications-bundle (claim) · cctv still (fact) · whatsapp-export (claim) · phone-records-summary (finding) |
| **Alibis (3)** | Farhan → **conflict** (linked to CCTV) · Sana → **insufficient_data** · Hassan → **verified** (linked to vault log, reason + verifier recorded) |
| **Contradictions (1)** | Vault log vs CCTV dual-presence, sources linked, status open |
| **Gaps (3)** | Phone records 12–14 Sept · warehouse owner · second CCTV angle |
| **Tasks (4)** | 2 open, 1 in_progress, 1 done — with assignees and due dates |
| **AI suggestions (1)** | Pending `contradiction_checker` finding, ready for accept/edit/dismiss |
| **Timeline (5)** | Manual events from case-open to working-theory, Fact/Claim classified |
| **Discussion (4)** | Seeded thread covering all four voices |

---

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| Seed says a member count is 0/less than 4 | That email hasn't signed up yet. Sign up through the app with the exact address, then re-run the script (idempotent). |
| Room doesn't appear for Zainab/Ehtesham/Qirat | Membership is pre-approved; just re-open the cases panel. To demo the *join flow* instead, delete their `room_members` row and have them join with `MERIDIAN7`. |
| AI tab has no run button / run fails | The `ai-agent` Edge Function isn't deployed (`npx supabase functions deploy ai-agent --project-ref hxrztoakimebjcibvkaa`). The seeded pending suggestion still demonstrates review without it. |
| Export button missing | You're signed in as Zainab or Qirat — that's the permission model working. Switch to Abdullah/Ehtesham. |
| Graph looks static / no physics | Reduced-motion is on (OS setting) — by design it renders the settled layout. |
| "No import templates published yet" | No published template carries an `entity_seed` yet — publish one via the marketplace editor or add `entity_seed` to a template row and set `is_published = true`. |
| Evidence download link 404s | Expected: seed rows reference stand-in storage paths (no real files were uploaded). Upload one file through the app to demo a real download. |

---

## 7. Why This Case Is a Good Test Bed

Every feature has a *reason to exist* in the story: the contradiction exists because two honest sensors disagree; the conflict alibi exists because the CCTV contradicts the interview; the verified alibi populates the donut honestly; the pending AI finding mirrors the seeded contradiction so accepting it visibly enriches the timeline; the read-only member proves the permission matrix; the discussion extraction and template import both produce real, auditable case data. Nothing in the demo is decorative — which is the project's own rule.
