-- Investigation status + closed summary test (0026 migration).
-- Verifies transition_investigation_status transitions
-- correctly and generates a case_closed_summary on →closed.

begin;
select plan(9);

select tests.unimpersonate();
select tests.create_test_user('alex@example.com');
select tests.create_test_user('sam@example.com');
select tests.create_test_user('kai@example.com');

select tests.impersonate('alex@example.com');

-- The room is created via the generic RPC (config-driven; the tests
-- reference it by name below).
insert into tests.fixtures (key, room_id)
select 'status-room', (result).room_id
from public.create_case_room('Status Room', 'legal') as result;
select is(
  count(*),
  1::bigint,
  'Room created'
) from public.case_rooms cr
where cr.name = 'Status Room' and cr.owner_id = (
  select user_id from tests.fixtures where key = 'alex@example.com'
);

-- Sam must be a member to read the room row (RLS). Fixture writes run
-- as postgres.
select tests.unimpersonate();
select tests.add_approved_member(
  (select id from public.case_rooms where name = 'Status Room'),
  'sam@example.com',
  'analyst'
);

-- Default status is open.
select tests.impersonate('sam@example.com');
select is(
  cr.investigation_status,
  'open',
  'default investigation status is open'
) from public.case_rooms cr
where cr.name = 'Status Room';

-- Non-member cannot transition (RPC raises).
select tests.impersonate('kai@example.com');
select throws_ok(
  'select public.transition_investigation_status('
  || '(select id from public.case_rooms where name = ''Status Room''), '
  || '''under_investigation'')',
  null,
  'non-member cannot transition status'
);

-- Owner transitions to under_investigation.
select tests.impersonate('alex@example.com');
select public.transition_investigation_status(
  (select id from public.case_rooms where name = 'Status Room'),
  'under_investigation'
);

select is(
  cr.investigation_status,
  'under_investigation',
  'status → under_investigation'
) from public.case_rooms cr
where cr.name = 'Status Room';

-- Transition to review.
select public.transition_investigation_status(
  (select id from public.case_rooms where name = 'Status Room'),
  'review'
);
select is(
  cr.investigation_status,
  'review',
  'status → review'
) from public.case_rooms cr
where cr.name = 'Status Room';

-- Transition to closed → should generate case_closed_summary.
select public.transition_investigation_status(
  (select id from public.case_rooms where name = 'Status Room'),
  'closed'
);

select is(
  cr.investigation_status,
  'closed',
  'status → closed'
) from public.case_rooms cr
where cr.name = 'Status Room';

select is(
  count(*),
  1::bigint,
  'case_closed_summary auto-generated on close'
) from public.case_closed_summaries cs
where cs.room_id = (select id from public.case_rooms where name = 'Status Room');

-- Verify summary JSONB has required fields.
select is(
  (cs.summary_json ? 'case_overview'),
  true,
  'summary contains case_overview'
) from public.case_closed_summaries cs
where cs.room_id = (select id from public.case_rooms where name = 'Status Room');

select is(
  (cs.summary_json->'case_overview' ? 'investigation_status'),
  true,
  'summary case_overview contains investigation_status'
) from public.case_closed_summaries cs
where cs.room_id = (select id from public.case_rooms where name = 'Status Room');

select * from finish();
rollback;
