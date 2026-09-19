-- RLS contract tests: investigation_gaps (0025 migration).
-- Members can read; edit_case holders can insert/update;
-- gap→task conversion via RPC.

begin;
select plan(10);

select tests.unimpersonate();
select tests.create_test_user('alex@example.com');
select tests.create_test_user('sam@example.com');
select tests.create_test_user('kai@example.com');

-- Setup: create the room via the generic RPC (impersonated as the
-- owner), then fixtures run as postgres.
select tests.impersonate('alex@example.com');
insert into tests.fixtures (key, room_id)
select 'gaps-room', (result).room_id
from public.create_case_room('Gaps Test Room', 'legal') as result;

select tests.unimpersonate();

select tests.impersonate('alex@example.com');
select is(
  count(*),
  1::bigint,
  'owner creates a room'
) from public.case_rooms cr
where cr.name = 'Gaps Test Room' and cr.owner_id = (
  select user_id from tests.fixtures where key = 'alex@example.com'
);

select tests.unimpersonate();
select tests.add_approved_member(
  (select id from public.case_rooms where name = 'Gaps Test Room'),
  'sam@example.com',
  'analyst'
);

select tests.impersonate('alex@example.com');
insert into public.entities (room_id, name, entity_type)
select cr.id, 'Kai Lee', 'person'
from public.case_rooms cr where cr.name = 'Gaps Test Room';

select tests.impersonate('sam@example.com');
-- 1. Member can read the (empty) gaps table.
select is(
  count(*),
  0::bigint,
  'member can read (empty) gaps table'
) from public.investigation_gaps where room_id = (
  select id from public.case_rooms where name = 'Gaps Test Room'
);

select tests.impersonate('alex@example.com');
-- 2. Owner can insert a gap.
insert into public.investigation_gaps (
  room_id, gap_type, description, source_type,
  status, created_by
)
select
  cr.id, 'missing_evidence', 'No contract on file',
  'manual', 'open',
  (select user_id from tests.fixtures where key = 'alex@example.com')
from public.case_rooms cr
where cr.name = 'Gaps Test Room';

select is(
  count(*),
  1::bigint,
  'owner insert succeeds'
) from public.investigation_gaps where description = 'No contract on file';

-- 3. Non-member cannot insert (RLS with check raises).
select tests.impersonate('kai@example.com');
select throws_ok(
  'insert into public.investigation_gaps (room_id, gap_type, '
  || 'description, source_type, status, created_by) select cr.id, '
  || '''missing_evidence'', ''X'', ''manual'', ''open'', '
  || '(select user_id from tests.fixtures where key = ''kai@example.com'') '
  || 'from public.case_rooms cr where cr.name = ''Gaps Test Room''',
  null,
  'non-member cannot insert gap'
);

select tests.impersonate('sam@example.com');
-- 4. Member with edit_case (analyst) can update gap status.
update public.investigation_gaps set status = 'in_progress'
where description = 'No contract on file';
select is(
  status,
  'in_progress',
  'member with edit_case can change gap status'
) from public.investigation_gaps where description = 'No contract on file';

select tests.impersonate('alex@example.com');
-- 5. gap_create_task RPC: create task + link + status change.
select public.gap_create_task(
  (select id from public.investigation_gaps
   where description = 'No contract on file'),
  'Fill contract gap'
);

select is(
  count(*),
  1::bigint,
  'gap_create_task creates a task'
) from public.tasks t
where t.title = 'Fill contract gap'
  and t.room_id = (select id from public.case_rooms where name = 'Gaps Test Room');

-- 6. Linked gap has linked_task_id set.
select is(
  (linked_task_id is not null),
  true,
  'gap linked_task_id set'
) from public.investigation_gaps where description = 'No contract on file';

-- 7. Task was created by the caller.
select is(
  (t.created_by = (select user_id from tests.fixtures where key = 'alex@example.com')),
  true,
  'task created_by is the RPC caller'
) from public.tasks t where t.title = 'Fill contract gap';

-- 8. gap_create_task with empty title rejected (tasks.title CHECK).
select throws_ok(
  'select public.gap_create_task('
  || '(select id from public.investigation_gaps '
  || 'where description = ''No contract on file''), '''')',
  null,
  'gap_create_task rejects empty title'
);

select tests.impersonate('kai@example.com');
-- 9. Non-member sees no gaps (RLS deny proof).
select is(
  count(*),
  0::bigint,
  'non-member sees no gaps'
) from public.investigation_gaps;

select * from finish();
rollback;
