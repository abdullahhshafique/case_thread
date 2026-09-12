-- CaseThread migration 0010: timeline system events + edit/task
-- audit coverage (Sprint 5, ExecutionPlan.md §3).
--
-- Timeline sources (PRD §6.5): manual events (client, permission-gated
-- by 0005) + system events (mirrored from state changes). This
-- migration wires the mirrors via triggers that write through the
-- sanctioned append_audit() path (0007) — triggers can't be bypassed
-- by any future code path.
--   - join_requested / join_approved / member_revoked → timeline
--   - evidence_uploaded → timeline
--   - code_rotated → timeline
-- Manual-event edits are audited (PRD §6.5: "edits are themselves
-- logged").

-- ---------------------------------------------------------------------------
-- 1. Mirror audit actions into timeline_events (system type).
--    One trigger on audit_log INSERT; a small action whitelist keeps the
--    timeline signal-to-noise high (every audit row stays in audit_log).
-- ---------------------------------------------------------------------------
create or replace function public.mirror_audit_to_timeline()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  room uuid;
  actor uuid;
  summary text;
  payload jsonb;
begin
  if new.action_type in (
    'room_created', 'join_requested', 'join_approved', 'member_revoked',
    'evidence_uploaded', 'code_rotated', 'task_created', 'task_updated'
  ) then
    room := new.room_id;
    actor := new.actor_id;

    summary := case new.action_type
      when 'room_created' then 'Room created'
      when 'join_requested' then 'Join requested'
      when 'join_approved' then 'Member approved'
      when 'member_revoked' then 'Member revoked'
      when 'evidence_uploaded' then 'Evidence uploaded'
      when 'code_rotated' then 'Access code rotated'
      when 'task_created' then 'Task created'
      when 'task_updated' then 'Task updated'
    end;

    payload := jsonb_build_object(
      'action_type', new.action_type,
      'summary', summary,
      'audit_id', new.id,
      'details', new.metadata
    );

    insert into public.timeline_events
      (room_id, event_type, actor_id, payload, occurred_at)
    values
      (room, 'system', actor, payload, new.created_at);
  end if;

  return new;
end;
$$;

drop trigger if exists audit_to_timeline on public.audit_log;
create trigger audit_to_timeline
  after insert on public.audit_log
  for each row execute function public.mirror_audit_to_timeline();

-- ---------------------------------------------------------------------------
-- 2. Manual timeline-event edits are audited (PRD §6.5). The 0005 UPDATE
--    policy already restricts edits to the author with edit_case; this
--    trigger records what changed.
-- ---------------------------------------------------------------------------
create or replace function public.audit_timeline_edit()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  -- Only manual events are editable (enforced by policy); audit the edit.
  perform public.append_audit(
    new.room_id,
    new.actor_id,
    'timeline_event_edited',
    'timeline_event',
    new.id::text,
    jsonb_build_object(
      'before', old.payload ->> 'summary',
      'after', new.payload ->> 'summary'
    )
  );
  return new;
end;
$$;

drop trigger if exists timeline_edit_audited on public.timeline_events;
create trigger timeline_edit_audited
  after update on public.timeline_events
  for each row execute function public.audit_timeline_edit();

-- ---------------------------------------------------------------------------
-- 3. Task lifecycle mirrors: creation + status changes audited AND shown
--    on the timeline (a task completing is case progress).
-- ---------------------------------------------------------------------------
create or replace function public.audit_task_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  actor uuid;
begin
  -- updated_by doesn't exist; attribute to the assignee for done-ticks,
  -- creator otherwise (policy allows either to update).
  actor := case
    when new.status = 'done' and new.assignee_id is not null then new.assignee_id
    else new.created_by
  end;

  perform public.append_audit(
    new.room_id, actor,
    case when tg_op = 'INSERT' then 'task_created' else 'task_updated' end,
    'task', new.id::text,
    jsonb_build_object('title', new.title, 'status', new.status)
  );

  return coalesce(new, old);
end;
$$;

drop trigger if exists task_created_audited on public.tasks;
create trigger task_created_audited
  after insert on public.tasks
  for each row execute function public.audit_task_change();

drop trigger if exists task_updated_audited on public.tasks;
create trigger task_updated_audited
  after update on public.tasks
  for each row execute function public.audit_task_change();
