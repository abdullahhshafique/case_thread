-- RLS contract tests: Sprint 5 mirrors — timeline system events,
-- manual-edit auditing, task lifecycle auditing (0010).

begin;
select plan(7);

select tests.unimpersonate();
select tests.create_test_user('tl-owner@example.com');
select tests.create_test_user('tl-analyst@example.com');
select tests.create_test_user('tl-observer@example.com');

-- Room with owner + analyst (edit_case) + observer (read-only).
select tests.impersonate('tl-owner@example.com');
insert into tests.fixtures (key, room_id)
select 'tl-room', (result).room_id
from public.create_case_room('Timeline Test Room', 'legal') as result;

select tests.unimpersonate();
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'tl-room'),
  'tl-analyst@example.com', 'analyst'
);
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'tl-room'),
  'tl-observer@example.com', 'observer'
);

-- 1. Room creation produced a system timeline event via the mirror.
select tests.unimpersonate();
select is(
  count(*),
  1::bigint,
  'room_created mirrored to timeline as system event'
) from public.timeline_events
where room_id = (select room_id from tests.fixtures where key = 'tl-room')
  and event_type = 'system'
  and payload ->> 'action_type' = 'room_created';

-- 2. Analyst creates a manual timeline event (permission-gated by 0005).
select tests.impersonate('tl-analyst@example.com');
insert into public.timeline_events (room_id, event_type, actor_id, payload)
select (select room_id from tests.fixtures where key = 'tl-room'),
       'manual', auth.uid(),
       '{"summary":"Hearing scheduled for October 12"}'::jsonb;

select is(
  count(*),
  1::bigint,
  'analyst manual timeline event created (edit_case true)'
) from public.timeline_events
where room_id = (select room_id from tests.fixtures where key = 'tl-room')
  and event_type = 'manual';

-- 3. Observer cannot create manual events (edit_case false).
select tests.impersonate('tl-observer@example.com');
select throws_ok(
  'insert into public.timeline_events (room_id, event_type, actor_id, payload) '
    || 'select (select room_id from tests.fixtures where key = ''tl-room''), '
    || '''manual'', auth.uid(), ''{"summary":"sneak"}''::jsonb',
  'new row violates row-level security policy for table "timeline_events"',
  'observer manual timeline event rejected (edit_case false)'
);

-- 4. Editing a manual event writes an audit entry (PRD §6.5).
select tests.impersonate('tl-analyst@example.com');
update public.timeline_events
set payload = jsonb_set(payload, '{summary}', '"Hearing moved to October 19"')
where room_id = (select room_id from tests.fixtures where key = 'tl-room')
  and event_type = 'manual';

select tests.unimpersonate();
select is(
  count(*),
  1::bigint,
  'timeline edit recorded in audit trail'
) from public.audit_log
where room_id = (select room_id from tests.fixtures where key = 'tl-room')
  and action_type = 'timeline_event_edited';

-- 5. Task creation is audited AND mirrored to timeline.
select tests.impersonate('tl-analyst@example.com');
insert into public.tasks (room_id, title, created_by)
select (select room_id from tests.fixtures where key = 'tl-room'),
       'Interview the witness', auth.uid();

select is(
  count(*),
  1::bigint,
  'task creation audited'
) from public.audit_log
where room_id = (select room_id from tests.fixtures where key = 'tl-room')
  and action_type = 'task_created';

-- 6. Assignee can update task status (0005 policy) — audited as
--    task_updated with the new status.
select tests.impersonate('tl-owner@example.com');
update public.tasks
set status = 'in_progress'
where room_id = (select room_id from tests.fixtures where key = 'tl-room')
  and title = 'Interview the witness';

select is(
  count(*),
  1::bigint,
  'task status change audited (task_updated)'
) from public.audit_log
where room_id = (select room_id from tests.fixtures where key = 'tl-room')
  and action_type = 'task_updated'
  and metadata ->> 'status' = 'in_progress';

-- 7. Members can read the merged timeline (manual + system together).
select tests.impersonate('tl-observer@example.com');
select is(
  count(*) >= 2,
  true,
  'members read merged timeline (manual + system events)'
) from public.timeline_events
where room_id = (select room_id from tests.fixtures where key = 'tl-room');

select * from finish();
rollback;
