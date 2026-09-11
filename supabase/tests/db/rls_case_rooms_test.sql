-- RLS contract tests: case_rooms + room_members (0002/0005 migrations).
-- Covers room visibility, creation, owner-only management, and the
-- join-request flow's database rules. No psql metacommands.

begin;
select plan(8);

select tests.unimpersonate();
select tests.create_test_user('priya@example.com');
select tests.create_test_user('elena@example.com');
select tests.create_test_user('marcus@example.com');

-- 1. Any authenticated user can create a room they own.
select tests.impersonate('priya@example.com');
insert into public.case_rooms (name, case_type, owner_id, access_code_hash)
select 'Fraud Case 2026', 'legal', user_id, 'hash-v1'
from tests.fixtures where key = 'priya@example.com';

select is(
  count(*),
  1::bigint,
  'creator sees the room they own'
) from public.case_rooms where name = 'Fraud Case 2026';

-- 2. Cannot create a room owned by someone else.
select throws_ok(
  'insert into public.case_rooms (name, case_type, owner_id, access_code_hash) '
    || 'select ''Forged'', ''legal'', user_id, ''h'' from tests.fixtures '
    || 'where key = ''elena@example.com''',
  null,
  'cannot create a room attributed to another user'
);

-- 3. Non-member cannot see the room.
select tests.impersonate('elena@example.com');
select is(
  count(*),
  0::bigint,
  'non-member cannot see the room'
) from public.case_rooms where name = 'Fraud Case 2026';

-- 4. Elena submits a pending join request (self, pending status).
insert into public.room_members (room_id, user_id, role_id, status)
select cr.id, f.user_id, 'analyst', 'pending'
from public.case_rooms cr, tests.fixtures f
where cr.name = 'Fraud Case 2026' and f.key = 'elena@example.com';

select is(
  rm.status,
  'pending',
  'join request lands as pending'
) from public.room_members rm
join tests.fixtures f on f.user_id = rm.user_id and f.key = 'elena@example.com'
join public.case_rooms cr on cr.id = rm.room_id and cr.name = 'Fraud Case 2026';

-- 5. Pending member cannot see the room yet (approval gates access).
select is(
  count(*),
  0::bigint,
  'pending member cannot see room content before approval'
) from public.case_rooms where name = 'Fraud Case 2026';

-- 6. Non-owner cannot approve (member-management is owner-only).
select tests.impersonate('marcus@example.com');
update public.room_members rm
set status = 'approved'
from tests.fixtures f
where f.user_id = rm.user_id and f.key = 'elena@example.com'
  and rm.room_id in (select id from public.case_rooms where name = 'Fraud Case 2026');

select is(
  count(*),
  0::bigint,
  'non-owner approval attempt changes nothing'
) from public.room_members rm
join tests.fixtures f on f.user_id = rm.user_id and f.key = 'elena@example.com'
where rm.status = 'approved'
  and rm.room_id in (select id from public.case_rooms where name = 'Fraud Case 2026');

-- 7. Owner approves Elena; she can now see the room.
select tests.impersonate('priya@example.com');
update public.room_members rm
set status = 'approved', joined_at = now()
from tests.fixtures f
where f.user_id = rm.user_id and f.key = 'elena@example.com'
  and rm.room_id in (select id from public.case_rooms where name = 'Fraud Case 2026');

select tests.impersonate('elena@example.com');
select is(
  count(*),
  1::bigint,
  'approved member sees the room'
) from public.case_rooms where name = 'Fraud Case 2026';

-- 8. Revoked member loses access.
select tests.impersonate('priya@example.com');
update public.room_members rm
set status = 'revoked'
from tests.fixtures f
where f.user_id = rm.user_id and f.key = 'elena@example.com'
  and rm.room_id in (select id from public.case_rooms where name = 'Fraud Case 2026');

select tests.impersonate('elena@example.com');
select is(
  count(*),
  0::bigint,
  'revoked member loses room visibility'
) from public.case_rooms where name = 'Fraud Case 2026';

select * from finish();
rollback;
