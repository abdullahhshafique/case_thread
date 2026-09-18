-- v_case_breakdown test (0033 migration).
-- Verifies evidence-by-type grouping and events-per-day windows are
-- correct and member-scoped (security invoker — no cross-room leak).

begin;
select plan(6);

select tests.unimpersonate();
select tests.create_test_user('alex@example.com');
select tests.create_test_user('sam@example.com');
select tests.create_test_user('kai@example.com');

select tests.impersonate('alex@example.com');
select is(
  count(*),
  1::bigint,
  'Room created'
) from public.case_rooms cr
where cr.name = 'Breakdown Room' and cr.owner_id = (
  select user_id from tests.fixtures where key = 'alex@example.com'
);

-- Fixture writes run as postgres (direct inserts; RLS denies them to
-- impersonated sessions).
select tests.unimpersonate();
select tests.add_approved_member(
  (select id from public.case_rooms where name = 'Breakdown Room'),
  'sam@example.com',
  'analyst'
);

select tests.impersonate('alex@example.com');
-- Two PDFs + one image.
insert into public.evidence_items (
  room_id, uploader_id, filename, storage_path, file_hash,
  mime_type, file_size_bytes, version
)
select cr.id, (select user_id from tests.fixtures where key = 'alex@example.com'),
  'doc' || g || '.pdf', 'rooms/x/doc' || g || '.pdf', 'h' || g,
  'application/pdf', 100, 1
from public.case_rooms cr, generate_series(1, 2) g
where cr.name = 'Breakdown Room';

insert into public.evidence_items (
  room_id, uploader_id, filename, storage_path, file_hash,
  mime_type, file_size_bytes, version
)
select cr.id, (select user_id from tests.fixtures where key = 'alex@example.com'),
  'photo.jpg', 'rooms/x/photo.jpg', 'h9',
  'image/jpeg', 100, 1
from public.case_rooms cr where cr.name = 'Breakdown Room';

-- One event today.
insert into public.timeline_events (room_id, actor_id, event_type, payload)
select cr.id, (select user_id from tests.fixtures where key = 'alex@example.com'),
  'manual', '{"summary": "today"}'
from public.case_rooms cr where cr.name = 'Breakdown Room';

select tests.impersonate('sam@example.com');
-- 2. Evidence by type groups correctly.
select is(
  (bd.evidence_by_type ->> 'pdf')::int,
  2,
  'evidence_by_type counts pdf = 2'
) from public.v_case_breakdown(
  (select id from public.case_rooms where name = 'Breakdown Room')
) bd;

select is(
  (bd.evidence_by_type ->> 'image')::int,
  1,
  'evidence_by_type counts image = 1'
) from public.v_case_breakdown(
  (select id from public.case_rooms where name = 'Breakdown Room')
) bd;

-- 3. Events-per-day includes today's event.
select is(
  jsonb_typeof(bd.events_per_day),
  'object',
  'events_per_day is an object'
) from public.v_case_breakdown(
  (select id from public.case_rooms where name = 'Breakdown Room')
) bd;

select tests.impersonate('kai@example.com');
-- 4. Non-member gets empty breakdowns (no leak).
select is(
  bd.evidence_by_type,
  '{}'::jsonb,
  'non-member evidence_by_type is empty'
) from public.v_case_breakdown(
  (select id from public.case_rooms where name = 'Breakdown Room')
) bd;

select is(
  bd.events_per_day,
  '{}'::jsonb,
  'non-member events_per_day is empty'
) from public.v_case_breakdown(
  (select id from public.case_rooms where name = 'Breakdown Room')
) bd;

select * from finish();
rollback;
