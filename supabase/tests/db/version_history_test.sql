-- Phase 4 contract tests (0024): version history over the audit log.
-- Member scoping (RLS deny proof), per-object-type rows, before/after
-- details, and the task-vs-timeline version numbering.

begin;
select plan(7);

select tests.unimpersonate();
select tests.create_test_user('hist-lead@example.com');
select tests.create_test_user('hist-analyst@example.com');
select tests.create_test_user('hist-outsider@example.com');

select tests.impersonate('hist-lead@example.com');
insert into tests.fixtures (key, room_id)
select 'hist-room', (result).room_id
from public.create_case_room('History Room', 'legal') as result;

select tests.unimpersonate();
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'hist-room'),
  'hist-analyst@example.com', 'analyst'
);

-- A task, created live by the lead (fires task_created audit).
select tests.impersonate('hist-lead@example.com');
insert into public.tasks (room_id, title, created_by)
select f.room_id, 'Draft the motion to compel', (select user_id from tests.fixtures where key = 'hist-lead@example.com')
from tests.fixtures f
where f.key = 'hist-room';

insert into tests.fixtures (key, member_id)
select 'hist-task',
       (select id from public.tasks
        where room_id = (select room_id from tests.fixtures where key = 'hist-room')
          and title = 'Draft the motion to compel')
from tests.fixtures where key = 'hist-room';

-- Status change through the sanctioned RPC (fires task_updated).
select public.update_task_with_stamp(
  (select member_id from tests.fixtures where key = 'hist-task'),
  'in_progress',
  now() + interval '1 minute'
);

-- A manual timeline event, then an edit (fires timeline_event_edited).
insert into public.timeline_events (room_id, event_type, actor_id, payload)
select f.room_id, 'manual', f.user_id, '{"summary": "Kickoff call held"}'
from tests.fixtures f
where f.key = 'hist-room'
  and f.user_id = (select user_id from tests.fixtures where key = 'hist-lead@example.com');

insert into tests.fixtures (key, text_value)
select 'hist-event',
       (select id::text from public.timeline_events
        where room_id = (select room_id from tests.fixtures where key = 'hist-room')
        order by occurred_at desc limit 1)
from tests.fixtures where key = 'hist-room';

select public.edit_timeline_event_with_stamp(
  (select text_value::uuid from tests.fixtures where key = 'hist-event'),
  'Kickoff call held; follow-up scheduled',
  now() + interval '1 minute'
);

-- 1. Members see the full task history: created + status change.
select tests.impersonate('hist-analyst@example.com');
select is(
  (select count(*) from public.list_versions('task',
    (select member_id from tests.fixtures where key = 'hist-task'))),
  2::bigint,
  'task history lists creation + status change'
);

-- 2. Version numbers ascend.
select is(
  (select min(version_no) from public.list_versions('task',
    (select member_id from tests.fixtures where key = 'hist-task'))),
  1,
  'task version numbering starts at 1'
);

-- 3. Task rows carry the before/after detail.
select is(
  (select detail from public.list_versions('task',
    (select member_id from tests.fixtures where key = 'hist-task'))
   where action = 'status_changed'),
  'Draft the motion to compel → in_progress',
  'task status detail shows the value change'
);

-- 4. Timeline event history: edits recorded with quoted summaries.
select is(
  (select count(*) from public.list_versions('timeline_event',
    (select text_value::uuid from tests.fixtures where key = 'hist-event'))),
  1::bigint,
  'timeline edit history lists the edit'
);
select is(
  (select detail from public.list_versions('timeline_event',
    (select text_value::uuid from tests.fixtures where key = 'hist-event'))),
  '"Kickoff call held" → "Kickoff call held; follow-up scheduled"',
  'timeline edit detail shows before → after'
);

-- 5. Outsiders see nothing (audit RLS member scoping — deny proof).
select tests.impersonate('hist-outsider@example.com');
select is(
  (select count(*) from public.list_versions('task',
    (select member_id from tests.fixtures where key = 'hist-task'))),
  0::bigint,
  'outsider sees zero history rows (RLS deny)'
);

-- 6. Unknown kinds are rejected with a typed error.
select throws_ok(
  'select public.list_versions(''room'', gen_random_uuid())',
  'Unknown versioned object kind: room',
  'unknown object kind rejected'
);

select * from finish();
rollback;
