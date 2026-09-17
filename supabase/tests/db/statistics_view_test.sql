-- Statistics view test (0026 migration).
-- Verifies v_case_statistics() returns correct counts per room
-- AND that the security_invoker does NOT leak counts for
-- rooms the caller is not a member of.

begin;
select plan(11);

select tests.unimpersonate();
select tests.create_test_user('alex@example.com');
select tests.create_test_user('sam@example.com');

-- Two rooms with different content.
select tests.impersonate('alex@example.com');
select is(
  count(*),
  1::bigint,
  'Room X created'
) from public.case_rooms cr
where cr.name = 'Stats Room X' and cr.owner_id = (
  select user_id from tests.fixtures where key = 'alex@example.com'
);

select is(
  count(*),
  1::bigint,
  'Room Y created'
) from public.case_rooms cr
where cr.name = 'Stats Room Y' and cr.owner_id = (
  select user_id from tests.fixtures where key = 'alex@example.com'
);

select tests.add_approved_member(
  (select id from public.case_rooms where name = 'Stats Room X'),
  'sam@example.com',
  'analyst'
);

select tests.impersonate('alex@example.com');
-- Populate Room X: 1 evidence item, 1 person entity,
-- 1 timeline event, 0 contradictions, 0 gaps, 0 alibis.
insert into public.evidence_items (
  room_id, uploader_id, filename, storage_path, file_hash,
  mime_type, file_size_bytes, version
)
select cr.id, (select user_id from tests.fixtures where key = 'alex@example.com'),
  'doc_a.pdf', 'rooms/x/doc_a.pdf', 'hash-a',
  'application/pdf', 500, 1
from public.case_rooms cr where cr.name = 'Stats Room X';

select is(
  count(*),
  1::bigint,
  'Room X evidence inserted'
) from public.evidence_items ei
where ei.room_id = (select id from public.case_rooms where name = 'Stats Room X')
  and ei.filename = 'doc_a.pdf';

insert into public.entities (room_id, name, entity_type)
select cr.id, 'Person X', 'person'
from public.case_rooms cr where cr.name = 'Stats Room X';

insert into public.timeline_events (room_id, actor_id, event_type, payload)
select cr.id, (select user_id from tests.fixtures where key = 'alex@example.com'),
  'manual', '{"summary": "test"}'::jsonb
from public.case_rooms cr where cr.name = 'Stats Room X';

-- Room Y is empty (no evidence, no people, no events).
select tests.impersonate('sam@example.com');

-- 4. Sam is a member of Room X, can call the statistics function.
select is(
  count(*),
  1::bigint,
  'sam can call v_case_statistics'
) from public.v_case_statistics() s
where s.room_id = (select id from public.case_rooms where name = 'Stats Room X');

-- 5. Sam cannot see Room Y in statistics (not a member).
select is(
  count(*),
  0::bigint,
  'sam cannot see Room Y stats (no leak)'
) from public.v_case_statistics() s
where s.room_id = (select id from public.case_rooms where name = 'Stats Room Y');

select tests.impersonate('alex@example.com');
-- 6. Owner can see both rooms' stats.
select is(
  count(*),
  2::bigint,
  'owner sees both rooms'
) from public.v_case_statistics() s;

select tests.impersonate('sam@example.com');
-- 7. Sam sees Room X only.
select is(
  count(*),
  1::bigint,
  'sam sees only Room X'
) from public.v_case_statistics() s;

-- 8. Evidence count is correct.
select is(
  s.evidence_count,
  1::bigint,
  'Room X has 1 evidence item'
) from public.v_case_statistics() s
where s.room_id = (select id from public.case_rooms where name = 'Stats Room X');

select tests.impersonate('alex@example.com');
insert into public.evidence_items (
  room_id, uploader_id, filename, storage_path, file_hash,
  mime_type, file_size_bytes, version
)
select cr.id, (select user_id from tests.fixtures where key = 'alex@example.com'),
  'doc_b.pdf', 'rooms/x/doc_b.pdf', 'hash-b',
  'application/pdf', 500, 1
from public.case_rooms cr where cr.name = 'Stats Room X';

-- 9. After adding a second evidence, count = 2.
select tests.impersonate('sam@example.com');
select is(
  s.evidence_count,
  2::bigint,
  'Room X now has 2 evidence items'
) from public.v_case_statistics() s
where s.room_id = (select id from public.case_rooms where name = 'Stats Room X');

-- 10. Statistics columns exist with correct types.
select is(
  pg_typeof(s.contradictions_count)::text,
  'bigint',
  'contradictions_count is bigint'
) from public.v_case_statistics() s limit 1;

select is(
  pg_typeof(s.ai_findings_count)::text,
  'bigint',
  'ai_findings_count is bigint'
) from public.v_case_statistics() s limit 1;

select * from finish();
rollback;
