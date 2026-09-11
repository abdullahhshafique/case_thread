-- RLS contract tests: audit_log immutability + visibility.
-- The append-only guarantee is the product's defensibility promise
-- (PRD §6.5, Architecture.md §4). No psql metacommands.

begin;
select plan(5);

select tests.unimpersonate();
select tests.create_test_user('auditor@example.com');
select tests.create_test_user('intruder@example.com');
select tests.create_test_user('outsider@example.com');

-- Room owned by auditor; auditor + intruder both approved members.
insert into public.case_rooms (name, case_type, owner_id, access_code_hash)
select 'Audit Test Room', 'legal', user_id, 'hash'
from tests.fixtures where key = 'auditor@example.com';

insert into tests.fixtures (key, room_id)
select 'audit_room', id from public.case_rooms
where name = 'Audit Test Room';

select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'audit_room'),
  'auditor@example.com', 'lead_investigator'
);
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'audit_room'),
  'intruder@example.com', 'observer'
);

-- Seed audit entry (postgres context; production inserts go via the
-- security-definer append_audit() helper — no client insert policy).
insert into public.audit_log (room_id, actor_id, action_type, object_type)
select (select room_id from tests.fixtures where key = 'audit_room'),
       (select user_id from tests.fixtures where key = 'auditor@example.com'),
       'room_created', 'case_room';

-- 1. Member can see the room's audit entries.
select tests.impersonate('auditor@example.com');
select is(
  count(*),
  1::bigint,
  'approved member sees audit log entries for their room'
) from public.audit_log
where room_id = (select room_id from tests.fixtures where key = 'audit_room');

-- 2. Non-member cannot see them.
select tests.impersonate('outsider@example.com');
select is(
  count(*),
  0::bigint,
  'non-member cannot see audit log entries'
) from public.audit_log
where room_id = (select room_id from tests.fixtures where key = 'audit_room');

-- 3. UPDATE must fail for ANY role — even the owner (grant-level revoke).
select tests.unimpersonate();
select tests.impersonate('auditor@example.com');
select throws_ok(
  'update public.audit_log set action_type = ''tampered''',
  null,
  'audit_log UPDATE throws for room owner'
);

-- 4. DELETE must fail for the owner too.
select throws_ok(
  'delete from public.audit_log',
  null,
  'audit_log DELETE throws for room owner'
);

-- 5. Direct client INSERT has no policy → fails even for members.
select throws_ok(
  'insert into public.audit_log (room_id, action_type, object_type) '
    || 'select room_id, ''fake'', ''case_room'' from tests.fixtures '
    || 'where key = ''audit_room''',
  null,
  'audit_log INSERT via client is not permitted (no policy)'
);

select * from finish();
rollback;
