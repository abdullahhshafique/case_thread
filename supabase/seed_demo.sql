-- ============================================================
-- CaseThread demo seed (Phase 6) — run in the Supabase SQL editor.
-- Idempotent: fixed UUIDs + WHERE NOT EXISTS guards, so re-running
-- updates the demo room in place without duplicating rows.
--
-- BEFORE RUNNING: open the `config` CTE below and replace
--   demo_user_id  ← your demo user's auth.users id
-- (Authentication → Users → copy id, or:
--   select id, email from auth.users;
-- ). The demo user owns the room and is its lead investigator.
-- Join the room with access code DEMO1234 as any other user.
-- ============================================================

-- ── CONFIG ───────────────────────────────────────────────────

with config as (
  select
    '11111111-1111-1111-1111-111111111111'::uuid as demo_user_id, -- ← REPLACE with your auth.users id
    '22222222-2222-2222-2222-222222222222'::uuid as room_id
)
-- ── ROOM ─────────────────────────────────────────────────────
insert into public.case_rooms (
  id, name, case_type, owner_id, access_code_hash,
  status, investigation_status, briefing
)
select
  c.room_id,
  'Riverside Robbery #2291',
  'legal',
  c.demo_user_id,
  public.hash_access_code('DEMO1234'),
  'active',
  'under_investigation',
  'Convenience-store robbery on the riverside, 10 September 2026, '
  '20:00–23:00. Two suspects in scope; CCTV and witness statements '
  'conflict on arrival time. Priority: reconcile witness A vs B, '
  'close the phone-records gap, verify both alibis.'
from config c
on conflict (id) do update
  set briefing = excluded.briefing,
      investigation_status = excluded.investigation_status;

-- ── MEMBERSHIP (owner as lead investigator) ──────────────────
insert into public.room_members (room_id, user_id, role_id, status, joined_at)
select c.room_id, c.demo_user_id, 'lead_investigator', 'approved', now()
from config c
where not exists (
  select 1 from public.room_members m
  where m.room_id = c.room_id and m.user_id = c.demo_user_id
);

-- ── ENTITIES ─────────────────────────────────────────────────
insert into public.entities (id, room_id, entity_type, name, attributes)
select v.id, c.room_id, v.entity_type, v.name, v.attributes::jsonb
from config c, (values
  ('33333333-3333-3333-3333-333333333333'::uuid, 'person',
   'Jamie Rivera', '{"role": "suspect"}'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'person',
   'Casey Monk', '{"role": "suspect"}'),
  ('55555555-5555-5555-5555-555555555555'::uuid, 'person',
   'Witness A (shop clerk)', '{"role": "witness"}'),
  ('66666666-6666-6666-6666-666666666666'::uuid, 'location',
   'Riverside Convenience Store', '{}')
) as v(id, entity_type, name, attributes)
where not exists (select 1 from public.entities e where e.id = v.id);

-- ── EVIDENCE ─────────────────────────────────────────────────
insert into public.evidence_items (
  id, room_id, uploader_id, filename, storage_path, file_hash,
  mime_type, file_size_bytes, classification
)
select v.id, c.room_id, c.demo_user_id, v.filename, v.storage_path,
       v.file_hash, v.mime_type, v.size, v.classification
from config c, (values
  ('77777777-7777-7777-7777-777777777777'::uuid,
   'cctv-still-2010.png', 'rooms/demo/cctv-still-2010.png',
   'seedhash-cctv', 'image/png', 184320, 'fact'),
  ('88888888-8888-8888-8888-888888888888'::uuid,
   'witness-a-statement.pdf', 'rooms/demo/witness-a-statement.pdf',
   'seedhash-wita', 'application/pdf', 92160, 'claim'),
  ('99999999-9999-9999-9999-999999999999'::uuid,
   'witness-b-statement.pdf', 'rooms/demo/witness-b-statement.pdf',
   'seedhash-witb', 'application/pdf', 88576, 'claim')
) as v(id, filename, storage_path, file_hash, mime_type, size, classification)
where not exists (select 1 from public.evidence_items e where e.id = v.id);

