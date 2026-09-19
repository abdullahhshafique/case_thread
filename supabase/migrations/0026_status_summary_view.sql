-- CaseThread migration 0026: Case Status lifecycle, Closed Summary,
-- and Dashboard Statistics view.
--
-- case_rooms.investigation_status is ADDITIVE — the existing
-- `status` column (active/archived, room lifecycle) is untouched
-- (Architecture.md §14, PRD §4.6).
--
-- case_closed_summaries stores a JSONB snapshot (stable even if
-- underlying data changes post-closure — PRD §4.6).
--
-- v_case_statistics is a SECURITY INVOKER function (not a view, not
-- materialized — Architecture-Phase5.md §2.10).

-- ---------------------------------------------------------------------------
-- case_rooms: additive investigation lifecycle column.
-- Named distinctly from existing `status` in UI:
--   "Investigation status" vs "Room status" (Phases-Phase5.md §5 risk).
-- ---------------------------------------------------------------------------
alter table public.case_rooms
  add column if not exists investigation_status text not null default 'open'
    check (investigation_status in (
      'open', 'under_investigation', 'review', 'closed'
    ));

-- ---------------------------------------------------------------------------
-- case_closed_summaries: snapshot on transition to closed.
-- Insert-only (not update) — if a case is reopened then re-closed,
-- a new row is inserted (keep history — PRD §4.6).
-- ---------------------------------------------------------------------------
create table public.case_closed_summaries (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  summary_json jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  generated_by uuid references auth.users (id) on delete set null,
  unique (room_id)
);

-- ---------------------------------------------------------------------------
-- v_case_statistics: live aggregate counts per room, scoped by
-- RLS (security_invoker inherits caller's row visibility — cannot
-- leak redacted counts — Architecture-Phase5.md §2.10, §6).
-- ---------------------------------------------------------------------------
create or replace function public.v_case_statistics()
returns table (
  room_id uuid,
  evidence_count bigint,
  people_count bigint,
  locations_count bigint,
  events_count bigint,
  contradictions_count bigint,
  gaps_count bigint,
  unverified_alibis_count bigint,
  ai_findings_count bigint
)
language sql
security invoker
stable
as $$
  select
    cr.id as room_id,
    count(distinct ei.id) as evidence_count,
    count(distinct e.id) filter (where e.entity_type = 'person') as people_count,
    count(distinct e.id) filter (where e.entity_type = 'location') as locations_count,
    count(distinct te.id) as events_count,
    count(distinct c.id) as contradictions_count,
    count(distinct ig.id) as gaps_count,
    count(distinct a.id) filter (
      where a.status is null or a.status in ('insufficient_data', 'conflict')
    ) as unverified_alibis_count,
    count(distinct asg.id) as ai_findings_count
  from public.case_rooms cr
  left join public.evidence_items ei on ei.room_id = cr.id
  left join public.entities e on e.room_id = cr.id
  left join public.timeline_events te on te.room_id = cr.id
  left join public.contradictions c on c.room_id = cr.id
  left join public.investigation_gaps ig on ig.room_id = cr.id
  left join public.alibis a on a.room_id = cr.id
  left join public.ai_suggestions asg on asg.room_id = cr.id
  where public.user_room_role(auth.uid(), cr.id) is not null
  group by cr.id;
$$;

-- v_case_statistics is a security_invoker FUNCTION (not a view):
-- functions take EXECUTE, not SELECT.
revoke execute on function public.v_case_statistics() from public, anon;
grant execute on function public.v_case_statistics() to authenticated;
