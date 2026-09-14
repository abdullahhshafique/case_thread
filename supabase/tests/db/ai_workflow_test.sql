-- Phase 3 contract tests (0018/0019): workflow builder persistence,
-- run-visibility, P1 agent seeds. Allow AND deny per Rules.md §7.
--
-- Deny semantics here: a failing INSERT (no policy) throws; a failing
-- UPDATE/DELETE (policy exists, USING false for this role) is a SILENT
-- 0-row no-op at the SQL level — so those contracts assert state
-- (steps unchanged / row still present), verified as postgres.

begin;
select plan(13);

select tests.unimpersonate();
select tests.create_test_user('wf-lead@example.com');
select tests.create_test_user('wf-analyst@example.com');
select tests.create_test_user('wf-reviewer@example.com');
select tests.create_test_user('wf-outsider@example.com');

select tests.impersonate('wf-lead@example.com');
insert into tests.fixtures (key, room_id)
select 'wf-room', (result).room_id
from public.create_case_room('Workflow Test Room', 'legal') as result;

select tests.unimpersonate();
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'wf-room'),
  'wf-analyst@example.com', 'analyst'
);
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'wf-room'),
  'wf-reviewer@example.com', 'reviewer'
);

-- 1. Analyst (edit_case=true) CAN create a workflow.
select tests.impersonate('wf-analyst@example.com');
-- (client inserts never send created_by — 0020's auth.uid() default
-- fills it; found live 2026-09-14, kept as a regression contract.)
insert into public.ai_workflows (room_id, name, steps)
values (
  (select room_id from tests.fixtures where key = 'wf-room'),
  'Contradictions then themes',
  '["contradiction_checker"]'::jsonb
);
select is(
  (select count(*) from public.ai_workflows
   where room_id = (select room_id from tests.fixtures where key = 'wf-room')
     and name = 'Contradictions then themes'),
  1::bigint,
  'analyst (edit_case) can create a workflow without created_by (0020 default)'
);
insert into tests.fixtures (key, text_value)
select 'wf-row', id::text from public.ai_workflows
where room_id = (select room_id from tests.fixtures where key = 'wf-room')
  and name = 'Contradictions then themes';

-- 2. Analyst CAN update a workflow (edit_case).
update public.ai_workflows
set steps = '["contradiction_checker", "root_cause_suggester"]'::jsonb
where id = (select text_value::uuid from tests.fixtures where key = 'wf-row');
select is(
  (select steps from public.ai_workflows
   where id = (select text_value::uuid from tests.fixtures where key = 'wf-row')),
  '["contradiction_checker", "root_cause_suggester"]'::jsonb,
  'analyst can update workflow steps'
);

