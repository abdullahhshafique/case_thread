-- RLS contract tests: audit_log immutability + visibility.
-- The append-only guarantee is the product's defensibility promise
-- (PRD §6.5, Architecture.md §4) — these tests are non-negotiable.

begin;
select plan(5);

select tests.unimpersonate();
select tests.create_test_user('auditor@example.com') as owner_id \gset
select tests.create_test_user('intruder@example.com') as intruder_id \gset

insert into public.case_types (id, display_name) values
  ('legal', 'Legal / Investigative') -- exists via migration; re-insert tolerated by on conflict? No: guard.
on conflict (id) do nothing;

-- Room owned by owner; owner + intruder both approved members.
insert into public.case_rooms (name, case_type, owner_id, access_code_hash)
values ('Audit Test Room', 'legal', :'owner_id', 'hash')
returning id as room_id \gset

select tests.add_approved_member(:room_id, :'owner_id', 'lead_investigator');
select tests.add_approved_member(:room_id, :'intruder_id', 'observer');

-- A seed audit entry (postgres context — inserts go via triggers in
-- production; policy allows none, so tests insert as postgres).
insert into public.audit_log (room_id, actor_id, action_type, object_type)
values (:room_id, :'owner_id', 'room_created', 'case_room');

-- 1. Member can see the room's audit entries.
select tests.impersonate(:'owner_id');
select is(
  count(*),
  1::bigint,
  'approved member sees audit log entries for their room'
) from public.audit_log where room_id = :room_id;

-- 2. Non-member cannot see them.
select tests.impersonate(:'intruder_id');
-- intruder IS a member here; use a non-member third user instead.
select tests.unimpersonate();
select tests.create_test_user('outsider@example.com') as outsider_id \gset
select tests.impersonate(:'outsider_id');
select is(
  count(*),
  0::bigint,
  'non-member cannot see audit log entries'
) from public.audit_log where room_id = :room_id;

-- 3. UPDATE must fail for ANY role — even the owner (grant-level revoke).
select tests.unimpersonate();
select tests.impersonate(:'owner_id');
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

-- 5. Direct client INSERT has no policy → fails even for members
-- (appends only via security-definer triggers in production).
select throws_ok(
  'insert into public.audit_log (room_id, action_type, object_type) '
    || 'values (' || quote_literal(:room_id) || ', ''fake'', ''case_room'')',
  null,
  'audit_log INSERT via client is not permitted (no policy)'
);

select * from finish();
rollback;
