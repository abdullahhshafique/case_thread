-- CaseThread migration 0041: fix the timeline-edit audit payload shape.
--
-- 0010's audit_timeline_edit() wrote metadata as flat scalars
-- ('before': 'old summary'), but list_versions() (0024) reads nested
-- objects (metadata -> 'before' ->> 'summary') — the `->` on a scalar
-- yields NULL, so every timeline version row rendered "? → ?".
-- Align the trigger with the reader: nest summary under before/after.

create or replace function public.audit_timeline_edit()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  perform public.append_audit(
    new.room_id,
    new.actor_id,
    'timeline_event_edited',
    'timeline_event',
    new.id::text,
    jsonb_build_object(
      'before', jsonb_build_object('summary', old.payload ->> 'summary'),
      'after', jsonb_build_object('summary', new.payload ->> 'summary')
    )
  );
  return new;
end;
$$;
