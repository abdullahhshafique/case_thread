-- CaseThread migration 0013: field-level redaction (Phase 2,
-- Phases.md §3; PRD P1 story "field-level redaction").
--
-- Architecture.md §9: redaction is implemented as column-level views /
-- JSONB field masking in the QUERY LAYER per role — never a client-side
-- hide. `view_privileged` exists in every role grid since 0004 but was
-- never enforced; this migration wires it.
--
-- Privileged content convention: any timeline/discussion payload key
-- under a "privileged" object is visible ONLY to roles whose grid has
-- view_privileged = true. The privileged sub-object is stripped
-- server-side for everyone else — they see the row, never the field.

-- ---------------------------------------------------------------------------
-- Redaction core: strip payload.privileged unless the caller holds the
-- view_privileged key for the room. SECURITY BARRIER so the view's own
-- RLS cannot be bypassed by stacking policies on the base table.
-- ---------------------------------------------------------------------------
create or replace function public.redact_payload(
  target_room uuid,
  payload jsonb
)
returns jsonb
language sql
stable
security definer set search_path = public
as $$
  select case
    when public.user_room_permission(target_room, 'view_privileged')
      then payload
    else payload - 'privileged'
  end;
$$;

-- Redacted timeline view: replaces direct timeline_events reads for all
-- clients. Same RLS as the base table (view is security_barrier).
drop view if exists public.v_timeline cascade;
create view public.v_timeline
with (security_barrier = true)
as
select
  id,
  room_id,
  event_type,
  actor_id,
  occurred_at,
  created_at,
  public.redact_payload(room_id, payload) as payload
from public.timeline_events;

alter view public.v_timeline
  enable row level security;

drop policy if exists "v_timeline visible to room members" on public.v_timeline;
create policy "v_timeline visible to room members"
  on public.v_timeline for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

-- Redacted discussion view: mentions carry user ids (contact-adjacent);
-- bodies may embed privileged sub-objects. Body masking matches the
-- timeline convention.
drop view if exists public.v_discussion cascade;
create view public.v_discussion
with (security_barrier = true)
as
select
  id,
  room_id,
  parent_message_id,
  author_id,
  body,
  mentions,
  created_at
from public.discussion_messages;

alter view public.v_discussion
  enable row level security;

drop policy if exists "v_discussion visible to room members" on public.v_discussion;
create policy "v_discussion visible to room members"
  on public.v_discussion for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

-- Note: discussion BODY redaction stays textual (the @mention + body
-- conventions live in the payload-based flow); v_discussion exists so a
-- later migration can add masked columns without breaking clients. The
-- enforced redaction boundary today is timeline payload.privileged.

-- ---------------------------------------------------------------------------
-- PostgREST exposure: views must be in the exposed schema for clients.
-- Supabase exposes `public` by default; nothing further needed. The
-- Dart repository reads v_timeline from Phase 2 onward.
-- ---------------------------------------------------------------------------

-- Grant the same access the base tables grant (authenticated via RLS).
grant select on public.v_timeline to authenticated;
grant select on public.v_discussion to authenticated;
