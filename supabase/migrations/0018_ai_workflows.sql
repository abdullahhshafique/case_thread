-- CaseThread migration 0018: Phase 3 — workflow builder persistence +
-- realtime publication (Phases.md §4 "workflow builder" P0 epic).
--
-- Rules.md §11 invariants, unchanged:
--   * Workflows are HUMAN-written configs (edit_case tier) saved per
--     room — direct client writes allowed, unlike suggestions.
--   * Runs are written ONLY by the Edge Function (service role) —
--     no client insert/update policy exists, mirroring ai_suggestions.
--   * Agents still write nothing but ai_suggestions (pending); a
--     chained run just produces SEVERAL pending suggestions, one
--     per step, each individually human-reviewable.

-- ---------------------------------------------------------------------------
-- ai_workflows: saved agent chains (the "workflow builder" data).
-- steps = ordered agent-id strings, 1–5 (server-enforced; agent ids
-- themselves are validated by the Edge Function against the registry).
-- ---------------------------------------------------------------------------
create table if not exists public.ai_workflows (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  name text not null,
  steps jsonb not null check (
    case
      when jsonb_typeof(steps) = 'array'
      then jsonb_array_length(steps) between 1 and 5
      else false
    end
  ),
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists ai_workflows_room_idx on public.ai_workflows (room_id);

alter table public.ai_workflows enable row level security;

-- Members can see a room's workflows (the builder lists them).
drop policy if exists "ai workflows visible to room members" on public.ai_workflows;
create policy "ai workflows visible to room members"
  on public.ai_workflows for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

-- edit_case holders create workflows (UI hides; DB refuses).
drop policy if exists "ai workflows insertable by permitted members" on public.ai_workflows;
create policy "ai workflows insertable by permitted members"
  on public.ai_workflows for insert
  to authenticated
  with check (public.user_room_permission(room_id, 'edit_case'));

drop policy if exists "ai workflows updatable by permitted members" on public.ai_workflows;
create policy "ai workflows updatable by permitted members"
  on public.ai_workflows for update
  to authenticated
  using (public.user_room_permission(room_id, 'edit_case'));

drop policy if exists "ai workflows deletable by permitted members" on public.ai_workflows;
create policy "ai workflows deletable by permitted members"
  on public.ai_workflows for delete
  to authenticated
  using (public.user_room_permission(room_id, 'edit_case'));

-- ---------------------------------------------------------------------------
-- ai_workflow_runs: one row per chained execution. Written by the
-- Edge Function (service role) only; clients read to watch progress.
-- ---------------------------------------------------------------------------
create table if not exists public.ai_workflow_runs (
  id uuid primary key default gen_random_uuid(),
  workflow_id uuid not null references public.ai_workflows (id) on delete cascade,
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  status text not null default 'running'
    check (status in ('running', 'completed', 'failed')),
  steps_total int not null,
  steps_done int not null default 0,
  suggestion_ids jsonb not null default '[]'::jsonb,
  error text,
  started_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

create index if not exists ai_workflow_runs_room_idx
  on public.ai_workflow_runs (room_id, created_at desc);

alter table public.ai_workflow_runs enable row level security;

-- Runs visible to room members; NO client write policies — the Edge
-- Function owns run lifecycle (service role bypasses RLS), mirroring
-- the ai_suggestions insert contract.
drop policy if exists "ai workflow runs visible to room members" on public.ai_workflow_runs;
create policy "ai workflow runs visible to room members"
  on public.ai_workflow_runs for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

-- ---------------------------------------------------------------------------
-- Realtime (closes the Architecture.md §7 gap: "Realtime pushes the
-- pending suggestion to the room"). supabase_flutter's .stream() uses
-- postgres_changes; tables must be in the supabase_realtime
-- publication. RLS still filters what each subscriber may receive.
--
-- The publication may not exist in local stacks started with the
-- realtime service excluded — create it (empty, cloud-default shape)
-- so both paths converge. add-table is guarded against re-apply.
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end
$$;

do $$
begin
  begin
    alter publication supabase_realtime add table public.ai_suggestions;
  exception
    when duplicate_object then null; -- already in the publication
  end;
  begin
    alter publication supabase_realtime add table public.ai_workflow_runs;
  exception
    when duplicate_object then null;
  end;
end
$$;
