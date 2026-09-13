-- Phase 2 export contract tests (0015): permission gating, redaction
-- in the compiled document, audit of the export itself.

begin;
select plan(5);

select tests.unimpersonate();
select tests.create_test_user('ex-lead@example.com');
select tests.create_test_user('ex-analyst@example.com');
select tests.create_test_user('ex-observer@example.com');

select tests.impersonate('ex-lead@example.com');
insert into tests.fixtures (key, room_id)
select 'ex-room', (result).room_id
from public.create_case_room('Export Test Room', 'legal') as result;

select tests.unimpersonate();
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'ex-room'),
  'ex-analyst@example.com', 'analyst'
);
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'ex-room'),
  'ex-observer@example.com', 'observer'
);

-- Seed a privileged manual event (lead writes; lead can see it).
select tests.impersonate('ex-lead@example.com');
insert into public.timeline_events (room_id, event_type, actor_id, payload)
select (select room_id from tests.fixtures where key = 'ex-room'),
       'manual', auth.uid(),
       '{"summary":"Privileged note","privileged":{"strategy":"settle first"} }'::jsonb;

-- 1. Lead (export_reports true) exports the document.
select tests.unimpersonate();
select tests.impersonate('ex-lead@example.com');
select is(
  (doc -> 'room' ->> 'name'),
  'Export Test Room',
  'export returns the compiled document'
) from public.export_case_report(
  (select room_id from tests.fixtures where key = 'ex-room')
) as doc;

-- 2. The lead's document retains the privileged field (they hold
--    view_privileged). CTE form: set-returning functions need a FROM.
with d as (
  select (public.export_case_report(
    (select room_id from tests.fixtures where key = 'ex-room')
  )) as doc
), tl as (
  select e.value as entry
  from d, jsonb_array_elements(d.doc -> 'timeline') e
)
select is(
  exists (select 1 from tl where entry -> 'payload' ? 'privileged'),
  true,
  'privileged field present for the privileged exporter'
);

-- 3. Analyst (export_reports false) is denied.
select tests.impersonate('ex-analyst@example.com');
select throws_ok(
  'select * from public.export_case_report('
    || quote_literal((select room_id from tests.fixtures where key = 'ex-room'))
    || ')',
  'Your role cannot export reports in this room.',
  'analyst (export_reports false) denied'
);

-- 4. Export is audited (state-changing action per PRD §6.5). Audit
--    reads are member-scoped; check as the lead (who exported).
select tests.impersonate('ex-lead@example.com');
select is(
  count(*),
  2::bigint, -- both exports (tests 1+2) are audited
  'exports recorded in the audit trail'
) from public.audit_log
where room_id = (select room_id from tests.fixtures where key = 'ex-room')
  and action_type = 'report_exported';

-- 5. Observer cannot export either.
select tests.impersonate('ex-observer@example.com');
select throws_ok(
  'select * from public.export_case_report('
    || quote_literal((select room_id from tests.fixtures where key = 'ex-room'))
    || ')',
  'Your role cannot export reports in this room.',
  'observer (export_reports false) denied'
);

select * from finish();
rollback;
