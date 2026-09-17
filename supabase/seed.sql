-- CaseThread demo seed (Rules.md §13): realistic rooms/evidence for
-- local development and demo environments. NEVER run against prod.
--
-- supabase db reset applies this automatically when config.toml's
-- [db] seed.enabled = true and seed.sql exists.

-- Demo users (password: demo1234 — dev-only, not production security).
insert into auth.users (
  instance_id, id, aud, role, email,
  encrypted_password, email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
) values
  ('00000000-0000-0000-0000-000000000000',
   'a1000000-0000-4000-8000-000000000001', 'authenticated',
   'authenticated', 'priya@casethread.demo',
   extensions.crypt('demo1234', extensions.gen_salt('bf')),
   now(), now(), now(), '{}', '{"display_name":"Priya Sharma"}'),
  ('00000000-0000-0000-0000-000000000000',
   'a1000000-0000-4000-8000-000000000002', 'authenticated',
   'authenticated', 'elena@casethread.demo',
   extensions.crypt('demo1234', extensions.gen_salt('bf')),
   now(), now(), now(), '{}', '{"display_name":"Elena"}'),
  ('00000000-0000-0000-0000-000000000000',
   'a1000000-0000-4000-8000-000000000003', 'authenticated',
   'authenticated', 'marcus@casethread.demo',
   extensions.crypt('demo1234', extensions.gen_salt('bf')),
   now(), now(), now(), '{}', '{"display_name":"Marcus Reid"}')
on conflict (id) do nothing;

insert into public.profiles (id, display_name) values
  ('a1000000-0000-4000-8000-000000000001', 'Priya Sharma'),
  ('a1000000-0000-4000-8000-000000000002', 'Elena'),
  ('a1000000-0000-4000-8000-000000000003', 'Marcus Reid')
on conflict (id) do nothing;

-- Legal demo room (Priya leads, Elena analyst).
insert into public.case_rooms (id, name, case_type, owner_id, access_code_hash)
values
  ('b1000000-0000-4000-8000-000000000001',
   'Contract Dispute — Riverbend Ltd',
   'legal',
   'a1000000-0000-4000-8000-000000000001',
   public.hash_access_code('RIVERBND'))
on conflict (id) do nothing;

insert into public.room_members (room_id, user_id, role_id, status, joined_at)
values
  ('b1000000-0000-4000-8000-000000000001',
   'a1000000-0000-4000-8000-000000000001',
   'lead_investigator', 'approved', now()),
  ('b1000000-0000-4000-8000-000000000001',
   'a1000000-0000-4000-8000-000000000002',
   'analyst', 'approved', now())
on conflict (room_id, user_id) do nothing;

-- Academic demo room (Marcus leads).
insert into public.case_rooms (id, name, case_type, owner_id, access_code_hash)
values
  ('b1000000-0000-4000-8000-000000000002',
   'CHEM-201 Integrity Hearing',
   'academic',
   'a1000000-0000-4000-8000-000000000003',
   public.hash_access_code('CHEM201'))
on conflict (id) do nothing;

insert into public.room_members (room_id, user_id, role_id, status, joined_at)
values
  ('b1000000-0000-4000-8000-000000000002',
   'a1000000-0000-4000-8000-000000000003',
   'integrity_officer', 'approved', now())
on conflict (room_id, user_id) do nothing;

-- Demo content for the legal room: evidence, task, discussion,
-- audit entries (mirrored into the timeline by the 0010 trigger).
insert into public.evidence_items (
  id, room_id, uploader_id, filename, storage_path,
  file_hash, mime_type, file_size_bytes, version
)
values
  ('c1000000-0000-4000-8000-000000000001',
   'b1000000-0000-4000-8000-000000000001',
   'a1000000-0000-4000-8000-000000000001',
   'riverbend-contract.pdf',
   'rooms/b1000000-0000-4000-8000-000000000001/riverbend-contract.pdf',
   repeat('2', 64), 'application/pdf', 482133, 1)
