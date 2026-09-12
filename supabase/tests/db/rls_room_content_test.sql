-- RLS contract tests: evidence, tasks, discussion, timeline, AI-suggestions.
-- Permission-key gating exercised per role. No psql metacommands.

begin;
select plan(15);

select tests.unimpersonate();
select tests.create_test_user('lead@example.com');
select tests.create_test_user('analyst@example.com');
select tests.create_test_user('observer@example.com');
select tests.create_test_user('outsider@example.com');

insert into public.case_rooms (name, case_type, owner_id, access_code_hash)
select 'Evidence Test Room', 'legal', user_id, 'hash'
from tests.fixtures where key = 'lead@example.com';

select tests.add_approved_member(
  (select id from public.case_rooms where name = 'Evidence Test Room'),
  'lead@example.com', 'lead_investigator'
);
select tests.add_approved_member(
  (select id from public.case_rooms where name = 'Evidence Test Room'),
  'analyst@example.com', 'analyst'
);
select tests.add_approved_member(
  (select id from public.case_rooms where name = 'Evidence Test Room'),
  'observer@example.com', 'observer'
);

-- Fixtures inserted as postgres (direct table access; RLS bypassed as
-- superuser — legitimate for seeding).
insert into public.evidence_items (
  room_id, uploader_id, filename, storage_path, file_hash, file_size_bytes
)
select cr.id, f.user_id, 'contract.pdf',
       'rooms/' || cr.id::text || '/contract.pdf',
       repeat('1', 64), 1024
from public.case_rooms cr, tests.fixtures f
where cr.name = 'Evidence Test Room' and f.key = 'lead@example.com';

insert into public.tasks (room_id, title, created_by)
select cr.id, 'Review contract', f.user_id
from public.case_rooms cr, tests.fixtures f
where cr.name = 'Evidence Test Room' and f.key = 'lead@example.com';

insert into public.discussion_messages (room_id, author_id, body)
select cr.id, f.user_id, 'First substantive comment.'
from public.case_rooms cr, tests.fixtures f
where cr.name = 'Evidence Test Room' and f.key = 'lead@example.com';

insert into public.timeline_events (room_id, event_type, actor_id, payload)
select cr.id, 'manual', f.user_id, '{"summary":"Case opened"}'
from public.case_rooms cr, tests.fixtures f
where cr.name = 'Evidence Test Room' and f.key = 'lead@example.com';

insert into public.ai_suggestions (room_id, agent_type, output)
select cr.id, 'contradiction_checker', '{"finding":"possible discrepancy"}'
from public.case_rooms cr
where cr.name = 'Evidence Test Room';

-- 1. All approved members can see evidence (view_case covers reads).
select tests.impersonate('observer@example.com');
select is(
  count(*),
  1::bigint,
  'observer (member) can read evidence'
) from public.evidence_items
where filename = 'contract.pdf';

