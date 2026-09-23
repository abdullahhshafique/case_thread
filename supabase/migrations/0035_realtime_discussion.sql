-- CaseThread migration 0035: add discussion_messages to the realtime
-- publication.
--
-- Sprint-5 gap (Phase-3 retro): supabase_flutter .stream() panes
-- silently no-op for tables missing from supabase_realtime; 0023 added
-- tasks + timeline_events but never discussion_messages. On
-- environments where the realtime service runs (cloud), the discussion
-- pane's stream hard-errors instead of no-opping. Standing rule
-- (Phases.md §6): any streamed table ships with its publication entry
-- + pgTAP assertion (realtime_publication_test.sql).

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'discussion_messages'
  ) then
    alter publication supabase_realtime add table public.discussion_messages;
  end if;
end
$$;
