-- ============================================================
-- CaseThread TEAM CASE STUDY (2026-09) — "Meridian Bank Insider
-- Fraud #3310" — run in the Supabase SQL editor.
-- Idempotent: fixed UUIDs + WHERE NOT EXISTS guards; re-running
-- refreshes the briefing/status without duplicating rows.
--
-- BEFORE RUNNING: the four team members must have signed up once
-- through the app (Email + password). This script then finds each
-- account BY EMAIL and assigns the room role.
--
--   abdullah@casethread.demo   (creates the account FIRST — becomes owner)
--   zainab@casethread.demo
--   ehtesham@casethread.demo
--   qirat@casethread.demo
--   Password for all: demo1234
--
-- Room access code: MERIDIAN7   (case type: legal)
-- ============================================================


-- ── PRE-FLIGHT CHECK ─────────────────────────────────────────
-- Fails fast with a readable message if any team member has not
-- signed up yet (the room needs its owner).
do $$
declare
  missing text;
begin
  select string_agg(e, ', ') into missing
  from unnest(array[
    'abdullah@casethread.demo',
    'zainab@casethread.demo',
    'ehtesham@casethread.demo',
    'qirat@casethread.demo'
  ]) as e
  where not exists (select 1 from auth.users where email = e);
  if missing is not null then
    raise exception 'These accounts have not signed up yet: %. '
      'Have each person sign up through the app first, then re-run '
      'this script.', missing;
  end if;
end $$;

-- ── CONFIG ───────────────────────────────────────────────────
create or replace function public.case_study_user(p_email text, p_fixed_id uuid)
returns uuid language sql stable as $$
  select coalesce(
    (select id from auth.users where email = p_email),
    (select id from auth.users where id = p_fixed_id)
  );
$$;

-- A CTE only lives for ONE statement — materialize the member ids as a
-- session temp table so every insert below can reference it.
create temp table _config as
  select
    public.case_study_user('abdullah@casethread.demo',
      'a0000000-0000-0000-0000-00000000a001') as abdullah,
    public.case_study_user('zainab@casethread.demo',
      'a0000000-0000-0000-0000-00000000a002') as zainab,
    public.case_study_user('ehtesham@casethread.demo',
      'a0000000-0000-0000-0000-00000000a003') as ehtesham,
    public.case_study_user('qirat@casethread.demo',
      'a0000000-0000-0000-0000-00000000a004') as qirat,
    'b1000000-0000-0000-0000-00000000b001'::uuid as room_id;
-- ── ROOM ─────────────────────────────────────────────────────
insert into public.case_rooms (
  id, name, case_type, owner_id, access_code_hash,
  status, investigation_status, briefing
)
select
  c.room_id,
  'Meridian Bank Insider Fraud #3310',
  'legal',
  c.abdullah,
  public.hash_access_code('MERIDIAN7'),
  'active',
  'under_investigation',
  'Between 3 and 17 September 2026, six personal loans totalling '
  'Rs 4.2M were approved at Meridian Bank''s Gulberg branch using '
  'forged income documents — every one within minutes of a vault '
  'access event by officer Farhan Malik. Suspected insider ring: '
  'Farhan (approvals) and Sana Iqbal (document runner). Priority: '
  'reconcile the vault log against CCTV timestamps, verify both '
  'suspects'' alibis, and obtain phone records for the 12–14 '
  'September window. Lead: Abdullah. Counsel review: Ehtesham.'
from _config c
on conflict (id) do update
  set briefing = excluded.briefing,
      investigation_status = excluded.investigation_status;

-- ── MEMBERS (all approved) ───────────────────────────────────
insert into public.room_members (room_id, user_id, role_id, status, joined_at)
select c.room_id, m.uid, m.role, 'approved', now()
from _config c, lateral (values
  (c.abdullah,  'lead_investigator'),
  (c.zainab,    'analyst'),
  (c.ehtesham,  'legal_counsel'),
  (c.qirat,     'reviewer')
) as m(uid, role)
where m.uid is not null
  and not exists (
    select 1 from public.room_members rm
    where rm.room_id = c.room_id and rm.user_id = m.uid
  );

