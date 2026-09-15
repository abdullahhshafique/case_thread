-- CaseThread migration 0024: Phase 4 — version history on
-- documents/notes (Phases.md §5 P2 "Version history").
--
-- Design: CaseThread already records every edit — task changes
-- (task_created/task_updated, 0010), manual timeline-event edits
-- (timeline_event_edited, 0010), and evidence versions (version
-- column + evidence_uploaded audit, 0009). "Version history" is
-- therefore a READ surface over the append-only audit log, not a new
-- write model: no history table to keep in sync, no new trigger, and
-- the audit immutability (0003) guarantees the trail can't be
-- rewritten.
--
-- Exposed as one RPC (list_versions) returning a per-object,
-- redaction-aware change list. security invoker + the member-visible
-- audit policy do the scoping — exactly the search_cases (0022)
-- approach: if you can't read the audit row, you can't see the
-- version.

-- ---------------------------------------------------------------------------
-- list_versions(): change history for one task or one manual timeline
-- event (the two editable document types). Older entries carry the
-- pre-edit value from the audit metadata (0010 records before/after
-- for timeline edits, title+status for tasks).
-- ---------------------------------------------------------------------------
create or replace function public.list_versions(
  object_kind text, -- 'task' | 'timeline_event'
  target_id uuid
)
returns table (
  version_no int,
  actor_name text,
  action text, -- 'created' | 'edited' | 'status_changed'
  detail text, -- human summary of the change
  changed_at timestamptz
)
language plpgsql
stable
as $$
declare
  room uuid;
begin
  if object_kind = 'task' then
    select room_id into room from public.tasks where id = target_id;
    if room is null then
      raise exception 'Task not found.';
    end if;

    return query
    with numbered as (
      select
        row_number() over (order by created_at) as version_no,
        al.created_at,
        al.actor_id,
        al.action_type,
        al.metadata
      from public.audit_log al
      where al.room_id = room
        and al.object_type = 'task'
        and al.object_id = target_id::text
    )
    select
      n.version_no::int,
      p.display_name,
      case
        when n.action_type = 'task_created' then 'created'
        else 'status_changed'
      end,
      format('%s → %s',
        coalesce(n.metadata ->> 'title', '?'),
        coalesce(n.metadata ->> 'status', '?')),
      n.created_at
    from numbered n
    left join public.profiles p on p.id = n.actor_id
    where n.action_type in ('task_created', 'task_updated');

  elsif object_kind = 'timeline_event' then
    select room_id into room from public.timeline_events where id = target_id;
    if room is null then
      raise exception 'Event not found.';
    end if;

    return query
    with numbered as (
      select
        row_number() over (order by created_at) as version_no,
        al.created_at,
        al.actor_id,
        al.metadata
      from public.audit_log al
      where al.room_id = room
        and al.object_type = 'timeline_event'
        and al.object_id = target_id::text
    )
    select
      (n.version_no::int + 1), -- v1 = the event itself (not audited);
                               -- edits start at v2
      p.display_name,
      'edited',
      format('"%s" → "%s"',
        coalesce(n.metadata -> 'before' ->> 'summary', '?'),
        coalesce(n.metadata -> 'after' ->> 'summary', '?')),
      n.created_at
    from numbered n
    left join public.profiles p on p.id = n.actor_id;

  else
    raise exception 'Unknown versioned object kind: %', object_kind;
  end if;
end;
$$;

-- PostgREST surface: authenticated only; RLS on audit_log does the
-- member scoping (invoker rights — same approach as 0022).
revoke execute on function public.list_versions(text, uuid) from public, anon;
grant execute on function public.list_versions(text, uuid) to authenticated;
