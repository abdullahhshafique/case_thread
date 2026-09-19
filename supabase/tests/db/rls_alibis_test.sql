-- RLS contract tests: alibis (0025 migration).
-- Members can read; edit_case holders can insert/update;
-- non-members get no access. No psql metacommands.

begin;
select plan(10);

select tests.unimpersonate();
select tests.create_test_user('alex@example.com');
select tests.create_test_user('sam@example.com');
select tests.create_test_user('kai@example.com');

-- Setup: a room where Alex is owner and Sam is an approved member.
select tests.impersonate('alex@example.com');

-- The room is created via the generic RPC (config-driven; the tests
-- reference it by name below).
insert into tests.fixtures (key, room_id)
select 'alibi-test-room', (result).room_id
from public.create_case_room('Alibi Test Room', 'legal') as result;
select is(
  count(*),
  1::bigint,
  'owner creates a room'
) from public.case_rooms cr
where cr.name = 'Alibi Test Room' and cr.owner_id = (
  select user_id from tests.fixtures where key = 'alex@example.com'
);

-- Member fixtures run as postgres (direct inserts; RLS denies
-- impersonated sessions).
select tests.unimpersonate();
select tests.add_approved_member(
  (select id from public.case_rooms where name = 'Alibi Test Room'),
  'sam@example.com',
  'analyst'
);

-- Insert an entity (the person being alibied).
select tests.impersonate('alex@example.com');
insert into public.entities (room_id, name, entity_type)
select cr.id, 'Kai Lee', 'person'
from public.case_rooms cr where cr.name = 'Alibi Test Room';

select tests.impersonate('sam@example.com');
-- 1. Member can read the (empty) alibis table.
select is(
  count(*),
  0::bigint,
  'member can read (empty) alibis table'
) from public.alibis where room_id = (
  select id from public.case_rooms where name = 'Alibi Test Room'
);

select tests.impersonate('alex@example.com');
-- 2. Owner can insert an alibi.
insert into public.alibis (
  room_id, entity_id, claimed_window_start, claimed_window_end,
  claim_text, source, status, status_reason, created_by
)
select
  cr.id,
  e.id,
  '2026-09-01 08:00:00+00',
  '2026-09-01 10:00:00+00',
  'At the library from 8-10 AM',
  'self',
  'verified',
  'Confirmed by librarian',
  (select user_id from tests.fixtures where key = 'alex@example.com')
from public.case_rooms cr, public.entities e
where cr.name = 'Alibi Test Room' and e.name = 'Kai Lee';

select is(
  count(*),
  1::bigint,
  'owner insert succeeds'
) from public.alibis where claim_text = 'At the library from 8-10 AM';

-- 3. Non-member cannot insert (RLS with check raises).
select tests.impersonate('kai@example.com');
-- Non-member INSERT..SELECT: the RLS-scoped SELECT sees no rooms, so
-- zero rows insert (no exception — the WITH CHECK is never reached).
-- The product promise is "nothing enters the record" — assert that.
insert into public.alibis (room_id, entity_id, claimed_window_start,
  claimed_window_end, claim_text, source, status, status_reason, created_by)
select cr.id, e.id, '2026-09-01 08:00:00+00', '2026-09-01 10:00:00+00',
  'Fake alibi', 'self', 'verified', 'no reason', (select user_id
from tests.fixtures where key = 'kai@example.com')
from public.case_rooms cr, public.entities e
where cr.name = 'Alibi Test Room' and e.name = 'Kai Lee';
select is(
  count(*),
  0::bigint,
  'non-member cannot insert alibi (row never lands)'
) from public.alibis where claim_text = 'Fake alibi';

select tests.impersonate('alex@example.com');
-- 4. Owner can update alibi status with reason.
update public.alibis set status = 'conflict', status_reason = 'Disputed'
where claim_text = 'At the library from 8-10 AM';
select is(
  status,
  'conflict',
  'owner update changes status'
) from public.alibis where claim_text = 'At the library from 8-10 AM';

select tests.impersonate('sam@example.com');
-- 5. Member with edit_case (analyst) can also update.
update public.alibis set status = 'verified', status_reason = 'Confirmed by analyst'
where claim_text = 'At the library from 8-10 AM';
select is(
  status,
  'verified',
  'member with edit_case can update alibi'
) from public.alibis where claim_text = 'At the library from 8-10 AM';

-- 6. Alibi requires a status reason (CHECK constraint).
select throws_ok(
  'insert into public.alibis (room_id, entity_id, claimed_window_start, '
  || 'claimed_window_end, claim_text, source, status, status_reason, created_by) '
  || 'select cr.id, e.id, ''2026-09-02 08:00:00+00'', ''2026-09-02 10:00:00+00'', '
  || '''Another alibi'', ''self'', ''verified'', NULL, (select user_id '
  || 'from tests.fixtures where key = ''sam@example.com'') '
  || 'from public.case_rooms cr, public.entities e '
  || 'where cr.name = ''Alibi Test Room'' and e.name = ''Kai Lee''',
  null,
  'alibi requires status_reason (CHECK constraint)'
);

-- 7. verify_alibi RPC works for edit_case holders.
select public.verify_alibi(
  (select id from public.alibis where claim_text = 'At the library from 8-10 AM'),
  'partially_verified',
  'Partially confirmed by analyst'
);
select is(
  status,
  'partially_verified',
  'verify_alibi RPC sets status'
) from public.alibis where claim_text = 'At the library from 8-10 AM';

-- 8. RPC stamped verified_at.
select is(
  (verified_at is not null),
  true,
  'verify_alibi stamps verified_at'
) from public.alibis where claim_text = 'At the library from 8-10 AM';

select tests.impersonate('kai@example.com');
-- 9. Non-member sees no alibis (RLS deny proof).
select is(
  count(*),
  0::bigint,
  'non-member sees no alibis'
) from public.alibis;

select * from finish();
rollback;
