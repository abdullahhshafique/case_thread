-- Realtime publication contract (Phase-3 standing rule): every table
-- the client .stream()s must be in supabase_realtime — missing entries
-- make panes silently no-op locally and hard-error on cloud realtime.

begin;
select plan(1);

select is(
  (select count(distinct tablename) from pg_publication_tables
   where pubname = 'supabase_realtime'
     and schemaname = 'public'
     and tablename in ('discussion_messages', 'timeline_events', 'tasks')),
  3::bigint,
  'discussion_messages, timeline_events, tasks are all in supabase_realtime'
);

select * from finish();
rollback;
