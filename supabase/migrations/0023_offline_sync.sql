-- CaseThread migration 0023: Phase 4 — offline-sync conflict
-- infrastructure (docs/offline-sync-conflict-policy.md, the approved
-- design gate; Phases.md §5 risk note).
--
-- The policy in one line: writes queue locally with full author
-- context; on reconnect they replay through the SAME RPC/RLS paths as
-- live writes; divergent single-field writes resolve last-write-wins
-- and are visibly flagged; security-sensitive writes never queue.
--
-- This migration provides the SERVER half:
--   * LWW stamping on tasks/timeline edits: a replay that arrives with
--     an older client_value_at than the row's last server change
--     LOSES and the row gets conflict metadata (policy §2/§3).
--   * clear_conflict(): members clear the advisory flag; audited.
--   * tasks + timeline added to the realtime publication (the
--     Phase-3-retro rule, applied to Sprint-5's streamed tables that
--     predate it).
--
-- The CLIENT half (Dart offline queue + replay + banner) lives in
-- lib/features/offline/. Replay uses existing endpoints only:
-- postMessage inserts, task updates, updateTaskStatus — no new
-- write paths exist, by design (policy §2 "no new bypass endpoints").

-- ---------------------------------------------------------------------------
-- 1. Conflict metadata columns (policy §4 — advisory, mutable, small).
--    timeline_events: payload-level conflict block (manual events only).
--    tasks: flag + note (classic two-members-flip-status case).
-- ---------------------------------------------------------------------------
alter table public.timeline_events
  add column if not exists conflict_flag boolean not null default false,
  add column if not exists conflict_resolved_at timestamptz;

alter table public.tasks
  add column if not exists conflict_flag boolean not null default false,
  add column if not exists conflict_note text,
  add column if not exists conflict_resolved_at timestamptz;

