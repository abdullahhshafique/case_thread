-- RLS contract tests: room service functions (0007 migration).
-- Covers create/join/preview/rotate/decide — including the PRD §6.1–6.2
-- edge cases those functions encode. No psql metacommands.

begin;
select plan(11);

select tests.unimpersonate();
select tests.create_test_user('svc-owner@example.com');
select tests.create_test_user('svc-joiner@example.com');
select tests.create_test_user('svc-intruder@example.com');

-- Create the room ONCE; keep id + code in fixtures.
select tests.impersonate('svc-owner@example.com');
insert into tests.fixtures (key, room_id, text_value)
select 'svc-room', (result).room_id, (result).access_code
from public.create_case_room('Service Test Room', 'legal') as result;

-- 1. Creation returned both values.
select is(
  room_id is not null and text_value is not null,
  true,
  'create_case_room returns room_id and plaintext code'
) from tests.fixtures where key = 'svc-room';

-- 2. Code is 8 chars from the unambiguous alphabet (PRD §6.1).
select matches(
  text_value,
  '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$',
  'access code is 8 unambiguous chars'
) from tests.fixtures where key = 'svc-room';

-- 3. Owner auto-approved with the owner-default role.
select is(
  role_id || '/' || status,
  'lead_investigator/approved',
  'creator auto-approved as lead_investigator'
) from public.room_members
where room_id = (select room_id from tests.fixtures where key = 'svc-room');

-- 4. Audit entry written.
select is(
  count(*),
  1::bigint,
  'room creation logged to audit trail'
) from public.audit_log
where room_id = (select room_id from tests.fixtures where key = 'svc-room')
  and action_type = 'room_created';

select tests.unimpersonate();

-- 5. Joiner previews by code: name + case type revealed (PRD §6.2).
select tests.impersonate('svc-joiner@example.com');
select is(
  (room_name, case_type_id),
  ('Service Test Room', 'legal')::record,
  'preview_room_by_code reveals name and case type'
) from public.preview_room_by_code(
  (select text_value from tests.fixtures where key = 'svc-room')
);

-- 6. Joiner requests analyst role; lands pending; audit logged.
insert into tests.fixtures (key, member_id, text_value)
select 'svc-join-result', member_id, status
from public.request_room_join(
  (select text_value from tests.fixtures where key = 'svc-room'),
  'analyst'
);

select is(
  text_value,
  'pending',
  'join request lands pending'
) from tests.fixtures where key = 'svc-join-result';

select is(
  count(*),
  1::bigint,
  'join request logged to audit trail'
) from public.audit_log
where room_id = (select room_id from tests.fixtures where key = 'svc-room')
  and action_type = 'join_requested';

-- 7. Pending joiner cannot read room content yet (approval gates access).
select is(
  count(*),
  0::bigint,
  'pending member cannot read case_rooms row'
) from public.case_rooms
where id = (select room_id from tests.fixtures where key = 'svc-room');

-- 8. Non-owner cannot approve the join request.
select tests.impersonate('svc-intruder@example.com');
select throws_ok(
  format(
    'select public.decide_join_request(%L, %L, ''approved'')',
    (select room_id from tests.fixtures where key = 'svc-room'),
    (select member_id from tests.fixtures where key = 'svc-join-result')
  ),
  null,
  'non-owner cannot approve join requests'
);

-- 9. Owner approves; joiner becomes approved and can see the room.
select tests.impersonate('svc-owner@example.com');
select is(
  public.decide_join_request(
    (select room_id from tests.fixtures where key = 'svc-room'),
    (select member_id from tests.fixtures where key = 'svc-join-result'),
    'approved'
  ),
  'approved',
  'owner approves join request'
);

select tests.impersonate('svc-joiner@example.com');
select is(
  count(*),
  1::bigint,
  'approved joiner can now read the room'
) from public.case_rooms
where id = (select room_id from tests.fixtures where key = 'svc-room');

-- 10. Rotation invalidates old code for previews; new code works.
-- Pending requests stay valid (keyed to room, not code — PRD §6.1).
select tests.impersonate('svc-owner@example.com');
insert into tests.fixtures (key, text_value)
select 'svc-room-new-code', public.rotate_room_code(
  (select room_id from tests.fixtures where key = 'svc-room')
);

select tests.impersonate('svc-joiner@example.com');
select is(
  count(*),
  0::bigint,
  'old code no longer previews the room'
) from public.preview_room_by_code(
  (select text_value from tests.fixtures where key = 'svc-room')
);

select tests.impersonate('svc-intruder@example.com');
select is(
  count(*),
  1::bigint,
  'new code previews the room'
) from public.preview_room_by_code(
  (select text_value from tests.fixtures where key = 'svc-room-new-code')
);

-- 11. Invalid code: same error regardless (no info leak — PRD §6.2).
select throws_ok(
  'select * from public.preview_room_by_code(''BOGUSCOD'')',
  null,
  'invalid code rejected without info leak'
);

select * from finish();
rollback;
