-- CaseThread migration 0033: per-room breakdown statistics for the
-- dashboard graphs (Phase 6, instructor doc §9 — "meaningful rather
-- than decorative" graphs).
--
-- v_case_breakdown(target_room) is a SECURITY INVOKER function like
-- v_case_statistics (0026): it can only be called by room members
-- (RLS deny → empty result), so evidence-type and events-per-day
-- data never leak across rooms.

create or replace function public.v_case_breakdown(target_room uuid)
returns jsonb
language sql
security invoker
stable
as $$
  select jsonb_build_object(
    'evidence_by_type', (
      select coalesce(jsonb_object_agg(group_key, n), '{}'::jsonb)
      from (
        select case
                 when mime_type like 'image/%' then 'image'
                 when mime_type like 'video/%' then 'video'
                 when mime_type like 'audio/%' then 'audio'
                 when mime_type = 'application/pdf' then 'pdf'
                 else 'other'
               end as group_key,
               count(*) as n
        from public.evidence_items
        where room_id = target_room
        group by 1
      ) g
    ),
    'events_per_day', (
      select coalesce(jsonb_object_agg(day, n order by day), '{}'::jsonb)
      from (
        select (occurred_at at time zone 'utc')::date::text as day,
               count(*) as n
        from public.timeline_events
        where room_id = target_room
          and occurred_at >= now() - interval '14 days'
        group by 1
      ) d
    )
  );
$$;

revoke execute on function public.v_case_breakdown(uuid) from public, anon;
grant execute on function public.v_case_breakdown(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- v_timeline: expose the 0027 classification column (append-only change,
-- keeps 0013's column order and the security_barrier setting).
-- ---------------------------------------------------------------------------
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
  classification
from public.timeline_events;