-- ── ENTITIES ─────────────────────────────────────────────────
insert into public.entities (id, room_id, entity_type, name, attributes)
select v.id, c.room_id, v.entity_type, v.name, v.attributes::jsonb
from _config c, lateral (values
  ('c1000000-0000-0000-0000-00000000c001'::uuid, 'person',
   'Farhan Malik', '{"role": "suspect", "note": "loan officer, 6 yrs at branch"}'),
  ('c1000000-0000-0000-0000-00000000c002'::uuid, 'person',
   'Sana Iqbal', '{"role": "suspect", "note": "document runner, not a bank employee"}'),
  ('c1000000-0000-0000-0000-00000000c003'::uuid, 'person',
   'Hassan Raza', '{"role": "witness", "note": "branch manager"}'),
  ('c1000000-0000-0000-0000-00000000c004'::uuid, 'location',
   'Gulberg Branch — Vault Room', '{}'),
  ('c1000000-0000-0000-0000-00000000c005'::uuid, 'location',
   'Model Town Warehouse', '{"note": "loans stored here before pickup"}'),
  ('c1000000-0000-0000-0000-00000000c006'::uuid, 'org',
   'Meridian Bank', '{}')
) as v(id, entity_type, name, attributes)
where not exists (select 1 from public.entities e where e.id = v.id);

-- ── EVIDENCE (classified, chain-of-custody hashes are seed stand-ins) ──
insert into public.evidence_items (
  id, room_id, uploader_id, filename, storage_path, file_hash,
  mime_type, file_size_bytes, classification
)
select v.id, c.room_id, v.uploader, v.filename, v.storage_path,
       v.file_hash, v.mime_type, v.size, v.classification
from _config c, lateral (values
  ('c2000000-0000-0000-0000-00000000d001'::uuid, c.abdullah,
   'vault-access-log-sept.pdf', 'rooms/seed/vault-access-log-sept.pdf',
   'seedhash-vaultlog', 'application/pdf', 148120, 'fact'),
  ('c2000000-0000-0000-0000-00000000d002'::uuid, c.zainab,
   'loan-applications-bundle.pdf', 'rooms/seed/loan-applications-bundle.pdf',
   'seedhash-loans', 'application/pdf', 421300, 'claim'),
  ('c2000000-0000-0000-0000-00000000d003'::uuid, c.zainab,
   'cctv-vault-corridor-0909.png', 'rooms/seed/cctv-vault-corridor-0909.png',
   'seedhash-cctv1', 'image/png', 262144, 'fact'),
  ('c2000000-0000-0000-0000-00000000d004'::uuid, c.abdullah,
   'whatsapp-export-sana.txt', 'rooms/seed/whatsapp-export-sana.txt',
   'seedhash-wa', 'text/plain', 8830, 'claim'),
  ('c2000000-0000-0000-0000-00000000d005'::uuid, c.ehtesham,
   'phone-records-summary.pdf', 'rooms/seed/phone-records-summary.pdf',
   'seedhash-phone', 'application/pdf', 96440, 'finding')
) as v(id, uploader, filename, storage_path, file_hash, mime_type, size, classification)
where not exists (select 1 from public.evidence_items e where e.id = v.id);

-- ── TASKS ────────────────────────────────────────────────────
insert into public.tasks (id, room_id, title, created_by, assignee_id, status, due_date)
select v.id, c.room_id, v.title, c.abdullah, v.assignee, v.status, v.due
from _config c, lateral (values
  ('c3000000-0000-0000-0000-00000000e001'::uuid,
   'Request phone records for 12–14 Sept window (both suspects)',
   c.zainab, 'open', date '2026-09-30'),
  ('c3000000-0000-0000-0000-00000000e002'::uuid,
   'Identify and contact Model Town warehouse owner',
   c.zainab, 'in_progress', date '2026-10-02'),
  ('c3000000-0000-0000-0000-00000000e003'::uuid,
   'Ehtesham: legality review of the WhatsApp export before it is filed',
   c.ehtesham, 'open', date '2026-09-28'),
  ('c3000000-0000-0000-0000-00000000e004'::uuid,
   'Collect branch duty roster for 9 September',
   c.abdullah, 'done', date '2026-09-20')
) as v(id, title, assignee, status, due)
where not exists (select 1 from public.tasks t where t.id = v.id);

