-- Phase 2 redaction contract tests (0013): payload.privileged is
-- visible ONLY to view_privileged roles; everyone else sees the event
-- with the field stripped. The deny case is the product promise
-- (PRD: "field-level redaction ... so sensitive data stays scoped
-- correctly even within a room").

begin;
select plan(6);

select tests.unimpersonate();
select tests.create_test_user('rd-lead@example.com');
select tests.create_test_user('rd-analyst@example.com');
select tests.create_test_user('rd-observer@example.com');
select tests.create_test_user('rd-outsider@example.com');

-- Legal room: lead (view_privileged true), analyst (false),
-- observer (false) — per the 0004 grid.
select tests.impersonate('rd-lead@example.com');
insert into tests.fixtures (key, room_id)
select 'rd-room', (result).room_id
from public.create_case_room('Redaction Test Room', 'legal') as result;

select tests.unimpersonate();
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'rd-room'),
  'rd-analyst@example.com', 'analyst'
);
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'rd-room'),
  'rd-observer@example.com', 'observer'
);

-- Seed a manual event with a privileged sub-object (lead can write).
select tests.impersonate('rd-lead@example.com');
insert into public.timeline_events (room_id, event_type, actor_id, payload)
select (select room_id from tests.fixtures where key = 'rd-room'),
       'manual', auth.uid(),
       '{
         "summary": "Witness statement collected",
         "privileged": {"witness_contact": "+1-555-0100", "witness_name": "J. Doe"}
       }'::jsonb;

-- 1. Lead (view_privileged true) sees the privileged sub-object.
select tests.unimpersonate();
select tests.impersonate('rd-lead@example.com');
select is(
  (payload -> 'privileged' ->> 'witness_contact'),
  '+1-555-0100',
  'lead (view_privileged) sees privileged field'
) from public.v_timeline
where room_id = (select room_id from tests.fixtures where key = 'rd-room')
  and payload ->> 'summary' = 'Witness statement collected';

-- 2. Analyst (view_privileged false) sees the event but the privileged
--    sub-object is STRIPPED server-side.
select tests.impersonate('rd-analyst@example.com');
select is(
  payload ? 'privileged',
  false,
  'analyst: privileged sub-object stripped server-side'
) from public.v_timeline
where room_id = (select room_id from tests.fixtures where key = 'rd-room')
  and payload ->> 'summary' = 'Witness statement collected';

-- 3. The non-privileged part is still visible to the analyst.
select is(
  (payload ->> 'summary'),
  'Witness statement collected',
  'analyst still sees the non-privileged summary'
) from public.v_timeline
where room_id = (select room_id from tests.fixtures where key = 'rd-room');

-- 4. Observer too: event visible, privileged gone.
select tests.impersonate('rd-observer@example.com');
select is(
  count(*),
  1::bigint,
  'observer sees the redacted event via the view'
) from public.v_timeline
where room_id = (select room_id from tests.fixtures where key = 'rd-room')
  and not (payload ? 'privileged');

-- 5. Outsider (non-member) sees nothing (view RLS holds).
select tests.impersonate('rd-outsider@example.com');
select is(
  count(*),
  0::bigint,
  'non-member sees no timeline rows via the view'
) from public.v_timeline
where room_id = (select room_id from tests.fixtures where key = 'rd-room');

-- 6. Direct base-table reads are NOT the client path, but verify the
--    redaction is in the VIEW (not trusting the app): the base table
--    retains the data (chain-of-custody) while the view masks.
select tests.unimpersonate();
select is(
  (payload -> 'privileged' ->> 'witness_contact'),
  '+1-555-0100',
  'base table retains full data (redaction is per-read, data intact)'
) from public.timeline_events
where room_id = (select room_id from tests.fixtures where key = 'rd-room')
  and payload ->> 'summary' = 'Witness statement collected';

select * from finish();
rollback;
