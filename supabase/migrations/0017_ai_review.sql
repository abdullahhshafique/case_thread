-- CaseThread migration 0017: Phase 3 — AI agent registry + human
-- review RPC (Phases.md §4).
--
-- Rules.md §11 invariants, enforced here:
--   * Agents NEVER write timeline_events/audit_log directly — only
--     ai_suggestions (status=pending). Promotion to the case record
--     happens ONLY through review_suggestion(), called by a Lead-tier
--     human, and it writes timeline + audit ATOMICICALLY.
--   * Prompt configs are versioned data, like case types.
--   * No client path exists to insert ai_suggestions (0005 has no
--     insert policy; the Edge Function inserts with the service role,
--     which RLS does not gate).

-- ---------------------------------------------------------------------------
-- Agent registry: config data (one core, many configs). prompt_version
-- pins the exact prompt; changing prompts ships as new rows, never
-- silent edits (Rules.md §11 "prompt versioning").
-- ---------------------------------------------------------------------------
create table if not exists public.ai_agents (
  id text primary key, -- e.g. 'contradiction_checker'
  display_name text not null,
  description text not null default '',
  case_type text references public.case_types (id) on delete cascade,
  prompt_version int not null default 1,
  prompt text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.ai_agents enable row level security;
-- Config readable by authenticated users (the workflow panel lists it);
-- changes ship only via migrations.
drop policy if exists "ai agents readable by authenticated" on public.ai_agents;
create policy "ai agents readable by authenticated"
  on public.ai_agents for select
  to authenticated
  using (is_active);

-- Seed the first three agents (Phases.md §4): one per flagship case
-- type. Prompts are deliberately conservative: analyse ONLY, never
-- conclude; output shape is fixed JSON.
insert into public.ai_agents (id, display_name, description, case_type, prompt_version, prompt) values
  ('contradiction_checker', 'Contradiction Checker',
   'Flags possible contradictions between statements and evidence in a legal case room.',
   'legal', 1,
   'You are assisting a legal investigation team. Review the room''s timeline '
   'events and evidence list. Identify AT MOST three possible contradictions '
   'or inconsistencies between items. For each, cite the involved items by '
   'name and quote the conflicting text. You are surfacing items for human '
   'review — never assert guilt, intent, or conclusions. Output JSON: '
   '{"findings": [{"title": string, "items": [string], "detail": string}]}'),
  ('financial_anomaly_detector', 'Financial Anomaly Detector',
   'Flags unusual patterns in amounts, dates, or sequences in expense/audit evidence.',
   'corporate', 1,
   'You are assisting an internal audit team. Review the room''s evidence '
   'list and timeline. Identify AT MOST three anomalies in amounts, dates, '
   'or sequences worth a human look. Never assert wrongdoing. Output JSON: '
   '{"findings": [{"title": string, "items": [string], "detail": string}]}'),
  ('root_cause_suggester', 'Root-Cause Suggester',
   'Proposes candidate root causes for an incident from the timeline.',
   'technical', 1,
   'You are assisting an engineering post-mortem. Review the incident '
   'timeline. Propose AT MOST three candidate root causes with the evidence '
   'each is consistent with. These are hypotheses for human validation, '
   'not conclusions. Output JSON: '
   '{"findings": [{"title": string, "items": [string], "detail": string}]}')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- review_suggestion(): the ONLY sanctioned promotion path from
-- suggestion → case record. Lead-tier only (PRD P1: "nothing enters
-- the record without human sign-off"). Single transaction: status
-- update + timeline_event + audit entry (Architecture.md §7 AI path).
-- ---------------------------------------------------------------------------
create or replace function public.review_suggestion(
  suggestion uuid,
  decision text, -- 'accepted' | 'edited' | 'dismissed'
  edited_output jsonb default null
)
returns table (suggestion_id uuid, new_status text, timeline_event_id uuid)
language plpgsql
security definer set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  sug public.ai_suggestions%rowtype;
  reviewed_id uuid;
  final_output jsonb;
  is_lead boolean;
  ev_id uuid;
begin
  if caller_id is null then
    raise exception 'Not authenticated';
  end if;

  if decision not in ('accepted', 'edited', 'dismissed') then
    raise exception 'Decision must be accepted, edited, or dismissed.';
  end if;

  select * into sug from public.ai_suggestions where id = suggestion;
  if sug.id is null then
    raise exception 'Suggestion not found.';
  end if;

  if sug.status <> 'pending' then
    raise exception 'This suggestion was already reviewed.';
  end if;

  -- approve_ai_findings is the Lead-tier key (0004 grids).
  if not public.user_room_permission(sug.room_id, 'approve_ai_findings') then
    raise exception 'Only Lead-tier roles can review AI findings.';
  end if;

  final_output := coalesce(edited_output, sug.output);

  update public.ai_suggestions
  set status = decision,
      reviewed_by = caller_id,
      reviewed_at = now(),
      output = case when decision = 'edited' then final_output else output end
  where id = suggestion
  returning id into reviewed_id;

  if decision = 'dismissed' then
    -- Dismissal is recorded on the suggestion + audit, but nothing
    -- enters the case record (PRD: suggestions never become timeline
    -- entries unless accepted).
    perform public.append_audit(
      sug.room_id, caller_id, 'suggestion_dismissed',
      'ai_suggestion', suggestion::text,
      jsonb_build_object('agent_type', sug.agent_type)
    );
    return query select reviewed_id, 'dismissed', null::uuid;
  else
    -- Accepted/edited: promote to the timeline as a distinct
    -- ai_suggestion event, atomically with the audit entry.
    insert into public.timeline_events
      (room_id, event_type, actor_id, payload)
    values
      (sug.room_id, 'ai_suggestion', caller_id,
       jsonb_build_object(
         'summary', 'AI finding reviewed: ' || sug.agent_type,
         'action_type', 'suggestion_' || decision,
         'agent_type', sug.agent_type,
         'finding', final_output ->> 'title',
         'details', final_output
       ))
    returning id into ev_id;

    perform public.append_audit(
      sug.room_id, caller_id, 'suggestion_' || decision,
      'ai_suggestion', suggestion::text,
      jsonb_build_object(
        'agent_type', sug.agent_type,
        'timeline_event', ev_id
      )
    );

    return query select reviewed_id, decision, ev_id;
  end if;
end;
$$;
