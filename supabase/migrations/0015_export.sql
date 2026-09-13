-- CaseThread migration 0015: case export (Phase 2, Phases.md §3 P1).
--
-- Architecture.md §7 export flow: Lead triggers export → compile case
-- summary + timeline + approved findings → document generated → audit
-- entry recorded. The DB owns everything security-relevant: permission
-- gating (export_reports), redaction (0013), and the audit entry. The
-- document itself is emitted as structured JSON (the client renders
-- PDF/Word locally from it — no privileged data can leak because the
-- DB already stripped what the caller can't see).

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

  -- Permission gate: export_reports (owner holds it implicitly — the
  -- UI gating uses owner-override; enforce the same server-side).
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

  -- Compile the document. Timeline payloads pass redact_payload so
  -- privileged fields never leave the DB for this caller.
  select jsonb_build_object(
    'kind', 'case_thread_export',
    'version', 1,
    'generated_at', now(),
    'room', jsonb_build_object(
      'name', room_row.name,
      'case_type', room_row.case_type,
      'status', room_row.status,
      'opened', room_row.created_at
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
    )
  ) into doc;

  -- The export itself is audited (PRD §6.5: every state-changing action).
  perform public.append_audit(
    target_room, caller_id, 'report_exported', 'case_room', target_room::text,
    jsonb_build_object('document_version', 1)
  );

  return doc;
end;
$$;
