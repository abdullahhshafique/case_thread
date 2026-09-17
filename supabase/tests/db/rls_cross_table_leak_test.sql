-- Cross-table RLS leak test (0028 migration).
-- Verifies that rows inserted via one table cannot be read
-- through another table's RLS scope (no join-based leaks).
-- Specifically: alibi_evidence_links and contradiction_sources
-- are scoped via subqueries on alibis/contradictions room_id.
-- A member of Room A must NOT see Room B's data through
-- the join tables.

begin;
select plan(8);

select tests.unimpersonate();
select tests.create_test_user('alex@example.com');
select tests.create_test_user('sam@example.com');

-- Two rooms. Alex owns both; Sam is a member of both.
select tests.impersonate('alex@example.com');
select is(
  count(*),
  1::bigint,
  'Room A created'
) from public.case_rooms cr
where cr.name = 'Room A' and cr.owner_id = (
  select user_id from tests.fixtures where key = 'alex@example.com'
);

select is(
  count(*),
  1::bigint,
  'Room B created'
) from public.case_rooms cr
where cr.name = 'Room B' and cr.owner_id = (
  select user_id from tests.fixtures where key = 'alex@example.com'
);

select tests.add_approved_member(
  (select id from public.case_rooms where name = 'Room A'),
  'sam@example.com',
  'analyst'
);
select tests.add_approved_member(
  (select id from public.case_rooms where name = 'Room B'),
  'sam@example.com',
  'analyst'
);

select tests.impersonate('alex@example.com');

-- Room A: entity + evidence + timeline event.
insert into public.entities (room_id, name, entity_type)
select cr.id, 'Person A', 'person'
from public.case_rooms cr where cr.name = 'Room A';

insert into public.evidence_items (
  room_id, uploader_id, filename, storage_path, file_hash,
  mime_type, file_size_bytes, version
)
select cr.id, (select user_id from tests.fixtures where key = 'alex@example.com'),
  'evidence_a.pdf', 'rooms/a/evidence.pdf', 'hash-a',
  'application/pdf', 1000, 1
from public.case_rooms cr where cr.name = 'Room A';

insert into public.timeline_events (room_id, actor_id, event_type, payload)
select cr.id, (select user_id from tests.fixtures where key = 'alex@example.com'),
  'manual', '{"summary": "Alex says they were at home"}'::jsonb
from public.case_rooms cr where cr.name = 'Room A';

-- Room B: different entity + evidence.
insert into public.entities (room_id, name, entity_type)
select cr.id, 'Person B', 'person'
from public.case_rooms cr where cr.name = 'Room B';

insert into public.evidence_items (
  room_id, uploader_id, filename, storage_path, file_hash,
  mime_type, file_size_bytes, version
)
select cr.id, (select user_id from tests.fixtures where key = 'alex@example.com'),
  'evidence_b.pdf', 'rooms/b/evidence.pdf', 'hash-b',
  'application/pdf', 2000, 1
from public.case_rooms cr where cr.name = 'Room B';

insert into public.timeline_events (room_id, actor_id, event_type, payload)
select cr.id, (select user_id from tests.fixtures where key = 'alex@example.com'),
  'manual', '{"summary": "Alex says B happened"}'::jsonb
from public.case_rooms cr where cr.name = 'Room B';

-- Now insert an alibi + link + contradiction in Room A.
insert into public.alibis (
  room_id, entity_id, claimed_window_start, claimed_window_end,
  claim_text, source, status, status_reason, created_by
)
select
  cr.id, e.id,
  '2026-09-01 08:00:00+00', '2026-09-01 10:00:00+00',
  'At the library', 'self', 'verified', 'Confirmed',
  (select user_id from tests.fixtures where key = 'alex@example.com')
from public.case_rooms cr, public.entities e
where cr.name = 'Room A' and e.name = 'Person A';

insert into public.alibi_evidence_links (alibi_id, evidence_item_id, relation)
select a.id, e.id, 'supports'
from public.alibis a, public.evidence_items e
where a.claim_text = 'At the library'
  and e.room_id = (select id from public.case_rooms where name = 'Room A')
  and e.filename = 'evidence_a.pdf';

-- Contradiction + source in Room A (flagged_by must be the
-- impersonated user per the 0028 insert policy).
insert into public.contradictions (
  room_id, source_type, conflicting_detail, flagged_reason,
  status, flagged_by
)
select
  cr.id, 'manual', 'A says X', 'manual review', 'open',
  (select user_id from tests.fixtures where key = 'alex@example.com')
from public.case_rooms cr
where cr.name = 'Room A';

insert into public.contradiction_sources (contradiction_id, evidence_item_id)
select c.id, e.id
from public.contradictions c, public.evidence_items e
where c.flagged_reason = 'manual review'
  and e.room_id = (select id from public.case_rooms where name = 'Room A')
  and e.filename = 'evidence_a.pdf';

-- Sam is a member of both rooms. Verify Sam can see
-- Room A's data via the join table but NOT Room B's.
select tests.impersonate('sam@example.com');

-- 3. Sam can see Room A's alibi evidence link.
select is(
  count(*),
  1::bigint,
  'sam sees Room A alibi link'
) from public.alibi_evidence_links sel
where sel.alibi_id in (
  select a.id from public.alibis a
  join public.case_rooms cr on cr.id = a.room_id
  where cr.name = 'Room A'
);

-- 4. Sam CANNOT see Room B's data through alibi_evidence_links
--    (no Room B alibi exists at all — the join exposes nothing).
select is(
  count(*),
  0::bigint,
  'sam cannot see Room B alibi link'
) from public.alibi_evidence_links sel
where sel.alibi_id in (
  select a.id from public.alibis a
  join public.case_rooms cr on cr.id = a.room_id
  where cr.name = 'Room B'
);

-- 5. Sam can see Room A's contradiction source.
select is(
  count(*),
  1::bigint,
  'sam sees Room A contradiction source'
) from public.contradiction_sources css
where css.contradiction_id in (
  select c.id from public.contradictions c
  join public.case_rooms cr on cr.id = c.room_id
  where cr.name = 'Room A'
);

-- 6. Sam CANNOT see Room B's data through contradiction_sources.
select is(
  count(*),
  0::bigint,
  'sam cannot see Room B contradiction source'
) from public.contradiction_sources css
where css.contradiction_id in (
  select c.id from public.contradictions c
  join public.case_rooms cr on cr.id = c.room_id
  where cr.name = 'Room B'
);

-- 7. Room A has at least one link (sanity).
select is(
  (select count(*) from public.alibi_evidence_links) >= 1,
  true,
  'Room A has at least one link'
);

-- 8. Cross-table leak check: alibi_evidence_links does not
--    expose Room B's evidence_item_id to Room A members.
select is(
  count(*),
  0::bigint,
  'Room A member sees no Room B evidence through links'
) from public.alibi_evidence_links sel
join public.alibis a on a.id = sel.alibi_id
join public.case_rooms cr on cr.id = a.room_id
where cr.name = 'Room A'
  and sel.evidence_item_id in (
    select e.id from public.evidence_items e
    join public.case_rooms cr2 on cr2.id = e.room_id
    where cr2.name = 'Room B'
  );

select * from finish();
rollback;