-- 2. Observer CANNOT upload — via the sanctioned RPC (0009 removed the
-- direct INSERT policy; the RPC enforces the upload_evidence key).
select throws_ok(
  'select * from public.register_evidence('
    || '(select cr.id::text from public.case_rooms cr where cr.name = ''Evidence Test Room'')::uuid, '
    || '''sneak.pdf'', '
    || '''rooms/'' || (select cr.id::text from public.case_rooms cr '
    || 'where cr.name = ''Evidence Test Room'') || ''/sneak.pdf'', '
    || '''application/pdf'', 1, repeat(''x'', 64))',
  'Your role cannot upload evidence in this room.'
);

select is(
  count(*),
  0::bigint,
  'observer upload is rejected (upload_evidence false)'
) from public.evidence_items where storage_path like '%sneak%';

-- 3. Analyst CAN upload — via the RPC (permitted role).
select tests.impersonate('analyst@example.com');
select is(
  (r).version_no,
  1,
  'analyst upload succeeds via RPC (upload_evidence true)'
)
from public.register_evidence(
  (select id from public.case_rooms where name = 'Evidence Test Room'),
  'bank_records.csv',
  'rooms/' || (select id::text from public.case_rooms where name = 'Evidence Test Room') || '/bank_records.csv',
  'text/plain', 2048,
  repeat('0', 64)
) as r;

select is(
  count(*),
  1::bigint,
  'analyst upload succeeds (upload_evidence true)'
) from public.evidence_items where storage_path like '%bank_records%';

-- 4. Non-member sees nothing in any content table.
select tests.impersonate('outsider@example.com');
select is(
  count(*),
  0::bigint,
  'non-member: no evidence visible'
) from public.evidence_items
where room_id in (select id from public.case_rooms where name = 'Evidence Test Room');
select is(
  count(*),
  0::bigint,
  'non-member: no tasks visible'
) from public.tasks
where room_id in (select id from public.case_rooms where name = 'Evidence Test Room');
select is(
  count(*),
  0::bigint,
  'non-member: no discussion visible'
) from public.discussion_messages
where room_id in (select id from public.case_rooms where name = 'Evidence Test Room');

-- 5. Observer cannot comment (comment = false).
select tests.impersonate('observer@example.com');
select throws_ok(
  'insert into public.discussion_messages (room_id, author_id, body) '
    || 'select cr.id, f.user_id, ''Observer tries to comment.'' '
    || 'from public.case_rooms cr, tests.fixtures f '
    || 'where cr.name = ''Evidence Test Room'' '
    || 'and f.key = ''observer@example.com''',
  'new row violates row-level security policy for table "discussion_messages"'
);

-- 6. Observer cannot create tasks or timeline events (edit_case false).
select throws_ok(
  'insert into public.tasks (room_id, title, created_by) '
    || 'select cr.id, ''Sneak task'', f.user_id '
    || 'from public.case_rooms cr, tests.fixtures f '
    || 'where cr.name = ''Evidence Test Room'' '
    || 'and f.key = ''observer@example.com''',
  'new row violates row-level security policy for table "tasks"'
);

select throws_ok(
  'insert into public.timeline_events (room_id, event_type, actor_id, payload) '
    || 'select cr.id, ''manual'', f.user_id, ''{"summary":"sneak"}'' '
    || 'from public.case_rooms cr, tests.fixtures f '
    || 'where cr.name = ''Evidence Test Room'' '
    || 'and f.key = ''observer@example.com''',
  'new row violates row-level security policy for table "timeline_events"'
);

-- 7. Analyst can create tasks + manual timeline events (edit_case true).
select tests.impersonate('analyst@example.com');
insert into public.tasks (room_id, title, created_by)
select cr.id, 'Analyst task', f.user_id
from public.case_rooms cr, tests.fixtures f
where cr.name = 'Evidence Test Room' and f.key = 'analyst@example.com';

select is(
  count(*),
  1::bigint,
  'analyst task creation succeeds (edit_case true)'
) from public.tasks t
join tests.fixtures f on f.user_id = t.created_by
  and f.key = 'analyst@example.com';

insert into public.timeline_events (room_id, event_type, actor_id, payload)
select cr.id, 'manual', f.user_id, '{"summary":"analyst event"}'
from public.case_rooms cr, tests.fixtures f
where cr.name = 'Evidence Test Room' and f.key = 'analyst@example.com';

select is(
  count(*),
  1::bigint,
  'analyst manual timeline event succeeds'
) from public.timeline_events te
join tests.fixtures f on f.user_id = te.actor_id
  and f.key = 'analyst@example.com'
where te.event_type = 'manual';

-- 8. Client cannot INSERT ai_suggestions directly (no policy — Phase 3
-- agents insert via Edge Functions only).
select tests.impersonate('lead@example.com');
select throws_ok(
  'insert into public.ai_suggestions (room_id, agent_type, output) '
    || 'select id, ''fake_agent'', ''{}''::jsonb from public.case_rooms '
    || 'where name = ''Evidence Test Room''',
  null,
  'direct ai_suggestions INSERT is not permitted (no client policy)'
);

-- 9. Member reads ai_suggestions are allowed (view_case).
select is(
  count(*),
  1::bigint,
  'member can read ai_suggestions for their room'
) from public.ai_suggestions
where room_id in (select id from public.case_rooms where name = 'Evidence Test Room');

select * from finish();
rollback;