on conflict (id) do nothing;

select public.append_audit(
  'b1000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'evidence_uploaded', 'evidence_item',
  'c1000000-0000-4000-8000-000000000001',
  jsonb_build_object('filename', 'riverbend-contract.pdf', 'version', 1)
);

insert into public.tasks (room_id, title, assignee_id, created_by, status)
values
  ('b1000000-0000-4000-8000-000000000001',
   'Review the signed contract clauses',
   'a1000000-0000-4000-8000-000000000002',
   'a1000000-0000-4000-8000-000000000001',
   'in_progress')
on conflict do nothing;

insert into public.discussion_messages (room_id, author_id, body, mentions)
values
  ('b1000000-0000-4000-8000-000000000001',
   'a1000000-0000-4000-8000-000000000001',
   'Kickoff: @Elena please review the termination clause by Friday.',
   array['a1000000-0000-4000-8000-000000000002']::uuid[])
on conflict do nothing;

-- ===========================================================================
-- Phase 6 (doc §30): one coherent fictional investigation —
-- "Riverside Robbery #2291" — so every feature (Dashboard, Vault, Timeline,
-- Connections, Alibis, Contradictions, Gaps, Tasks, Report) tells the same
-- story. Priya leads, Elena assists.
-- ===========================================================================

insert into public.case_rooms (id, name, case_type, owner_id, access_code_hash)
values
  ('b1000000-0000-4000-8000-000000000003',
   'Riverside Robbery #2291',
   'legal',
   'a1000000-0000-4000-8000-000000000001',
   public.hash_access_code('ROBBERY2'))
on conflict (id) do nothing;

insert into public.room_members (room_id, user_id, role_id, status, joined_at)
values
  ('b1000000-0000-4000-8000-000000000003',
   'a1000000-0000-4000-8000-000000000001', 'lead_investigator', 'approved', now()),
  ('b1000000-0000-4000-8000-000000000003',
   'a1000000-0000-4000-8000-000000000002', 'analyst', 'approved', now())
on conflict (room_id, user_id) do nothing;

-- People, vehicle, locations (doc §30 cast).
insert into public.entities (id, room_id, entity_type, name, attributes) values
  ('d1000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000003',
   'person', 'Suspect A', '{"note": "identified from CCTV frame"}'),
  ('d1000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000003',
   'person', 'Witness B', '{}'),
  ('d1000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000003',
   'person', 'Witness C', '{}'),
  ('d1000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000003',
   'person', 'Store Owner', '{}'),
  ('d1000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000003',
   'vehicle', 'Vehicle V01', '{"make": "grey van"}'),
  ('d1000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000003',
   'location', 'Suspect Home', '{}'),
  ('d1000000-0000-4000-8000-000000000007', 'b1000000-0000-4000-8000-000000000003',
   'location', 'Riverside Store', '{}'),
  ('d1000000-0000-4000-8000-000000000008', 'b1000000-0000-4000-8000-000000000003',
   'location', 'Riverside Road', '{}'),
  ('d1000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000003',
   'location', 'Rear Entrance', '{}')
on conflict (id) do nothing;

-- Relationships: the connection map's story (doc §13).
insert into public.entity_relationships (room_id, from_entity_id, to_entity_id, relationship_type) values
  ('b1000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000001',
   'd1000000-0000-4000-8000-000000000005', 'owns'),
  ('b1000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000001',
   'd1000000-0000-4000-8000-000000000006', 'left_from'),
  ('b1000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000005',
   'd1000000-0000-4000-8000-000000000008', 'spotted_at'),
  ('b1000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000005',
   'd1000000-0000-4000-8000-000000000007', 'arrived_at'),
  ('b1000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000001',
   'd1000000-0000-4000-8000-000000000009', 'entered_via'),
  ('b1000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000002',
   'd1000000-0000-4000-8000-000000000005', 'witnessed'),
  ('b1000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000003',
   'd1000000-0000-4000-8000-000000000009', 'witnessed'),
  ('b1000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000004',
   'd1000000-0000-4000-8000-000000000007', 'works_at')
