-- CaseThread migration 0014: notification/activity feed (Phase 2,
-- Phases.md §3 P1; Architecture.md §4 "what changed since you last
-- opened this room").
--
-- Design: the audit log is the canonical activity stream; each member
-- carries a last_seen watermark per room. The feed view = audit rows
-- in the member's rooms newer than their watermark — redaction-aware
-- (0013): privileged sub-objects never enter feed payloads for roles
-- lacking view_privileged.

-- Per-room, per-member watermark. Updated when the member opens the
-- room (or marks-reads). Additive table — no core changes.
create table if not exists public.room_last_seen (
  user_id uuid not null references auth.users (id) on delete cascade,
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  last_seen_at timestamptz not null default now(),
  primary key (user_id, room_id)
);

alter table public.room_last_seen enable row level security;

-- Own watermark only.
drop policy if exists "own watermark readable" on public.room_last_seen;
create policy "own watermark readable"
  on public.room_last_seen for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "own watermark writable" on public.room_last_seen;
create policy "own watermark writable"
  on public.room_last_seen for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "own watermark updatable" on public.room_last_seen;
create policy "own watermark updatable"
  on public.room_last_seen for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Feed view: unseen activity in the caller's rooms. Runs over
-- audit_log (member-visible per 0005) joined to the caller's
-- watermark; NULL watermark = everything is unseen. Payload metadata
-- passes through redact_payload (0013).
-- ---------------------------------------------------------------------------
drop view if exists public.v_activity_feed cascade;
create view public.v_activity_feed
with (security_barrier = true)
as
select
  al.id,
  al.room_id,
  al.action_type,
  al.object_type,
  al.object_id,
  al.created_at,
  ls.user_id as for_user_id,
  public.redact_payload(al.room_id, jsonb_build_object(
    'details', al.metadata
  )) as feed_payload
from public.audit_log al
join public.room_last_seen ls
  on ls.room_id = al.room_id
where al.created_at > ls.last_seen_at;

-- Views can't carry RLS; security_invoker makes base-table policies
-- (audit_log member scoping, room_last_seen own-row) apply through the
-- join. The join itself constrains to the caller's watermark rows.
alter view public.v_activity_feed set (security_invoker = true);

grant select on public.v_activity_feed to authenticated;
