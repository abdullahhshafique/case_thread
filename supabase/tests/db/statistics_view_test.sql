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
insert into tests.fixtures (key, room_id)
select 'stats-x', (result).room_id from
public.create_case_room('Stats Room X', 'legal') as result;
insert into tests.fixtures (key, room_id)
select 'stats-y', (result).room_id from
public.create_case_room('Stats Room Y', 'legal') as result;

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
-- Evidence fixtures run as postgres (direct evidence inserts are
-- RPC-only for clients, 0009).
select tests.unimpersonate();
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
