-- CaseThread migration 0030: Phase 5 RPC functions.
--
-- All functions use security definer (existing pattern,
-- Architecture.md §7) and are callable via PostgREST.
-- Permission checks inside each function mirror the
-- RLS policies from migration 0028.

-- ---------------------------------------------------------------------------
-- verify_alibi: record a verification pass with status + reason.
-- Writes status, reason, links, and audit in one transaction.
-- ---------------------------------------------------------------------------
create or replace function public.verify_alibi(
  p_alibi_id uuid,
  p_status text,
  p_status_reason text,
  p_evidence_item_ids uuid[] default '{}',
  p_timeline_event_ids uuid[] default '{}'
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_alibi public.alibis%rowtype;
  v_room uuid;
begin
  select * into v_alibi
    from public.alibis where id = p_alibi_id;

  if v_alibi.id is null then
    raise exception 'Alibi not found: %', p_alibi_id;
  end if;

  v_room := v_alibi.room_id;

  -- Permission: edit_case or the original creator
  if not (
    public.user_room_permission(v_room, 'edit_case')
    or auth.uid() = v_alibi.created_by
  ) then
    raise exception 'Permission denied: cannot verify alibi in room %', v_room;
  end if;

  -- Validate status
  if p_status not in ('verified', 'partially_verified', 'conflict', 'insufficient_data') then
    raise exception 'Invalid status: %', p_status;
  end if;

  if p_status is not null and (p_status_reason is null or char_length(p_status_reason) < 1) then
    raise exception 'status_reason is required when status is set';
  end if;

  -- Update alibi
  update public.alibis set
    status = p_status,
    status_reason = p_status_reason,
    verified_by = auth.uid(),
    verified_at = now()
  where id = p_alibi_id;

  -- Remove old links
  delete from public.alibi_evidence_links where alibi_id = p_alibi_id;

  -- Insert new evidence links
  if p_evidence_item_ids is not null then
    insert into public.alibi_evidence_links (alibi_id, evidence_item_id, relation)
    select p_alibi_id, unnest(p_evidence_item_ids), 'supports';
  end if;

  if p_timeline_event_ids is not null then
    insert into public.alibi_evidence_links (alibi_id, timeline_event_id, relation)
    select p_alibi_id, unnest(p_timeline_event_ids), 'supports';
  end if;

  -- Audit (handled by trigger on update)
end;
$$;

revoke execute on function public.verify_alibi(uuid, text, text, uuid[], uuid[])
from public, anon;
grant execute on function public.verify_alibi(uuid, text, text, uuid[], uuid[])
to authenticated;

-- ---------------------------------------------------------------------------
-- contradiction_decision: resolve, dismiss, or create task
-- from a contradiction (PRD §4.3, PDF §15).
-- ---------------------------------------------------------------------------
create or replace function public.contradiction_decision(
  p_contradiction_id uuid,
  p_decision text, -- 'resolve' | 'dismiss'
  p_resolution_note text default '',
  p_linked_task_id uuid default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_contradiction public.contradictions%rowtype;
  v_room uuid;
begin
  select * into v_contradiction
    from public.contradictions where id = p_contradiction_id;

  if v_contradiction.id is null then
    raise exception 'Contradiction not found: %', p_contradiction_id;
  end if;

  v_room := v_contradiction.room_id;

  -- Permission: approve_ai_findings (Lead tier) or edit_case
  if not (
    public.user_room_permission(v_room, 'approve_ai_findings')
    or public.user_room_permission(v_room, 'edit_case')
  ) then
    raise exception 'Permission denied: cannot review contradiction %', p_contradiction_id;
  end if;

  if p_decision = 'resolve' then
    update public.contradictions set
      status = 'resolved',
      resolution_note = p_resolution_note,
      linked_task_id = p_linked_task_id,
      resolved_by = auth.uid(),
      resolved_at = now()
    where id = p_contradiction_id;
  elsif p_decision = 'dismiss' then
    update public.contradictions set
      status = 'dismissed',
      resolution_note = p_resolution_note,
      resolved_by = auth.uid(),
      resolved_at = now()
    where id = p_contradiction_id;
  else
    raise exception 'Invalid decision: %', p_decision;
  end if;
end;
$$;

revoke execute on function public.contradiction_decision(uuid, text, text, uuid)
from public, anon;
grant execute on function public.contradiction_decision(uuid, text, text, uuid)
to authenticated;

-- ---------------------------------------------------------------------------
-- gap_create_task: one-click gap → task (PRD §4.4, PDF §21).
-- ---------------------------------------------------------------------------
create or replace function public.gap_create_task(
  p_gap_id uuid,
  p_task_title text,
  p_task_description text default ''
)
returns uuid -- the new task id
language plpgsql
security definer set search_path = public
as $$
declare
  v_gap public.investigation_gaps%rowtype;
  v_room uuid;
  v_task_id uuid;
begin
  select * into v_gap
    from public.investigation_gaps where id = p_gap_id;

  if v_gap.id is null then
    raise exception 'Gap not found: %', p_gap_id;
  end if;

  v_room := v_gap.room_id;

  if not (
    public.user_room_permission(v_room, 'edit_case')
    or auth.uid() = v_gap.created_by
  ) then
    raise exception 'Permission denied: cannot create task from gap %', p_gap_id;
  end if;

  insert into public.tasks (
    room_id, title, assignee_id, created_by, status, linked_evidence_id
  ) values (
    v_room, p_task_title, null, auth.uid(), 'open', null
  ) returning id into v_task_id;

  update public.investigation_gaps set
    linked_task_id = v_task_id,
    status = 'in_progress'
  where id = p_gap_id;

  return v_task_id;
end;
$$;

revoke execute on function public.gap_create_task(uuid, text, text)
from public, anon;
grant execute on function public.gap_create_task(uuid, text, text)
to authenticated;

-- ---------------------------------------------------------------------------
-- transition_investigation_status: change case investigation
-- status. Generates closed summary on transition to 'closed'.
-- ---------------------------------------------------------------------------
create or replace function public.transition_investigation_status(
  p_room_id uuid,
  p_new_status text
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_room public.case_rooms%rowtype;
  v_summary jsonb;
begin
  select * into v_room from public.case_rooms where id = p_room_id;

  if v_room.id is null then
    raise exception 'Room not found: %', p_room_id;
  end if;

  -- Permission: room owner only (PRD §4.6 — the investigation
  -- lifecycle is an owner decision, not an edit_case one).
  if v_room.owner_id <> auth.uid() then
    raise exception 'Only the room owner can change investigation status';
  end if;

  if p_new_status not in ('open', 'under_investigation', 'review', 'closed') then
    raise exception 'Invalid investigation status: %', p_new_status;
  end if;

  -- Update status (trigger logs the audit)
  update public.case_rooms set
    investigation_status = p_new_status
  where id = p_room_id;

  -- On transition to closed: generate summary
  if p_new_status = 'closed' then
    v_summary := jsonb_build_object(
      'case_overview', jsonb_build_object(
        'room_name', v_room.name,
        'room_status', v_room.status,
        'investigation_status', p_new_status,
        'case_type', v_room.case_type,
        'opened', v_room.created_at
      ),
      'people', (
        select jsonb_agg(jsonb_build_object(
          'id', e.id, 'name', e.name, 'type', e.entity_type,
          'attributes', e.attributes
        ))
        from public.entities e
        where e.room_id = p_room_id
      ),
      'evidence', (
        select jsonb_agg(jsonb_build_object(
          'id', ei.id, 'filename', ei.filename,
          'mime_type', ei.mime_type
        ))
        from public.evidence_items ei
        where ei.room_id = p_room_id
      ),
      'major_events', (
        select jsonb_agg(jsonb_build_object(
          'id', te.id, 'type', te.event_type,
          'occurred_at', te.occurred_at,
          'summary', te.payload->>'summary'
        ) order by te.occurred_at)
        from public.timeline_events te
        where te.room_id = p_room_id
      ),
      'contradictions', (
        select jsonb_agg(jsonb_build_object(
          'id', c.id, 'detail', c.conflicting_detail,
          'status', c.status, 'flagged_by', c.flagged_by
        ))
        from public.contradictions c
        where c.room_id = p_room_id
      ),
      'unresolved_gaps', (
        select jsonb_agg(jsonb_build_object(
          'id', ig.id, 'description', ig.description,
          'gap_type', ig.gap_type
        ))
        from public.investigation_gaps ig
        where ig.room_id = p_room_id and ig.status = 'open'
      ),
      'relationships', (
        select jsonb_agg(jsonb_build_object(
          'from', e1.name, 'to', e2.name,
          'type', er.relationship_type
        ))
        from public.entity_relationships er
        join public.entities e1 on e1.id = er.from_entity_id
        join public.entities e2 on e2.id = er.to_entity_id
        where er.room_id = p_room_id
      )
    );

    insert into public.case_closed_summaries (
      room_id, summary_json, generated_by
    ) values (
      p_room_id, v_summary, auth.uid()
    );
  end if;
end;
$$;

revoke execute on function public.transition_investigation_status(uuid, text)
from public, anon;
grant execute on function public.transition_investigation_status(uuid, text)
to authenticated;
