-- CaseThread migration 0038: v_timeline regains the conflict flag.
--
-- 0023 added conflict_flag / conflict_resolved_at to timeline_events
-- (flag only by design — the note column is a tasks-table concern),
-- and the client selects conflict_flag through the redacted view — but
-- 0033's recreate of v_timeline used an explicit column list without
-- it, so every timeline read failed with 42703 (caught in the field
-- 2026-09-20). Recreate the view with the flag included; redaction of
-- payload fields is unchanged.

create or replace view public.v_timeline
with (security_barrier = true, security_invoker = true)
as
select
  id,
  room_id,
  event_type,
  actor_id,
  occurred_at,
  created_at,
  public.redact_payload(room_id, payload) as payload,
  classification,
  conflict_flag
from public.timeline_events;