on conflict do nothing;

-- Evidence with Fact/Claim classification (doc §30).
insert into public.evidence_items (
  id, room_id, uploader_id, filename, storage_path, file_hash,
  mime_type, file_size_bytes, version, classification
) values
  ('c1000000-0000-4000-8000-000000000011', 'b1000000-0000-4000-8000-000000000003',
   'a1000000-0000-4000-8000-000000000001', 'cctv-riverside-road-2042.mp4',
   'rooms/b1000000-0000-4000-8000-000000000003/cctv-riverside-road-2042.mp4',
   repeat('3', 64), 'video/mp4', 24800000, 1, 'fact'),
  ('c1000000-0000-4000-8000-000000000012', 'b1000000-0000-4000-8000-000000000003',
   'a1000000-0000-4000-8000-000000000001', 'vehicle-registration-v01.pdf',
   'rooms/b1000000-0000-4000-8000-000000000003/vehicle-registration-v01.pdf',
   repeat('4', 64), 'application/pdf', 220000, 1, 'fact'),
  ('c1000000-0000-4000-8000-000000000013', 'b1000000-0000-4000-8000-000000000003',
   'a1000000-0000-4000-8000-000000000001', 'witness-b-statement.pdf',
   'rooms/b1000000-0000-4000-8000-000000000003/witness-b-statement.pdf',
   repeat('5', 64), 'application/pdf', 96000, 1, 'claim'),
  ('c1000000-0000-4000-8000-000000000014', 'b1000000-0000-4000-8000-000000000003',
   'a1000000-0000-4000-8000-000000000001', 'phone-location-record.csv',
   'rooms/b1000000-0000-4000-8000-000000000003/phone-location-record.csv',
   repeat('6', 64), 'text/csv', 34000, 1, 'fact'),
  ('c1000000-0000-4000-8000-000000000015', 'b1000000-0000-4000-8000-000000000003',
   'a1000000-0000-4000-8000-000000000001', 'rear-entrance-photos.zip',
   'rooms/b1000000-0000-4000-8000-000000000003/rear-entrance-photos.zip',
   repeat('7', 64), 'application/zip', 8100000, 1, 'fact')
on conflict (id) do nothing;

-- Reconstructed timeline (doc §10 example sequence), with classifications.
insert into public.timeline_events (
  id, room_id, actor_id, event_type, payload, occurred_at, classification
) values
  ('e1000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000003',
   'a1000000-0000-4000-8000-000000000001', 'manual',
   '{"summary": "8:15 PM — Suspect A allegedly leaves home"}',
   '2026-09-10 20:15:00+00', 'claim'),
  ('e1000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000003',
   'a1000000-0000-4000-8000-000000000001', 'manual',
   '{"summary": "8:32 PM — Vehicle V01 spotted near Riverside Road (Witness B)"}',
   '2026-09-10 20:32:00+00', 'claim'),
  ('e1000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000003',
   'a1000000-0000-4000-8000-000000000001', 'manual',
   '{"summary": "8:42 PM — CCTV captures Vehicle V01 at Riverside Road"}',
   '2026-09-10 20:42:00+00', 'fact'),
  ('e1000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000003',
   'a1000000-0000-4000-8000-000000000001', 'manual',
   '{"summary": "8:47 PM — Riverside Store alarm triggered"}',
   '2026-09-10 20:47:00+00', 'fact'),
  ('e1000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000003',
   'a1000000-0000-4000-8000-000000000001', 'manual',
   '{"summary": "8:51 PM — Police notified by Store Owner"}',
   '2026-09-10 20:51:00+00', 'fact'),
  ('e1000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000003',
   'a1000000-0000-4000-8000-000000000001', 'manual',
   '{"summary": "Witness C reports seeing a person enter via the rear entrance"}',
   '2026-09-10 21:10:00+00', 'claim')
