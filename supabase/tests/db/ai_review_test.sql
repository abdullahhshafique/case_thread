-- Phase 3 contract tests (0017): the human-in-the-loop pipeline.
-- The deny cases are the product's core promise (Rules.md §11):
-- agents never touch the case record; only Lead-tier humans promote.

begin;
select plan(10);

select tests.unimpersonate();
select tests.create_test_user('ai-lead@example.com');
select tests.create_test_user('ai-analyst@example.com');
select tests.create_test_user('ai-observer@example.com');

select tests.impersonate('ai-lead@example.com');
insert into tests.fixtures (key, room_id)
select 'ai-room', (result).room_id
from public.create_case_room('AI Review Test Room', 'legal') as result;

select tests.unimpersonate();
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'ai-room'),
  'ai-analyst@example.com', 'analyst'
);
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'ai-room'),
  'ai-observer@example.com', 'observer'
);

-- The Edge Function (service role) inserts suggestions; emulate that
-- as postgres — no client path exists by design (0005: no insert policy).
-- (unimpersonate: the prior block left us impersonated as ai-lead.)
select tests.unimpersonate();
select set_config('role', 'postgres', true);
insert into public.ai_suggestions (id, room_id, agent_type, input_ref, output)
values (
  'd1000000-0000-4000-8000-000000000001',
  (select room_id from tests.fixtures where key = 'ai-room'),
  'contradiction_checker', 'run-1',
  '{"title": "Dates conflict", "detail": "Statement says March; contract says June", "items": ["statement.pdf", "contract.pdf"]}'::jsonb
);
insert into tests.fixtures (key, text_value)
values ('ai-sug', 'd1000000-0000-4000-8000-000000000001');

-- 1. Analyst (approve_ai_findings=false) CANNOT accept.
select tests.impersonate('ai-analyst@example.com');
select throws_ok(
  'select * from public.review_suggestion('
    || quote_literal((select text_value from tests.fixtures where key = 'ai-sug'))
    || ', ''accepted'')',
  'Only Lead-tier roles can review AI findings.',
  'analyst cannot review AI findings'
);

-- 2. Observer cannot review either.
select tests.impersonate('ai-observer@example.com');
select throws_ok(
  'select * from public.review_suggestion('
    || quote_literal((select text_value from tests.fixtures where key = 'ai-sug'))
    || ', ''accepted'')',
  'Only Lead-tier roles can review AI findings.',
  'observer cannot review AI findings'
);

-- 3. Lead accepts → status flips + timeline event + audit, atomically.
select tests.impersonate('ai-lead@example.com');
insert into tests.fixtures (key, room_id, text_value)
select 'ai-review', r.suggestion_id, r.timeline_event_id::text
from public.review_suggestion(
  (select text_value::uuid from tests.fixtures where key = 'ai-sug'),
  'accepted'
) as r;

select is(
  (select status from public.ai_suggestions
   where id = (select text_value::uuid from tests.fixtures where key = 'ai-sug')),
  'accepted',
  'acceptance flips suggestion status'
);

-- 4. The accepted finding entered the timeline (event_type ai_suggestion).
select is(
  count(*),
  1::bigint,
  'accepted finding promoted to timeline'
) from public.timeline_events
where room_id = (select room_id from tests.fixtures where key = 'ai-room')
  and event_type = 'ai_suggestion';

-- 5. Double review is rejected (already reviewed).
select throws_ok(
  'select * from public.review_suggestion('
    || quote_literal((select text_value from tests.fixtures where key = 'ai-sug'))
    || ', ''accepted'')',
  'This suggestion was already reviewed.',
  'double review rejected'
);

-- Second suggestion: lead EDITS then accepts. (service-role insert —
-- back to postgres first)
select tests.unimpersonate();
insert into public.ai_suggestions (id, room_id, agent_type, input_ref, output)
values (
  'd1000000-0000-4000-8000-000000000002',
  (select room_id from tests.fixtures where key = 'ai-room'),
  'contradiction_checker', 'run-2',
  '{"title": "Draft finding", "detail": "needs human polish"}'::jsonb
);
insert into tests.fixtures (key, text_value)
values ('ai-sug2', 'd1000000-0000-4000-8000-000000000002');

-- 6. Edited acceptance stores the HUMAN's version in the timeline.
insert into tests.fixtures (key, room_id, text_value)
select 'ai-review2', r.suggestion_id, r.timeline_event_id::text
from public.review_suggestion(
  (select text_value::uuid from tests.fixtures where key = 'ai-sug2'),
  'edited',
  '{"title": "Polished by lead", "detail": "final wording"}'::jsonb
) as r;

select is(
  (select te.payload -> 'details' ->> 'title' from public.timeline_events te
   where te.id = (select text_value::uuid from tests.fixtures where key = 'ai-review2')),
  'Polished by lead',
  'edited review promotes the HUMAN version to the timeline'
);

-- Third suggestion: dismissed. (service-role insert)
select tests.unimpersonate();
insert into public.ai_suggestions (id, room_id, agent_type, input_ref, output)
values (
  'd1000000-0000-4000-8000-000000000003',
  (select room_id from tests.fixtures where key = 'ai-room'),
  'contradiction_checker', 'run-3',
  '{"title": "False positive", "detail": "recurring calendar artifact"}'::jsonb
);
insert into tests.fixtures (key, text_value)
values ('ai-sug3', 'd1000000-0000-4000-8000-000000000003');

-- 7. Dismissal: no timeline entry, but audited.
insert into tests.fixtures (key, member_id, text_value)
select 'ai-review3', r.suggestion_id, r.timeline_event_id::text
from public.review_suggestion(
  (select text_value::uuid from tests.fixtures where key = 'ai-sug3'),
  'dismissed'
) as r;

select is(
  (select status from public.ai_suggestions
   where id = (select text_value::uuid from tests.fixtures where key = 'ai-sug3')),
  'dismissed',
  'dismissal flips status'
);
select is(
  (select text_value from tests.fixtures where key = 'ai-review3'),
  null,
  'dismissal creates NO timeline event'
);

-- 8. All three decisions audited.
select is(
  count(*),
  3::bigint,
  'accept/edit/dismiss all audited'
) from public.audit_log
where room_id = (select room_id from tests.fixtures where key = 'ai-room')
  and action_type in ('suggestion_accepted', 'suggestion_edited', 'suggestion_dismissed');

-- 9. Client cannot insert ai_suggestions (service-role only — the
-- Edge Function's exclusive right).
select tests.impersonate('ai-lead@example.com');
select throws_ok(
  'insert into public.ai_suggestions (room_id, agent_type, output) '
    || 'values ((select room_id from tests.fixtures where key = ''ai-room''), '
    || '''fake_agent'', ''{}''::jsonb)',
  'new row violates row-level security policy for table "ai_suggestions"',
  'client INSERT into ai_suggestions rejected (service-role only)'
);

select * from finish();
rollback;