-- 3. Reviewer (edit_case=false) CANNOT insert a workflow.
select tests.impersonate('wf-reviewer@example.com');
select throws_ok(
  'insert into public.ai_workflows (room_id, name, steps, created_by) values ('
    || '(select room_id from tests.fixtures where key = ''wf-room''), '
    || '''Denied'', ''["contradiction_checker"]''::jsonb, '
    || '(select user_id from tests.fixtures where key = ''wf-reviewer@example.com''))',
  'new row violates row-level security policy for table "ai_workflows"',
  'reviewer (no edit_case) cannot create a workflow'
);

-- 4. Reviewer's UPDATE is a silent no-op: steps unchanged.
update public.ai_workflows
set steps = '["fake_agent"]'::jsonb
where id = (select text_value::uuid from tests.fixtures where key = 'wf-row');
select tests.unimpersonate();
select is(
  (select steps from public.ai_workflows
   where id = (select text_value::uuid from tests.fixtures where key = 'wf-row')),
  '["contradiction_checker", "root_cause_suggester"]'::jsonb,
  'reviewer UPDATE is a no-op (steps unchanged)'
);

-- 5. Reviewer's DELETE is a silent no-op: row still present.
select tests.impersonate('wf-reviewer@example.com');
delete from public.ai_workflows
where id = (select text_value::uuid from tests.fixtures where key = 'wf-row');
select tests.unimpersonate();
select is(
  (select count(*) from public.ai_workflows
   where id = (select text_value::uuid from tests.fixtures where key = 'wf-row')),
  1::bigint,
  'reviewer DELETE is a no-op (workflow still present)'
);

-- 6. Reviewer CAN read the room's workflows (member SELECT).
select tests.impersonate('wf-reviewer@example.com');
select is(
  (select count(*) from public.ai_workflows
   where room_id = (select room_id from tests.fixtures where key = 'wf-room')),
  1::bigint,
  'reviewer can list member-visible workflows'
);

-- 7. Non-member sees zero workflows.
select tests.impersonate('wf-outsider@example.com');
select is(
  (select count(*) from public.ai_workflows
   where room_id = (select room_id from tests.fixtures where key = 'wf-room')),
  0::bigint,
  'non-member sees no workflows'
);

-- 8. Client INSERT into ai_workflow_runs is REJECTED (service-role
--    only — the Edge Function's exclusive right, like suggestions).
select tests.impersonate('wf-analyst@example.com');
select throws_ok(
  'insert into public.ai_workflow_runs (workflow_id, room_id, steps_total, started_by) '
    || 'values ((select text_value::uuid from tests.fixtures where key = ''wf-row''), '
    || '(select room_id from tests.fixtures where key = ''wf-room''), 2, '
    || '(select user_id from tests.fixtures where key = ''wf-analyst@example.com''))',
  'new row violates row-level security policy for table "ai_workflow_runs"',
  'client INSERT into ai_workflow_runs rejected (service-role only)'
);

-- Emulate the Edge Function's run insert (as postgres, like 0017's
-- suggestion inserts) so visibility contracts can be asserted.
select tests.unimpersonate();
insert into public.ai_workflow_runs (
  id, workflow_id, room_id, status, steps_total, steps_done, suggestion_ids, started_by
) values (
  'd2000000-0000-4000-8000-000000000001',
  (select text_value::uuid from tests.fixtures where key = 'wf-row'),
  (select room_id from tests.fixtures where key = 'wf-room'),
  'completed', 2, 2, '[]'::jsonb,
  (select user_id from tests.fixtures where key = 'wf-analyst@example.com')
);
insert into tests.fixtures (key, text_value)
values ('wf-run', 'd2000000-0000-4000-8000-000000000001');

-- 9. Runs visible to members.
select tests.impersonate('wf-reviewer@example.com');
select is(
  (select count(*) from public.ai_workflow_runs
   where id = (select text_value::uuid from tests.fixtures where key = 'wf-run')),
  1::bigint,
  'member can read workflow runs'
);

-- 10. Runs invisible to non-members.
select tests.impersonate('wf-outsider@example.com');
select is(
  (select count(*) from public.ai_workflow_runs
   where id = (select text_value::uuid from tests.fixtures where key = 'wf-run')),
  0::bigint,
  'non-member sees no workflow runs'
);

-- 11. Steps constraint: 0 steps rejected (server-side 1–5 bound).
select tests.unimpersonate();
select throws_ok(
  'insert into public.ai_workflows (room_id, name, steps, created_by) values ('
    || '(select room_id from tests.fixtures where key = ''wf-room''), '
    || '''Bad'', ''[]''::jsonb, '
    || '(select user_id from tests.fixtures where key = ''wf-analyst@example.com''))',
  'new row for relation "ai_workflows" violates check constraint "ai_workflows_steps_check"',
  'empty steps array rejected (1–5 bound)'
);

-- 12. P1 agent seeds (0019) present, correctly scoped, active.
select is(
  (select count(*) from public.ai_agents
   where id in ('literature_summarizer', 'diagnostic_differential_assistant')
     and is_active
     and case_type in ('academic', 'medical')
     and prompt_version = 1),
  2::bigint,
  'P1 agents seeded (academic + medical, v1, active)'
);

-- 13. Realtime publication carries suggestions + runs (0018 — the
--     Architecture.md §7 "realtime pushes" contract, machine-checked
--     so the guarded ALTER can never silently no-op).
select is(
  (select count(*) from pg_publication_tables
   where pubname = 'supabase_realtime'
     and schemaname = 'public'
     and tablename in ('ai_suggestions', 'ai_workflow_runs')),
  2::bigint,
  'ai_suggestions + ai_workflow_runs in supabase_realtime publication'
);

select * from finish();
rollback;