-- ── ALIBIS (one of each status — populates the donut + alert card) ──
insert into public.alibis (
  id, room_id, entity_id, claimed_window_start, claimed_window_end,
  claim_text, source, status, status_reason, created_by, verified_by, verified_at
)
select v.id, c.room_id, v.entity_id, v.ws, v.we, v.claim, v.source,
       v.status, v.reason, c.abdullah, v.verifier, v.verified_at
from _config c, lateral (values
  ('c4000000-0000-0000-0000-00000000f001'::uuid,
   'c1000000-0000-0000-0000-00000000c001'::uuid,
   timestamptz '2026-09-09 18:00:00+00',
   timestamptz '2026-09-09 22:00:00+00',
   'Farhan: at the branch until closing, never left',
   'interview',
   'conflict',
   'CCTV still 0909 places him at the Model Town warehouse at 19:55, '
   'inside the claimed branch window.',
   null, null),
  ('c4000000-0000-0000-0000-00000000f002'::uuid,
   'c1000000-0000-0000-0000-00000000c002'::uuid,
   timestamptz '2026-09-12 09:00:00+00',
   timestamptz '2026-09-12 18:00:00+00',
   'Sana: out of the city all day, phone was off',
   'interview',
   'insufficient_data',
   'Phone off for the whole window and no records yet — cannot '
   'confirm or contradict until the phone-records gap closes.',
   null, null),
  ('c4000000-0000-0000-0000-00000000f003'::uuid,
   'c1000000-0000-0000-0000-00000000c003'::uuid,
   timestamptz '2026-09-09 18:00:00+00',
   timestamptz '2026-09-09 22:00:00+00',
   'Hassan: in the manager office on a video call with regional HQ',
   'interview',
   'verified',
   'HQ call logs confirm the video call for the full window; duty '
   'roster (task 4) corroborates.',
   c.abdullah, timestamptz '2026-09-21 10:00:00+00')
) as v(id, entity_id, ws, we, claim, source, status, reason, verifier, verified_at)
where not exists (select 1 from public.alibis a where a.id = v.id);

-- ── ALIBI ↔ EVIDENCE LINKS ───────────────────────────────────
insert into public.alibi_evidence_links (alibi_id, evidence_item_id, relation)
select v.alibi, v.evidence, v.relation
from (values
  ('c4000000-0000-0000-0000-00000000f001'::uuid,
   'c2000000-0000-0000-0000-00000000d003'::uuid, 'conflicts'),
  ('c4000000-0000-0000-0000-00000000f003'::uuid,
   'c2000000-0000-0000-0000-00000000d001'::uuid, 'supports')
) as v(alibi, evidence, relation)
where not exists (
  select 1 from public.alibi_evidence_links l
  where l.alibi_id = v.alibi and l.evidence_item_id = v.evidence
);

-- ── CONTRADICTION (open, with linked sources) ────────────────
insert into public.contradictions (
  id, room_id, source_type, conflicting_detail, relevant_time,
  relevant_location, flagged_reason, status
)
select
  'c5000000-0000-0000-0000-00000000a001'::uuid,
  c.room_id, 'manual',
  'Vault access log shows Farhan inside the vault 19:48–20:02 on 9 Sept; '
  'CCTV corridor still timestamps him at the Model Town warehouse at 19:55.',
  timestamptz '2026-09-09 19:55:00+00',
  'Gulberg Branch — Vault Room',
  'Physical presence impossible at two locations 11 km apart within '
  'a 7-minute overlap.',
  'open'
from _config c
where not exists (
  select 1 from public.contradictions x
  where x.id = 'c5000000-0000-0000-0000-00000000a001'::uuid
);

insert into public.contradiction_sources (contradiction_id, evidence_item_id)
select v.contradiction, v.evidence
from (values
  ('c5000000-0000-0000-0000-00000000a001'::uuid,
   'c2000000-0000-0000-0000-00000000d001'::uuid),
  ('c5000000-0000-0000-0000-00000000a001'::uuid,
   'c2000000-0000-0000-0000-00000000d003'::uuid)
) as v(contradiction, evidence)
where not exists (
  select 1 from public.contradiction_sources s
  where s.contradiction_id = v.contradiction
    and s.evidence_item_id = v.evidence
);

-- ── INVESTIGATION GAPS ───────────────────────────────────────
insert into public.investigation_gaps (
  id, room_id, gap_type, description, source_type, status, created_by
)
select v.id, c.room_id, v.gap_type, v.description, 'manual', v.status,
       c.zainab