-- ── TASKS ────────────────────────────────────────────────────
insert into public.tasks (id, room_id, title, created_by, status, due_date)
select v.id, c.room_id, v.title, c.demo_user_id, v.status, v.due
from config c, (values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
   'Reconcile witness A and B arrival-time statements', 'open',
   date '2026-09-30'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
   'Request phone records for the 20:00–23:00 window', 'in_progress',
   date '2026-10-02')
) as v(id, title, status, due)
where not exists (select 1 from public.tasks t where t.id = v.id);

-- ── CONTRADICTION (open) ─────────────────────────────────────
insert into public.contradictions (
  id, room_id, source_type, conflicting_detail, relevant_time,
  relevant_location, flagged_reason, status
)
select
  'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
  c.room_id, 'manual',
  'Witness A states the suspect arrived ~20:15; Witness B states ~21:40.',
  timestamptz '2026-09-10 20:15:00+00',
  'Riverside Convenience Store',
  'Direct statement conflict on arrival time within the incident window.',
  'open'
from config c
where not exists (
  select 1 from public.contradictions x
  where x.id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid
);

-- ── ALIBIS ───────────────────────────────────────────────────
insert into public.alibis (
  id, room_id, entity_id, claimed_window_start, claimed_window_end,
  claim_text, source, status, status_reason, created_by
)
select v.id, c.room_id, v.entity_id, v.ws, v.we, v.claim, 'interview',
       v.status, v.reason, c.demo_user_id
from config c, (values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd'::uuid,
   '33333333-3333-3333-3333-333333333333'::uuid,
   timestamptz '2026-09-10 19:00:00+00',
   timestamptz '2026-09-10 23:00:00+00',
   'At home with family all evening',
   'conflict',
   'CCTV places them near the store at 21:55, contradicting the claim.'),
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'::uuid,
   '44444444-4444-4444-4444-444444444444'::uuid,
   timestamptz '2026-09-10 20:00:00+00',
   timestamptz '2026-09-10 23:00:00+00',
   'Gym session across town',
   'gym-records',
   'insufficient_data',
   null)
) as v(id, entity_id, ws, we, claim, status, reason)
where not exists (select 1 from public.alibis a where a.id = v.id);

-- ── INVESTIGATION GAPS ───────────────────────────────────────
insert into public.investigation_gaps (
  id, room_id, gap_type, description, source_type, status, created_by
)
select v.id, c.room_id, v.gap_type, v.description, 'manual', v.status,
       c.demo_user_id
from config c, (values
  ('ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid, 'evidence',
   'Phone records for both suspects, 20:00–23:00 window, not requested yet.',
   'open'),
  ('abababab-abab-abab-abab-abababababab'::uuid, 'evidence',
   'Second CCTV angle (car park) not recovered from the store owner.',
   'open')
) as v(id, gap_type, description, status)
where not exists (
  select 1 from public.investigation_gaps g where g.id = v.id
);

-- ── TIMELINE ─────────────────────────────────────────────────
insert into public.timeline_events (
  id, room_id, event_type, actor_id, payload, occurred_at, classification
)
select v.id, c.room_id, 'manual', c.demo_user_id,
       jsonb_build_object('summary', v.summary), v.at, v.classification
from config c, (values
  ('acacacac-acac-acac-acac-acacacacacac'::uuid,
   'Case opened; initial witness statements collected.',
   timestamptz '2026-09-10 23:30:00+00', 'fact'),
  ('adadadad-adad-adad-adad-adadadadadad'::uuid,
   'CCTV still recovered from the storefront camera.',
   timestamptz '2026-09-12 09:00:00+00', 'fact'),
  ('aeaeaeae-aeae-aeae-aeae-aeaeaeaeaeae'::uuid,
   'Witness arrival-time conflict flagged for reconciliation.',
   timestamptz '2026-09-14 15:00:00+00', 'claim')
) as v(id, summary, at, classification)
where not exists (select 1 from public.timeline_events t where t.id = v.id);
