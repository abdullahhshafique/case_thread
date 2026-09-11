-- RLS contract tests: case_rooms + room_members (0002/0005 migrations).
-- Covers room visibility, creation, owner-only management, and the
-- join-request flow's database rules (Sprint 3 builds on these).

begin;
select plan(8);

select tests.unimpersonate();
select tests.create_test_user('priya@example.com') as priya_id \gset
select tests.create_test_user('elena@example.com') as elena_id \gset
select tests.create_test_user('marcus@example.com') as marcus_id \gset

-- 1. Any authenticated user can create a room they own.
select tests.impersonate(:'priya_id');
insert into public.case_rooms (name, case_type, owner_id, access_code_hash)
values ('Fraud Case 2026', 'legal', :'priya_id', 'hash-v1')
returning id as priya_room \gset

select is(
  count(*),
  1::bigint,
  'creator sees the room they own'
) from public.case_rooms where id = :priya_room;

-- 2. Cannot create a room owned by someone else.
select throws_ok(
  'insert into public.case_rooms (name, case_type, owner_id, access_code_hash) '
    || 'values (''Forged'', ''legal'', ' || quote_literal(:'elena_id')
    || ', ''h'')',
  null,
  'cannot create a room attributed to another user'
);

-- 3. Non-member cannot see the room.
select tests.impersonate(:'elena_id');
select is(
  count(*),
  0::bigint,
  'non-member cannot see the room'
) from public.case_rooms where id = :priya_room;

-- 4. Elena submits a pending join request (self, pending status).
insert into public.room_members (room_id, user_id, role_id, status)
values (:priya_room, :'elena_id', 'analyst', 'pending');

select is(
  status,
  'pending',
  'join request lands as pending'
) from public.room_members where room_id = :priya_room and user_id = :'elena_id';

-- 5. Pending member cannot see the room yet (approval gates access).
select is(
  count(*),
  0::bigint,
  'pending member cannot see room content before approval'
) from public.case_rooms where id = :priya_room;

-- 6. Non-owner cannot approve (member-management is owner-only).
select tests.impersonate(:'marcus_id');
-- Marcus is not even a member; his update must affect nothing.
update public.room_members set status = 'approved'
where room_id = :priya_room and user_id = :'elena_id';
select is(
  count(*),
  0::bigint,
  'non-owner approval attempt changes nothing'
) from public.room_members
where room_id = :priya_room and user_id = :'elena_id' and status = 'approved';

-- 7. Owner approves Elena; she can now see the room.
select tests.impersonate(:'priya_id');
update public.room_members
set status = 'approved', joined_at = now()
where room_id = :priya_room and user_id = :'elena_id';

select tests.impersonate(:'elena_id');
select is(
  count(*),
  1::bigint,
  'approved member sees the room'
) from public.case_rooms where id = :priya_room;

-- 8. Revoked member loses access.
select tests.impersonate(:'priya_id');
update public.room_members set status = 'revoked'
where room_id = :priya_room and user_id = :'elena_id';

select tests.impersonate(:'elena_id');
select is(
  count(*),
  0::bigint,
  'revoked member loses room visibility'
) from public.case_rooms where id = :priya_room;

select * from finish();
rollback;
