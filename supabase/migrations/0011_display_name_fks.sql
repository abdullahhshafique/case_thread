-- CaseThread migration 0011: display-name embed FKs for Sprint 5 UI.
--
-- PostgREST relationship embeds need declared FKs (same as 0008 did
-- for room_members). Timeline actor names and task assignee names are
-- rendered in the UI; add the FKs so `timeline_events` and `tasks`
-- can embed `profiles`.

alter table public.timeline_events
  add constraint timeline_events_profile_fkey
  foreign key (actor_id) references public.profiles (id) on delete set null;

alter table public.tasks
  add constraint tasks_assignee_profile_fkey
  foreign key (assignee_id) references public.profiles (id) on delete set null;
