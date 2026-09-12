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