from _config c, lateral (values
  ('c6000000-0000-0000-0000-00000000a001'::uuid, 'evidence',
   'Phone records for both suspects, 12–14 September window, not '
   'requested yet (task 1 pending).', 'open'),
  ('c6000000-0000-0000-0000-00000000a002'::uuid, 'evidence',
   'Model Town warehouse lease/owner records not obtained — who '
   'rented the unit and when?', 'open'),
  ('c6000000-0000-0000-0000-00000000a003'::uuid, 'person',
   'Second vault-corridor camera (car-park angle) not recovered '
   'from the branch facilities team.', 'open')
) as v(id, gap_type, description, status)
where not exists (
  select 1 from public.investigation_gaps g where g.id = v.id
);

-- ── AI SUGGESTION (pending — for the human-in-the-loop review demo) ──
insert into public.ai_suggestions (id, room_id, agent_type, input_ref, output, status, created_at)
select
  'c7000000-0000-0000-0000-00000000a001'::uuid,
  c.room_id,
  'contradiction_checker',
  'vault_log+cctv',
  jsonb_build_object(
    'title', 'Impossible dual presence: vault log vs CCTV, 9 Sept 19:48–20:02',
    'detail', 'The vault access log and the corridor CCTV still place '
      'Farhan Malik at two locations 11 km apart inside a 7-minute '
      'window. Pattern matches the five prior approval events — each '
      'loan approval followed a vault access by 3–6 minutes. '
      'Recommend reconciling badge-reader raw timestamps before '
      'treating either source as authoritative.',
    'provider', 'seed'
  ),
  'pending',
  timestamptz '2026-09-22 09:15:00+00'
from _config c
where not exists (
  select 1 from public.ai_suggestions s
  where s.id = 'c7000000-0000-0000-0000-00000000a001'::uuid
);

-- ── TIMELINE (manual events, classified) ─────────────────────
insert into public.timeline_events (
  id, room_id, event_type, actor_id, payload, occurred_at, classification
)
select v.id, c.room_id, 'manual', v.actor, v.payload::jsonb, v.at, v.classification
from _config c, lateral (values
  ('c8000000-0000-0000-0000-00000000a001'::uuid, c.abdullah,
   '{"summary": "Case opened: six suspicious loans flagged by internal audit at Meridian Bank Gulberg branch."}',
   timestamptz '2026-09-18 09:00:00+00', 'fact'),
  ('c8000000-0000-0000-0000-00000000a002'::uuid, c.zainab,
   '{"summary": "Vault access log obtained: every fraudulent approval within 3–6 minutes of a Farhan Malik vault event."}',
   timestamptz '2026-09-19 14:30:00+00', 'fact'),
  ('c8000000-0000-0000-0000-00000000a003'::uuid, c.zainab,
   '{"summary": "CCTV corridor still recovered for 9 September — appears to contradict the vault log."}',
   timestamptz '2026-09-20 11:00:00+00', 'fact'),
  ('c8000000-0000-0000-0000-00000000a004'::uuid, c.abdullah,
   '{"summary": "Farhan and Sana interviewed; both alibis recorded in the Analysis tab."}',
   timestamptz '2026-09-21 16:00:00+00', 'fact'),
  ('c8000000-0000-0000-0000-00000000a005'::uuid, c.ehtesham,
   '{"summary": "Working theory: badge-reader clock skew may explain the vault/CCTV conflict — needs raw reader data."}',
   timestamptz '2026-09-22 17:45:00+00', 'claim')
) as v(id, actor, payload, at, classification)
where not exists (select 1 from public.timeline_events t where t.id = v.id);

