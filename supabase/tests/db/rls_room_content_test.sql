-- RLS contract tests: evidence, tasks, discussion, timeline, AI-suggestions
-- (0002/0005 migrations). Permission-key gating is exercised per role.

begin;
select plan(9);

select tests.unimpersonate();
select tests.create_test_user('lead@example.com') as lead_id \gset
select tests.create_test_user('analyst@example.com') as analyst_id \gset
select tests.create_test_user('observer@example.com') as observer_id \gset
select tests.create_test_user('outsider@example.com') as outsider_id \gset

insert into public.case_rooms (name, case_type, owner_id, access_code_hash)
values ('Evidence Test Room', 'legal', :'lead_id', 'hash')
returning id as room \gset

select tests.add_approved_member(:room, :'lead_id', 'lead_investigator');
select tests.add_approved_member(:room, :'analyst_id', 'analyst');
select tests.add_approved_member(:room, :'observer_id', 'observer');

-- Fixtures inserted as postgres (direct table access).
insert into public.evidence_items (
  room_id, uploader_id, filename, storage_path, file_hash, file_size_bytes
) values (
  :room, :'lead_id', 'contract.pdf', 'rooms/evidence-test/contract.pdf',
  'abc123', 1024
) returning id as evidence_id \gset;

insert into public.tasks (room_id, title, created_by)
values (:room, 'Review contract', :'lead_id');

insert into public.discussion_messages (room_id, author_id, body)
values (:room, :'lead_id', 'First substantive comment.');

insert into public.timeline_events (room_id, event_type, actor_id, payload)
values (:room, 'manual', :'lead_id', '{"summary":"Case opened"}');

insert into public.ai_suggestions (room_id, agent_type, output)
values (:room, 'contradiction_checker', '{"finding":"possible discrepancy"}');

-- 1. All approved members can see evidence (view_case covers reads).
select tests.impersonate(:'observer_id');
select is(
  count(*),
  1::bigint,
  'observer (member) can read evidence'
) from public.evidence_items where room_id = :room;

-- 2. Observer CANNOT upload (upload_evidence = false).
insert into public.evidence_items (
  room_id, uploader_id, filename, storage_path, file_hash, file_size_bytes
) values (
  :room, :'observer_id', 'sneak.pdf', 'rooms/evidence-test/sneak.pdf', 'x', 1
);
select is(
  count(*),
  0::bigint,
  'observer upload is rejected (upload_evidence false)'
) from public.evidence_items where storage_path like '%sneak%';

-- 3. Analyst CAN upload.
select tests.impersonate(:'analyst_id');
insert into public.evidence_items (
  room_id, uploader_id, filename, storage_path, file_hash, file_size_bytes
) values (
  :room, :'analyst_id', 'bank_records.csv', 'rooms/evidence-test/bank_records.csv',
  'def456', 2048
);
select is(
  count(*),
  1::bigint,
  'analyst upload succeeds (upload_evidence true)'
) from public.evidence_items where storage_path like '%bank_records%';

-- 4. Non-member sees nothing in any content table.
select tests.impersonate(:'outsider_id');
select is(
  count(*),
  0::bigint,
  'non-member: no evidence visible'
) from public.evidence_items where room_id = :room;
select is(
  count(*),
  0::bigint,
  'non-member: no tasks visible'
) from public.tasks where room_id = :room;
select is(
  count(*),
  0::bigint,
  'non-member: no discussion visible'
) from public.discussion_messages where room_id = :room;

-- 5. Observer cannot comment (comment = false).
select tests.impersonate(:'observer_id');
insert into public.discussion_messages (room_id, author_id, body)
values (:room, :'observer_id', 'Observer tries to comment.');
select is(
  count(*),
  0::bigint,
  'observer comment rejected (comment false)'
) from public.discussion_messages where author_id = :'observer_id';

-- 6. Observer cannot create tasks or timeline events (edit_case false).
insert into public.tasks (room_id, title, created_by)
values (:room, 'Sneak task', :'observer_id');
select is(
  count(*),
  0::bigint,
  'observer task creation rejected (edit_case false)'
) from public.tasks where created_by = :'observer_id';

insert into public.timeline_events (room_id, event_type, actor_id, payload)
values (:room, 'manual', :'observer_id', '{"summary":"sneak"}');
select is(
  count(*),
  0::bigint,
  'observer manual timeline event rejected'
) from public.timeline_events where actor_id = :'observer_id';

-- 7. Analyst can create tasks + manual timeline events (edit_case true).
select tests.impersonate(:'analyst_id');
insert into public.tasks (room_id, title, created_by)
values (:room, 'Analyst task', :'analyst_id');
select is(
  count(*),
  1::bigint,
  'analyst task creation succeeds (edit_case true)'
) from public.tasks where created_by = :'analyst_id';

insert into public.timeline_events (room_id, event_type, actor_id, payload)
values (:room, 'manual', :'analyst_id', '{"summary":"analyst event"}');
select is(
  count(*),
  1::bigint,
  'analyst manual timeline event succeeds'
) from public.timeline_events
where actor_id = :'analyst_id' and event_type = 'manual';

-- 8. Client cannot INSERT ai_suggestions directly (no policy — Phase 3
-- agents insert via Edge Functions only).
select tests.impersonate(:'lead_id');
select throws_ok(
  'insert into public.ai_suggestions (room_id, agent_type, output) '
    || 'values (' || quote_literal(:room) || ', ''fake_agent'', ''{}'')',
  null,
  'direct ai_suggestions INSERT is not permitted (no client policy)'
);

-- 9. Member reads ai_suggestions are allowed (view_case).
select is(
  count(*),
  1::bigint,
  'member can read ai_suggestions for their room'
) from public.ai_suggestions where room_id = :room;

select * from finish();
rollback;
