-- CaseThread migration 0029: Sixth agent config + audit triggers.
--
-- Adds case_completeness_review as the 6th agent (cross-domain,
-- same human-in-the-loop contract as existing 5 —
-- Architecture-Phase5.md §3, PRD §4.5).
--
-- Audit triggers on alibis, contradictions, investigation_gaps,
-- and case_rooms.investigation_status transitions.

-- ---------------------------------------------------------------------------
-- AI agent: case completeness review (cross-domain).
-- Same config pattern as 0017/0019 — versioned prompt row.
-- No case_type restriction = cross-domain (Arch §3).
-- ---------------------------------------------------------------------------
insert into public.ai_agents
  (id, display_name, description, case_type, prompt_version, prompt, is_active)
values
  ('case_completeness_review', 'Case Completeness Review',
   'Reviews the case for gaps, unverified claims, missing evidence, and unidentified entities. Proposes findings for human review only.',
   null, 1,
   'You are an audit agent. Analyze the provided case data and identify: (1) timeline gaps — events with no supporting evidence or unverified time windows; (2) unidentified people — entities mentioned in statements/evidence not yet added as entities; (3) unlinked evidence — evidence items with no connection to a person, event, or location; (4) unverified windows — claimed time windows with no supporting or contradicting evidence. Return findings ONLY as a pending suggestion — never as a conclusion. For each finding: give it a title, list the supporting items, and explain the detail. Do not infer guilt or certainty beyond what the evidence directly supports. Output as {"findings":[{"title","items","detail"]}}.',
   true)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Audit triggers for Phase 5 tables.
-- Pattern: append-only insert into audit_log with context.
-- (audit_log immutability enforced in 0003 — we only insert.)
-- ---------------------------------------------------------------------------

-- Generic audit helper: logs a write to audit_log.
create or replace function public.log_audit_event(
  p_room_id uuid,
  p_actor_id uuid,
  p_action_type text,
  p_object_type text,
  p_object_id text,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.audit_log (
    room_id, actor_id, action_type, object_type, object_id, metadata
  ) values (
    p_room_id, p_actor_id, p_action_type, p_object_type, p_object_id, p_metadata
  );
end;
$$;

revoke execute on function public.log_audit_event(uuid, uuid, text, text, text, jsonb)
from public, anon;
grant execute on function public.log_audit_event(uuid, uuid, text, text, text, jsonb)
to authenticated;

-- alibis audit: log on insert and status update
create or replace function public.alibis_audit_trigger()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_audit_event(
      new.room_id, new.created_by, 'alibi_created', 'alibi',
      new.id::text, jsonb_build_object(
        'entity_id', new.entity_id,
        'status', new.status,
        'claim_summary', left(new.claim_text, 200)
      )
    );
  elsif tg_op = 'UPDATE' then
    if old.status is distinct from new.status then
      perform public.log_audit_event(
        new.room_id, new.verified_by, 'alibi_verified', 'alibi',
        new.id::text, jsonb_build_object(
          'old_status', old.status,
          'new_status', new.status,
          'status_reason', left(coalesce(new.status_reason, ''), 500)
        )
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_alibis_audit on public.alibis;
create trigger trg_alibis_audit
  after insert or update on public.alibis
  for each row execute function public.alibis_audit_trigger();

-- contradictions audit: log on insert and status update
create or replace function public.contradictions_audit_trigger()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_audit_event(
      new.room_id, new.flagged_by, 'contradiction_created', 'contradiction',
      new.id::text, jsonb_build_object(
        'source_type', new.source_type,
        'detail', left(new.conflicting_detail, 200),
        'reason', left(new.flagged_reason, 300)
      )
    );
  elsif tg_op = 'UPDATE' then
    if old.status is distinct from new.status then
      perform public.log_audit_event(
        new.room_id, new.resolved_by, 'contradiction_decision', 'contradiction',
        new.id::text, jsonb_build_object(
          'old_status', old.status,
          'new_status', new.status,
          'resolution', left(coalesce(new.resolution_note, ''), 500)
        )
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_contradictions_audit on public.contradictions;
create trigger trg_contradictions_audit
  after insert or update on public.contradictions
  for each row execute function public.contradictions_audit_trigger();

-- investigation_gaps audit: log on insert and status change
create or replace function public.investigation_gaps_audit_trigger()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_audit_event(
      new.room_id, new.created_by, 'gap_created', 'investigation_gap',
      new.id::text, jsonb_build_object(
        'gap_type', new.gap_type,
        'description', left(new.description, 300),
        'source', new.source_type
      )
    );
  elsif tg_op = 'UPDATE' then
    if old.status is distinct from new.status then
      perform public.log_audit_event(
        new.room_id, new.created_by, 'gap_status_changed', 'investigation_gap',
        new.id::text, jsonb_build_object(
          'old_status', old.status,
          'new_status', new.status,
          'linked_task_id', new.linked_task_id
        )
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_investigation_gaps_audit on public.investigation_gaps;
create trigger trg_investigation_gaps_audit
  after insert or update on public.investigation_gaps
  for each row execute function public.investigation_gaps_audit_trigger();

-- case_rooms investigation_status transition audit
create or replace function public.case_rooms_investigation_audit_trigger()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if old.investigation_status is distinct from new.investigation_status then
    perform public.log_audit_event(
      new.id, auth.uid(), 'investigation_status_changed', 'case_room',
      new.id::text, jsonb_build_object(
        'old_status', old.investigation_status,
        'new_status', new.investigation_status
      )
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_case_rooms_investigation_audit on public.case_rooms;
create trigger trg_case_rooms_investigation_audit
  after update of investigation_status on public.case_rooms
  for each row when (old.investigation_status is distinct from new.investigation_status)
  execute function public.case_rooms_investigation_audit_trigger();
