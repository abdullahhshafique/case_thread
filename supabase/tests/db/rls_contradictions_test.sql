-- RLS contract tests: contradictions (0025 migration).
-- Members can read; edit_case holders can insert (manual);
-- approve_ai_findings holders can update (resolve/dismiss).

begin;
select plan(11);

select tests.unimpersonate();
select tests.create_test_user('alex@example.com');
select tests.create_test_user('sam@example.com');
select tests.create_test_user('jordan@example.com');
select tests.create_test_user('kai@example.com');

-- Setup: room + approved members + entity.
select tests.impersonate('alex@example.com');

-- The room is created via the generic RPC (config-driven; the tests
-- reference it by name below).
insert into tests.fixtures (key, room_id)
select 'contradiction-test-room', (result).room_id
from public.create_case_room('Contradiction Test Room', 'legal') as result;
select is(
  count(*),
  1::bigint,
  'owner creates a room'
) from public.case_rooms cr
where cr.name = 'Contradiction Test Room' and cr.owner_id = (
  select user_id from tests.fixtures where key = 'alex@example.com'
);

-- Member fixtures run as postgres (direct inserts; RLS denies
-- impersonated sessions).
select tests.unimpersonate();
select tests.add_approved_member(
  (select id from public.case_rooms where name = 'Contradiction Test Room'),
  'sam@example.com',
  'lead_investigator'
);
select tests.add_approved_member(
  (select id from public.case_rooms where name = 'Contradiction Test Room'),
  'jordan@example.com',
  'analyst'
);

select tests.impersonate('alex@example.com');
insert into public.entities (room_id, name, entity_type)
select cr.id, 'Kai Lee', 'person'
from public.case_rooms cr where cr.name = 'Contradiction Test Room';

select tests.impersonate('sam@example.com');
-- 1. Members can read the (empty) contradictions table.
select is(
  count(*),
  0::bigint,
  'member can read (empty) contradictions'
) from public.contradictions;

-- 2. Lead-tier (edit_case) can insert a manual contradiction.
--    (contradictions has no created_by column — flagged_by is the actor.)
insert into public.contradictions (
  room_id, source_type, conflicting_detail, flagged_reason,
  status, flagged_by
)
select
  cr.id, 'manual', 'Statement says June; contract says March',
  'Reviewed both docs', 'open',
  (select user_id from tests.fixtures where key = 'sam@example.com')
from public.case_rooms cr
where cr.name = 'Contradiction Test Room';

select is(
  count(*),
  1::bigint,
  'lead insert succeeds'
) from public.contradictions where flagged_reason = 'Reviewed both docs';

-- 3. Non-member cannot insert (RLS with check raises).
select tests.impersonate('kai@example.com');
-- Non-member INSERT..SELECT: RLS hides the room from the source SELECT
-- → zero rows land. Assert the record never entered (the promise).
insert into public.contradictions (room_id, source_type,
  conflicting_detail, flagged_reason, status, flagged_by)
select cr.id, 'manual', 'X', 'Fake open', 'open', (select user_id
from tests.fixtures where key = 'kai@example.com')
from public.case_rooms cr where cr.name = 'Contradiction Test Room';
select is(
  count(*),
  0::bigint,
  'non-member cannot insert contradiction (row never lands)'
) from public.contradictions where flagged_reason = 'Fake open';

select tests.impersonate('sam@example.com');
-- 4. Lead-tier can resolve a contradiction.
update public.contradictions set status = 'resolved',
  resolution_note = 'Statement corrected'
where flagged_reason = 'Reviewed both docs';
select is(
  status,
  'resolved',
  'lead can resolve'
) from public.contradictions where flagged_reason = 'Reviewed both docs';

select tests.impersonate('jordan@example.com');
-- 5. Member without approve_ai_findings: update silently skipped
--    (RLS update USING filters the row out — no exception, no change).
update public.contradictions set status = 'dismissed'
where flagged_reason = 'Reviewed both docs';
select is(
  (select status from public.contradictions
   where flagged_reason = 'Reviewed both docs'),
  'resolved',
  'non-lead update is denied (row unchanged)'
);

select tests.impersonate('sam@example.com');
-- 6. Members can read the resolved row.
select is(
  count(*),
  1::bigint,
  'member can read contradictions'
) from public.contradictions where flagged_reason = 'Reviewed both docs';

-- 7. AI-suggestion source type is valid (CHECK accepts it).
--    The RLS insert policy only permits source_type='manual', so this
--    insert runs as superuser (unimpersonated) against a real
--    ai_suggestions row — matching how the Edge Function writes them.
select tests.unimpersonate();
insert into public.ai_suggestions (room_id, agent_type, output)
select cr.id, 'contradiction_detector', '{"detail": "AI flagged date conflict"}'::jsonb
from public.case_rooms cr where cr.name = 'Contradiction Test Room';

insert into public.contradictions (
  room_id, source_type, ai_suggestion_id, conflicting_detail,
  flagged_reason, status, flagged_by
)
select
  cr.id, 'ai_suggestion', s.id,
  'AI flagged date conflict', 'auto-detected', 'open',
  (select user_id from tests.fixtures where key = 'alex@example.com')
from public.case_rooms cr, public.ai_suggestions s
where cr.name = 'Contradiction Test Room'
  and s.agent_type = 'contradiction_detector';

select is(
  count(*),
  1::bigint,
  'ai_suggestion source_type accepted'
) from public.contradictions where flagged_reason = 'auto-detected';

-- 8. AI suggestion requires ai_suggestion_id (CHECK constraint) —
--    superuser so RLS is bypassed and the CHECK itself is exercised.
select throws_ok(
  'insert into public.contradictions (room_id, source_type, '
  || 'ai_suggestion_id, conflicting_detail, flagged_reason, status, '
  || 'flagged_by) select cr.id, ''ai_suggestion'', NULL, '
  || '''X'', ''Y'', ''open'', (select user_id from tests.fixtures '
  || 'where key = ''alex@example.com'') '
  || 'from public.case_rooms cr where cr.name = '
  || '''Contradiction Test Room''',
  null,
  'ai_suggestion source requires ai_suggestion_id (CHECK)'
);

select tests.impersonate('sam@example.com');
-- 9. Members can read the AI-sourced contradiction too.
select is(
  count(*),
  1::bigint,
  'member can read ai_suggestion contradiction'
) from public.contradictions where flagged_reason = 'auto-detected';

-- 10. Lead can dismiss it.
update public.contradictions set status = 'dismissed'
where flagged_reason = 'auto-detected';
select is(
  status,
  'dismissed',
  'lead can dismiss'
) from public.contradictions where flagged_reason = 'auto-detected';

select * from finish();
rollback;
