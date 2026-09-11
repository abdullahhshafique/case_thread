-- CaseThread migration 0003: audit_log immutability (Architecture.md §4).
--
-- The audit trail's append-only guarantee is enforced at the DATABASE
-- level, not in app logic — no UPDATE/DELETE path exists for ANY role,
-- including table owners. Two layers:
--   1. REVOKE the grants (SQL-level: even a bug in a policy can't update)
--   2. A BEFORE trigger that raises on UPDATE/DELETE (defense-in-depth
--      against service-role misuse)
-- RLS (migration 0005) separately controls who can INSERT/SELECT.

-- Layer 1: revoke row-modification grants from every role that has them.
-- (Supabase grants ALL to authenticated/anon/service_role by default.)
revoke update, delete on public.audit_log from authenticated, anon, service_role;

-- Layer 2: trigger guard — fires even for postgres/superusers who bypass
-- grants, making the immutability explicit and auditable.
create or replace function public.audit_log_immutable_guard()
returns trigger
language plpgsql
as $$
begin
  raise exception 'audit_log is append-only: % is not permitted (row id %)',
    tg_op, coalesce(old.id::text, 'n/a');
end;
$$;

drop trigger if exists audit_log_no_update on public.audit_log;
create trigger audit_log_no_update
  before update on public.audit_log
  for each row execute function public.audit_log_immutable_guard();

drop trigger if exists audit_log_no_delete on public.audit_log;
create trigger audit_log_no_delete
  before delete on public.audit_log
  for each row execute function public.audit_log_immutable_guard();

-- updated_at hygiene for the tables that have one (case_rooms, tasks):
-- keeps timestamps truthful without app-side trust.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists case_rooms_touch on public.case_rooms;
create trigger case_rooms_touch
  before update on public.case_rooms
  for each row execute function public.touch_updated_at();

drop trigger if exists tasks_touch on public.tasks;
create trigger tasks_touch
  before update on public.tasks
  for each row execute function public.touch_updated_at();