-- ---------------------------------------------------------------------------
-- 2. update_task_with_stamp(): LWW-stamped task update — the sanctioned
--    replay endpoint for queued task mutations. SECURITY DEFINER would
--    BYPASS RLS; instead the RPC re-checks membership + permission via
--    the same helper every policy uses, then updates through the table
--    (whose RLS re-evaluates on the RPC's invoker context).
--
--    client_value_at: when the OFFLINE device last wrote this field
--    (its queued_at). If the server row changed LATER (updated_at >
--    client_value_at), the server value wins and the row is flagged.
-- ---------------------------------------------------------------------------
create or replace function public.update_task_with_stamp(
  target_task uuid,
  new_status text,
  client_value_at timestamptz
)
returns text -- 'applied' | 'conflict_server_won'
language plpgsql
as $$
declare
  t public.tasks%rowtype;
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'Not authenticated';
  end if;

  if new_status not in ('open', 'in_progress', 'done') then
    raise exception 'Unknown task status: %', new_status;
  end if;

  select * into t from public.tasks where id = target_task;
  if t.id is null then
    raise exception 'Task not found.';
  end if;

  -- Same permission boundary as the live UPDATE policy (0005):
  -- edit_case roles, or the assignee flipping status.
  if not (
    public.user_room_permission(t.room_id, 'edit_case')
    or t.assignee_id = caller_id
  ) then
    raise exception 'Your role can''t update tasks in this room.';
  end if;

  -- LWW (policy §2): if the row changed after the client's snapshot,
  -- the server value wins; keep the flag visible for the loser's author.
  if t.updated_at > client_value_at then
    update public.tasks
    set conflict_flag = true,
        conflict_note = format(
          'Offline edit at %s lost to a newer change at %s.',
          client_value_at, t.updated_at
        ),
        conflict_resolved_at = null
    where id = t.id;
    return 'conflict_server_won';
  end if;

  update public.tasks
  set status = new_status,
      updated_at = now(),
      conflict_flag = false,
      conflict_note = null,
      conflict_resolved_at = null
  where id = t.id;

  -- Audit via the existing trigger (task_updated, 0010) — this UPDATE
  -- passes through it exactly like a live one.
  return 'applied';
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. edit_timeline_event_with_stamp(): LWW for manual-event edits —
--    the second queued-write class. Same shape as the task stamp: the
--    policy allows the author (edit_case) to edit own manual events.
-- ---------------------------------------------------------------------------
create or replace function public.edit_timeline_event_with_stamp(
  target_event uuid,
  new_summary text,
  client_value_at timestamptz
)
returns text -- 'applied' | 'conflict_server_won'
language plpgsql
as $$
declare
  e public.timeline_events%rowtype;
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into e from public.timeline_events where id = target_event;
  if e.id is null then
    raise exception 'Event not found.';
  end if;

  -- Mirrors the 0005 UPDATE policy: author's own manual event + edit_case.
  if not (
    e.actor_id = caller_id
    and e.event_type = 'manual'
    and public.user_room_permission(e.room_id, 'edit_case')
  ) then
    raise exception 'Your role can''t edit this timeline event.';
  end if;

  -- LWW: manual events have no updated_at; the mirror row's created_at
  -- in v_timeline is the event's own stamp. Use the latest audit row
  -- (timeline_event_edited) — absent means never edited server-side.
  if exists (
    select 1 from public.audit_log al
    where al.room_id = e.room_id
      and al.object_type = 'timeline_event'
      and al.object_id = e.id::text
      and al.action_type = 'timeline_event_edited'
      and al.created_at > client_value_at
  ) then
    update public.timeline_events
    set conflict_flag = true,
        conflict_resolved_at = null
    where id = e.id;
    return 'conflict_server_won';
  end if;

  update public.timeline_events
  set payload = jsonb_set(payload, '{summary}', to_jsonb(new_summary)),
      conflict_flag = false,
      conflict_resolved_at = null
  where id = e.id;

  -- Edit audit fires through the 0010 trigger (timeline_event_edited).
  return 'applied';
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. clear_conflict(): any permitted member clears the advisory flag
--    on a task or manual timeline event; clearing is audited (policy
--    §4). SECURITY DEFINER — the base UPDATE policies are author-only
--    (0005) but clearing is a room-level act, so this function does
--    its own permission check via the same helper and writes directly.
--    It flips ONLY the advisory conflict columns — never case data.
-- ---------------------------------------------------------------------------
create or replace function public.clear_conflict(
  object_kind text, -- 'task' | 'timeline_event'
  target_id uuid
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  room uuid;
begin
  if caller_id is null then
    raise exception 'Not authenticated';
  end if;

  if object_kind = 'task' then
    select room_id into room from public.tasks where id = target_id;
    if room is null then
      raise exception 'Task not found.';
    end if;
    if not public.user_room_permission(room, 'edit_case') then
      raise exception 'Your role can''t manage tasks in this room.';
    end if;

    update public.tasks
    set conflict_flag = false,
        conflict_resolved_at = now()
    where id = target_id and conflict_flag;

    perform public.append_audit(
      room, caller_id, 'conflict_cleared', 'task', target_id::text,
      jsonb_build_object('kind', 'task')
    );

  elsif object_kind = 'timeline_event' then
    select room_id into room from public.timeline_events where id = target_id;
    if room is null then
      raise exception 'Event not found.';
    end if;
    if not public.user_room_permission(room, 'edit_case') then
      raise exception 'Your role can''t edit this room''s timeline.';
    end if;

    update public.timeline_events
    set conflict_flag = false,
        conflict_resolved_at = now()
    where id = target_id and conflict_flag;

    perform public.append_audit(
      room, caller_id, 'conflict_cleared', 'timeline_event',
      target_id::text, jsonb_build_object('kind', 'timeline_event')
    );

  else
    raise exception 'Unknown conflict object kind: %', object_kind;
  end if;
end;
$$;

-- PostgREST surface: authenticated callers only. The functions enforce
-- their own permission checks (same helpers the RLS policies use).
revoke execute on function public.update_task_with_stamp(uuid, text, timestamptz) from public, anon;
grant execute on function public.update_task_with_stamp(uuid, text, timestamptz) to authenticated;
revoke execute on function public.edit_timeline_event_with_stamp(uuid, text, timestamptz) from public, anon;
grant execute on function public.edit_timeline_event_with_stamp(uuid, text, timestamptz) to authenticated;
revoke execute on function public.clear_conflict(text, uuid) from public, anon;
grant execute on function public.clear_conflict(text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Realtime publication (Phase-3-retro standing rule): tasks and
--    timeline_events are streamed by Sprint-5 panes but predate the
--    rule — close the gap now that offline resync leans on the same
--    streams for the "re-pull deltas" step (policy §3.4).
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
    alter publication supabase_realtime add table public.tasks;
  exception
    when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.timeline_events;
  exception
    when duplicate_object then null;
  end;
end
$$;
