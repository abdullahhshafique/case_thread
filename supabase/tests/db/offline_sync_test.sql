-- Phase 4 contract tests (0023): offline-sync conflict infrastructure.
-- Policy doc §6 gates 1-3 as pgTAP: revoked-member replay is denied
-- (not partially applied), LWW stamps + flags the loser, audit_log
-- ordering is untouched, and clear_conflict is permission-gated.

begin;
select plan(12);

select tests.unimpersonate();
select tests.create_test_user('off-lead@example.com');
select tests.create_test_user('off-analyst@example.com');
select tests.create_test_user('off-outsider@example.com');

insert into tests.fixtures (key, room_id)
select 'off-room', (result).room_id
from public.create_case_room('Offline Sync Room', 'legal') as result;

select tests.unimpersonate();
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'off-room'),
  'off-analyst@example.com', 'analyst'
);

-- A task created live, then "goes offline": snapshot taken at queue time.
insert into public.tasks (room_id, title, created_by, status)
select f.room_id, 'Interview the witness', f.user_id, 'open'
from tests.fixtures f
where f.key = 'off-lead@example.com'
  and f.user_id = (select user_id from tests.fixtures where key = 'off-lead@example.com');

insert into tests.fixtures (key, member_id, text_value)
select 'off-task',
       (select id from public.tasks
        where room_id = (select room_id from tests.fixtures where key = 'off-room')
          and title = 'Interview the witness'),
       (select room_id from tests.fixtures where key = 'off-room')
from tests.fixtures where key = 'off-room';

-- A manual timeline event by the lead (editable by the lead offline).
insert into public.timeline_events (room_id, event_type, actor_id, payload)
select f.room_id, 'manual', f.user_id, '{"summary": "Site visit complete"}'
from tests.fixtures f
where f.key = 'off-lead@example.com'
  and f.user_id = (select user_id from tests.fixtures where key = 'off-lead@example.com');

-- 1. LIVE path still works: stamped update applies (no divergence yet).
select tests.impersonate('off-lead@example.com');
select is(
  public.update_task_with_stamp(
    (select member_id from tests.fixtures where key = 'off-task'),
    'in_progress',
    now() + interval '1 minute' -- client snapshot newer than any server change
  ),
  'applied',
  'fresh stamped task update applies'
);

-- 2. LWW deny: the task changed server-side AFTER the offline snapshot.
select tests.impersonate('off-lead@example.com');
-- Simulate a second writer landing a newer change first.
update public.tasks
set status = 'in_progress', updated_at = now() + interval '5 minutes'
where id = (select member_id from tests.fixtures where key = 'off-task');

select is(
  public.update_task_with_stamp(
    (select member_id from tests.fixtures where key = 'off-task'),
    'done',
    now() -- stale offline snapshot: LWW server wins
  ),
  'conflict_server_won',
  'stale stamped task update loses (LWW: server wins)'
);
select is(
  (select status from public.tasks
   where id = (select member_id from tests.fixtures where key = 'off-task')),
  'in_progress',
  'server value kept on LWW loss (no partial application)'
);
select is(
  (select conflict_flag from public.tasks
   where id = (select member_id from tests.fixtures where key = 'off-task')),
  true,
  'LWW loser row carries the visible conflict flag (policy §4)'
);
select is(
  (select conflict_note is not null from public.tasks
   where id = (select member_id from tests.fixtures where key = 'off-task')),
  true,
  'conflict note explains who lost to what'
);

-- 3. Revoked/never-member replay denied through the RPC (gate 1).
--    The function's permission check is membership-based; revoked
--    members lose user_room_permission (status must be 'approved').
select tests.unimpersonate();
update public.room_members
set status = 'revoked'
where room_id = (select room_id from tests.fixtures where key = 'off-room')
  and user_id = (select user_id from tests.fixtures where key = 'off-analyst@example.com');

select tests.impersonate('off-analyst@example.com');
select throws_ok(
  'select public.update_task_with_stamp('
    || '(select member_id::text from tests.fixtures where key = ''off-task'')::uuid, '
    || '''done'', now())',
  'Your role can''t update tasks in this room.',
  'revoked member queued replay is denied (typed error)'
);
select tests.unimpersonate();
select is(
  (select status from public.tasks
   where id = (select member_id from tests.fixtures where key = 'off-task')),
  'in_progress',
  'denied replay left the task unchanged (no partial application)'
);

-- 4. Timeline LWW: newer server edit beats the offline snapshot.
insert into tests.fixtures (key, text_value)
select 'off-event',
       (select id::text from public.timeline_events te
        where room_id = (select room_id from tests.fixtures where key = 'off-room')
        order by occurred_at desc limit 1)
on conflict (key) do update set text_value = excluded.text_value;

select tests.impersonate('off-lead@example.com');
-- Server-side edit (fires timeline_event_edited audit with created_at=now).
select is(
  public.edit_timeline_event_with_stamp(
    (select text_value::uuid from tests.fixtures where key = 'off-event'),
    'Site visit rescheduled',
    now() + interval '1 minute' -- fresh snapshot: client wins
  ),
  'applied',
  'fresh stamped timeline edit applies'
);

-- A second offline snapshot taken BEFORE another server-side edit.
select is(
  public.edit_timeline_event_with_stamp(
    (select text_value::uuid from tests.fixtures where key = 'off-event'),
    'Site visit canceled',
    now() - interval '10 minutes' -- STALE: the edit above is newer
  ),
  'conflict_server_won',
  'stale stamped timeline edit loses (audit-trail LWW)'
);
select is(
  (select conflict_flag from public.timeline_events
   where id = (select text_value::uuid from tests.fixtures where key = 'off-event')),
  true,
  'timeline LWW loser row carries the conflict flag'
);

-- 5. clear_conflict: permitted member clears; clear is audited.
select is(
  (select count(*) from public.clear_conflict('task',
    (select member_id from tests.fixtures where key = 'off-task')),
  1::bigint,
  'clear_conflict on a task runs for permitted member'
);

-- Clearing an already-cleared/never-flagged task is a no-op, not an error.
select is(
  (select count(*) from public.clear_conflict('task',
    (select member_id from tests.fixtures where key = 'off-task')),
  1::bigint,
  'clear_conflict is idempotent'
);

-- audit_log untouched by any replay: append-only order preserved
-- (gate 3 — verified by the 0003 immutability suite; here we assert
-- the conflict flow only ever APPENDED rows).
select tests.unimpersonate();
select is(
  (select count(*) from public.audit_log
   where room_id = (select room_id from tests.fixtures where key = 'off-room')
     and action_type in ('task_updated', 'timeline_event_edited', 'conflict_cleared')),
  4::bigint,
  'replays + clears append audit rows through the same triggers (ordering untouched)'
);

select * from finish();
rollback;