-- ── DISCUSSION (a few messages so the thread isn't empty) ─────
insert into public.discussion_messages (id, room_id, author_id, body, created_at)
select v.id, c.room_id, v.author, v.body, v.at
from _config c, lateral (values
  ('c9000000-0000-0000-0000-00000000a001'::uuid, c.abdullah,
   'Welcome team. Everything you need is in the briefing — Zainab, start with the phone-records task.',
   timestamptz '2026-09-18 09:10:00+00'),
  ('c9000000-0000-0000-0000-00000000a002'::uuid, c.zainab,
   'Pulled the vault log — the 3–6 minute pattern between access and approval is consistent across all six loans.',
   timestamptz '2026-09-19 14:40:00+00'),
  ('c9000000-0000-0000-0000-00000000a003'::uuid, c.ehtesham,
   'Before the WhatsApp export is filed I need to verify how it was captured — chain of custody matters.',
   timestamptz '2026-09-21 17:50:00+00'),
  ('c9000000-0000-0000-0000-00000000a004'::uuid, c.qirat,
   'Reviewed the timeline so far — reads clean. Flagging that the gap list should mention the second camera.',
   timestamptz '2026-09-22 10:20:00+00')
) as v(id, author, body, at)
where not exists (select 1 from public.discussion_messages m where m.id = v.id);


-- ── ENTITY RELATIONSHIPS (the connection graph) ──────────────
-- Who is linked to whom: employment, access, contact and the
-- alleged movement of files between the two locations.
insert into public.entity_relationships
  (room_id, from_entity_id, to_entity_id, relationship_type)
select c.room_id, v.f, v.t, v.rel
from _config c, lateral (values
  ('c1000000-0000-0000-0000-00000000c001'::uuid,   -- Farhan
   'c1000000-0000-0000-0000-00000000c006'::uuid, 'employed_by'),  -- Meridian Bank
  ('c1000000-0000-0000-0000-00000000c003'::uuid,   -- Hassan
   'c1000000-0000-0000-0000-00000000c006'::uuid, 'employed_by'),
  ('c1000000-0000-0000-0000-00000000c003'::uuid,   -- Hassan
   'c1000000-0000-0000-0000-00000000c001'::uuid, 'supervises'),   -- Farhan
  ('c1000000-0000-0000-0000-00000000c001'::uuid,   -- Farhan
   'c1000000-0000-0000-0000-00000000c004'::uuid, 'has_access_to'),-- Vault Room
  ('c1000000-0000-0000-0000-00000000c001'::uuid,   -- Farhan
   'c1000000-0000-0000-0000-00000000c005'::uuid, 'present_at'),   -- Warehouse (CCTV)
  ('c1000000-0000-0000-0000-00000000c002'::uuid,   -- Sana
   'c1000000-0000-0000-0000-00000000c005'::uuid, 'present_at'),   -- Warehouse
  ('c1000000-0000-0000-0000-00000000c002'::uuid,   -- Sana
   'c1000000-0000-0000-0000-00000000c001'::uuid, 'contacted'),    -- WhatsApp
  ('c1000000-0000-0000-0000-00000000c002'::uuid,   -- Sana
   'c1000000-0000-0000-0000-00000000c001'::uuid, 'accomplice_of'),
  ('c1000000-0000-0000-0000-00000000c004'::uuid,   -- Vault Room
   'c1000000-0000-0000-0000-00000000c005'::uuid, 'files_moved_to') -- working theory
) as v(f, t, rel)
where not exists (
  select 1 from public.entity_relationships r
  where r.room_id = c.room_id
    and r.from_entity_id = v.f
    and r.to_entity_id = v.t
    and r.relationship_type = v.rel
);

-- ── VERIFICATION SUMMARY ─────────────────────────────────────
-- Run the SELECTs below (they execute at the end of the script in the
-- SQL editor) to confirm the import. Expect:
--   members = 4, entities = 6, evidence = 5, tasks = 4,
--   alibis = 3, contradictions = 1, gaps = 3, ai_pending = 1
select
  (select count(*) from public.room_members
     where room_id = c.room_id)                          as members,
  (select count(*) from public.entities
     where room_id = c.room_id)                          as entities,
  (select count(*) from public.evidence_items
     where room_id = c.room_id)                          as evidence,
  (select count(*) from public.tasks
     where room_id = c.room_id)                          as tasks,
  (select count(*) from public.alibis
     where room_id = c.room_id)                          as alibis,
  (select count(*) from public.contradictions
     where room_id = c.room_id)                          as contradictions,
  (select count(*) from public.investigation_gaps
     where room_id = c.room_id)                          as gaps,
  (select count(*) from public.ai_suggestions
     where room_id = c.room_id and status = 'pending')   as ai_pending,
  (select count(*) from public.discussion_messages
     where room_id = c.room_id)                          as messages,
  (select count(*) from public.entity_relationships
     where room_id = c.room_id)                          as relationships
from _config c;
