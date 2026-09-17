-- CaseThread migration 0031: extend export_case_report (Phase 5).
--
-- Architecture.md §4: export service extends its compiled
-- content to include contradictions, alibis, gaps, and
-- investigation_status alongside the existing summary/timeline/
-- findings (PRD §23).
--
-- Uses CREATE OR REPLACE FUNCTION (additive: the function
-- definition is replaced, no prior migration is edited).

create or replace function public.export_case_report(target_room uuid)
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  room_row public.case_rooms%rowtype;
  can_export boolean;
  doc jsonb;
begin
  if caller_id is null then
    raise exception 'Not authenticated';
  end if;

  select exists (
    select 1 from public.case_rooms cr
    where cr.id = target_room and cr.owner_id = caller_id
  ) or public.user_room_permission(target_room, 'export_reports')
  into can_export;

  if not can_export then
    raise exception 'Your role cannot export reports in this room.';
  end if;

  select * into room_row from public.case_rooms where id = target_room;
  if room_row.id is null then
    raise exception 'Invalid or inactive room.';
  end if;

  select jsonb_build_object(
    'kind', 'case_thread_export',
    'version', 2,
    'generated_at', now(),
    'room', jsonb_build_object(
      'name', room_row.name,
      'case_type', room_row.case_type,
      'status', room_row.status,
      'opened', room_row.created_at,
      'investigation_status', room_row.investigation_status
    ),
    'members', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'name', p.display_name,
        'role', rm.role_id,
        'status', rm.status,
        'joined', rm.joined_at
      ) order by rm.joined_at nulls last), '[]'::jsonb)
      from public.room_members rm
      join public.profiles p on p.id = rm.user_id
      where rm.room_id = target_room and rm.status = 'approved'
    ),
    'timeline', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'when', te.occurred_at,
        'type', te.event_type,
        'actor', p.display_name,
        'payload', public.redact_payload(target_room, te.payload)
      ) order by te.occurred_at), '[]'::jsonb)
      from public.timeline_events te
      left join public.profiles p on p.id = te.actor_id
      where te.room_id = target_room
    ),
    'tasks', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'title', t.title,
        'status', t.status,
        'assignee', p.display_name,
        'due', t.due_date
      ) order by t.created_at), '[]'::jsonb)
      from public.tasks t
      left join public.profiles p on p.id = t.assignee_id
      where t.room_id = target_room
    ),
    'evidence', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'filename', e.filename,
        'version', e.version,
        'sha256', e.file_hash,
        'uploaded', e.uploaded_at
      ) order by e.uploaded_at), '[]'::jsonb)
      from public.evidence_items e
      where e.room_id = target_room
    ),
    'contradictions', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'status', c.status,
        'detail', c.conflicting_detail,
        'flagged_reason', c.flagged_reason
      ) order by c.created_at desc), '[]'::jsonb)
      from public.contradictions c
      where c.room_id = target_room
    ),
    'alibis', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'status', a.status,
        'claim', a.claim_text,
        'window_start', a.claimed_window_start,
        'window_end', a.claimed_window_end
      ) order by a.created_at desc), '[]'::jsonb)
      from public.alibis a
      where a.room_id = target_room
    ),
    'gaps', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'status', g.status,
        'description', g.description,
        'gap_type', g.gap_type
      ) order by g.created_at desc), '[]'::jsonb)
      from public.investigation_gaps g
      where g.room_id = target_room
    )
  ) into doc;

  perform public.append_audit(
    target_room, caller_id, 'report_exported', 'case_room', target_room::text,
    jsonb_build_object('document_version', 2)
  );

  return doc;
end;
$$;