on conflict (id) do nothing;

-- Alibi: Suspect A claims home 8:30–9:00 PM — conflicts with CCTV (doc §14).
insert into public.alibis (
  room_id, entity_id, claimed_window_start, claimed_window_end,
  claim_text, source, status, status_reason, created_by
)
values
  ('b1000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000001',
   '2026-09-10 20:30:00+00', '2026-09-10 21:00:00+00',
   'Suspect A claims he was at home from 8:30 to 9:00 PM',
   'statement', 'conflict',
   'CCTV places Vehicle V01 (registered to Suspect A) at Riverside Road at 8:42 PM',
   'a1000000-0000-4000-8000-000000000001')
on conflict do nothing;

insert into public.alibi_evidence_links (alibi_id, evidence_item_id, relation)
select a.id, 'c1000000-0000-4000-8000-000000000011', 'conflicts'
from public.alibis a
where a.claim_text like 'Suspect A claims he was at home%'
on conflict do nothing;

-- Contradiction: witness statement vs CCTV record (doc §15).
insert into public.contradictions (
  room_id, source_type, conflicting_detail, flagged_reason, status, flagged_by
)
values
  ('b1000000-0000-4000-8000-000000000003', 'manual',
   'Witness B says the van arrived "around 9 PM"; CCTV shows Vehicle V01 at 8:42 PM',
   'Statement timing conflicts with the CCTV record',
   'open', 'a1000000-0000-4000-8000-000000000001')
on conflict do nothing;

insert into public.contradiction_sources (contradiction_id, evidence_item_id)
select c.id, 'c1000000-0000-4000-8000-000000000013'
from public.contradictions c where c.flagged_reason like 'Statement timing%'
on conflict do nothing;

insert into public.contradiction_sources (contradiction_id, evidence_item_id)
select c.id, 'c1000000-0000-4000-8000-000000000011'
from public.contradictions c where c.flagged_reason like 'Statement timing%'
on conflict do nothing;

-- Investigation gaps (doc §16): missing puzzle pieces, one becomes a task.
insert into public.investigation_gaps (
  room_id, gap_type, description, source_type, status, created_by
)
values
  ('b1000000-0000-4000-8000-000000000003', 'unknown_person',
   'Driver of Vehicle V01 at 8:42 PM is not confirmed — Suspect A or an associate?',
   'manual', 'open', 'a1000000-0000-4000-8000-000000000001'),
  ('b1000000-0000-4000-8000-000000000003', 'missing_evidence',
   'No CCTV coverage of the rear entrance before 8:45 PM',
   'manual', 'open', 'a1000000-0000-4000-8000-000000000001')
on conflict do nothing;

insert into public.tasks (room_id, title, assignee_id, created_by, status)
values
  ('b1000000-0000-4000-8000-000000000003',
   'Identify the driver of Vehicle V01',
   'a1000000-0000-4000-8000-000000000002',
   'a1000000-0000-4000-8000-000000000001',
   'open')
on conflict do nothing;

insert into public.discussion_messages (room_id, author_id, body, mentions)
values
  ('b1000000-0000-4000-8000-000000000003',
   'a1000000-0000-4000-8000-000000000001',
   'Kickoff: @Elena please verify the CCTV timestamps against the alarm log.',
   array['a1000000-0000-4000-8000-000000000002']::uuid[])
on conflict do nothing;

-- Audit entry so the vault mirror exists from first launch.
select public.append_audit(
  'b1000000-0000-4000-8000-000000000003',
  'a1000000-0000-4000-8000-000000000001',
  'evidence_uploaded', 'evidence_item',
  'c1000000-0000-4000-8000-000000000011',
  jsonb_build_object('filename', 'cctv-riverside-road-2042.mp4', 'version', 1)
);
