-- Sprint 6 contract test: the Academic case-type flow, end-to-end,
-- entirely on config data from 0004 — ZERO schema/code changes.
-- This is the "one core, many configs" architecture gate
-- (ExecutionPlan.md Sprint 6: needing a migration here is a red flag).

begin;
select plan(10);

select tests.unimpersonate();
select tests.create_test_user('ac-officer@example.com');
select tests.create_test_user('ac-respondent@example.com');
select tests.create_test_user('ac-witness@example.com');

-- 1. Academic room via the same generic RPC — owner becomes the
--    case type's configured owner-default role (integrity_officer).
select tests.impersonate('ac-officer@example.com');
insert into tests.fixtures (key, room_id)
select 'ac-room', (result).room_id
from public.create_case_room('CHEM-201 Final Integrity Case', 'academic') as result;

select is(
  role_id,
  'integrity_officer',
  'academic creator auto-approved with configured owner-default role'
) from public.room_members
where room_id = (select room_id from tests.fixtures where key = 'ac-room')
  and user_id = (select user_id from tests.fixtures where key = 'ac-officer@example.com');

-- 2. Academic roles resolve for the join flow (0004 config rows).
select is(
  count(*),
  5::bigint,
  'academic case type exposes its 5 configured roles'
) from public.roles
where case_type = 'academic';

-- 3. A witness joins room 2 by code — the generic join flow against
-- the academic config (role list from 0004).
insert into tests.fixtures (key, room_id, text_value)
select 'ac-room2', (result).room_id, (result).access_code
from public.create_case_room('Academic Flow Second Room', 'academic') as result;

select tests.impersonate('ac-witness@example.com');
insert into tests.fixtures (key, member_id, text_value)
select 'ac-join2', member_id, member_status
from public.request_room_join(
  (select text_value from tests.fixtures where key = 'ac-room2'),
  'witness'
);

select is(
  text_value,
  'pending',
  'academic witness join lands pending (generic flow, academic config)'
) from tests.fixtures where key = 'ac-join2';

-- 4. Officer approves; witness sees the room. Room 2's owner is the
-- same officer (the RPC ran while impersonated as them).
select tests.unimpersonate();
select tests.impersonate('ac-officer@example.com');
select public.decide_join_request(
  (select room_id from tests.fixtures where key = 'ac-room2'),
  (select member_id from tests.fixtures where key = 'ac-join2'),
  'approved'
);

select tests.impersonate('ac-witness@example.com');
select is(
  count(*),
  1::bigint,
  'approved academic witness reads the room'
) from public.case_rooms
where id = (select room_id from tests.fixtures where key = 'ac-room2');

-- 5. Witness permissions come from the CONFIG grid: witness can upload
--    evidence (upload_evidence true) — via the sanctioned 0009 RPC,
--    which re-checks the permission key against the config grid.
select is(
  (r).version_no,
  1,
  'witness uploads evidence via RPC (config: upload_evidence true)'
)
from public.register_evidence(
  (select room_id from tests.fixtures where key = 'ac-room2'),
  'statement.txt',
  'rooms/' || (select room_id::text from tests.fixtures where key = 'ac-room2') || '/statement.txt',
  'text/plain', 100,
  repeat('1', 64)
) as r;

select throws_ok(
  'insert into public.discussion_messages (room_id, author_id, body) '
    || 'select (select room_id from tests.fixtures where key = ''ac-room2''), '
    || 'auth.uid(), ''witness tries to comment'''
    || '',
  'new row violates row-level security policy for table "discussion_messages"',
  'witness comment rejected (config: comment false)'
);

-- 6. Witness cannot create tasks (edit_case false in the config grid).
select throws_ok(
  'insert into public.tasks (room_id, title, created_by) '
    || 'select (select room_id from tests.fixtures where key = ''ac-room2''), '
    || '''Sneak task'', auth.uid()',
  'new row violates row-level security policy for table "tasks"',
  'witness task creation rejected (config: edit_case false)'
);

-- 7. Timeline mirror worked for the academic room (generic 0010 trigger).
select is(
  count(*) >= 1,
  true,
  'academic room creation mirrored to timeline (generic trigger)'
) from public.timeline_events
where room_id = (select room_id from tests.fixtures where key = 'ac-room2')
  and event_type = 'system';

-- 8. Permission helper agrees with the config grid for the witness.
select is(
  public.user_room_permission(
    (select room_id from tests.fixtures where key = 'ac-room2'),
    'comment'
  ),
  false,
  'user_room_permission reads the CONFIG grid (witness: comment false)'
);

-- 9. Respondent on room 1 can see the room as an approved member
--    (added directly — membership mechanics already covered).
-- Fixture writes need superuser context (the helper inserts directly).
select tests.unimpersonate();
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'ac-room'),
  'ac-respondent@example.com', 'respondent'
);
select tests.impersonate('ac-respondent@example.com');
select is(
  count(*),
  1::bigint,
  'respondent (approved member) reads the academic room'
) from public.case_rooms
where id = (select room_id from tests.fixtures where key = 'ac-room');

select * from finish();
rollback;
