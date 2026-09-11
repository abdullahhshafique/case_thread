-- CaseThread migration 0005: Row Level Security — the real permission
-- boundary (Architecture.md §9: RLS is the enforcement point, never the UI).
--
-- Central helper: user_room_role(user, room) resolves the caller's
-- APPROVED role in a room, or null. Every member-scoped policy uses it so
-- the join logic exists in exactly one place (Rules.md: boring where it
-- counts). Revoked/pending members get null → treated as non-members.

-- Enable RLS on every table first: default-deny until a policy allows.
alter table public.case_rooms          enable row level security;
alter table public.case_types          enable row level security;
alter table public.roles               enable row level security;
alter table public.room_members        enable row level security;
alter table public.evidence_items      enable row level security;
alter table public.timeline_events     enable row level security;
alter table public.audit_log           enable row level security;
alter table public.discussion_messages enable row level security;
alter table public.tasks               enable row level security;
alter table public.ai_suggestions      enable row level security;
alter table public.entities            enable row level security;
alter table public.entity_relationships enable row level security;

create or replace function public.user_room_role(target_user uuid, target_room uuid)
returns text
language sql
stable
security definer set search_path = public
as $$
  select rm.role_id
  from public.room_members rm
  where rm.user_id = target_user
    and rm.room_id = target_room
    and rm.status = 'approved'
  limit 1;
$$;

-- Permission-key check: does the caller's role in this room hold a
-- permission? (permissions JSONB grid from migration 0004.)
create or replace function public.user_room_permission(
  target_room uuid,
  permission_key text
)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select coalesce(
    (r.permissions ->> permission_key)::boolean,
    false
  )
  from public.roles r
  where r.id = public.user_room_role(auth.uid(), target_room);
$$;

-- ---------------------------------------------------------------------------
-- case_types + roles: readable by any authenticated user (needed to pick
-- a case type at room creation and a role at join — PRD §6.1–6.2).
-- Not writable by anyone through PostgREST; changes ship as migrations.
-- ---------------------------------------------------------------------------
drop policy if exists "case_types readable by authenticated" on public.case_types;
create policy "case_types readable by authenticated"
  on public.case_types for select
  to authenticated
  using (is_active);

drop policy if exists "roles readable by authenticated" on public.roles;
create policy "roles readable by authenticated"
  on public.roles for select
  to authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- case_rooms: members see their rooms; anyone authenticated can CREATE
-- (becoming owner). Owner-only UPDATE (rotate code, archive). No DELETE
-- through PostgREST (retention policy is an open question, PRD §10).
-- ---------------------------------------------------------------------------
drop policy if exists "rooms visible to members" on public.case_rooms;
create policy "rooms visible to members"
  on public.case_rooms for select
  to authenticated
  using (public.user_room_role(auth.uid(), id) is not null);

drop policy if exists "rooms creatable by anyone authenticated" on public.case_rooms;
create policy "rooms creatable by anyone authenticated"
  on public.case_rooms for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "rooms updatable by owner" on public.case_rooms;
create policy "rooms updatable by owner"
  on public.case_rooms for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- ---------------------------------------------------------------------------
-- room_members: visible to approved members of the same room (the member
-- list is part of the room). INSERT = join request (Sprint 3 flow will
-- call this after code validation): any authenticated user can insert
-- their own PENDING row. Approval (status change) is owner-only — and
-- only the owner can set status to 'approved'/'revoked' or change roles.
-- ---------------------------------------------------------------------------
drop policy if exists "members visible to room members" on public.room_members;
create policy "members visible to room members"
  on public.room_members for select
  to authenticated
  using (
    public.user_room_role(auth.uid(), room_id) is not null
    or user_id = auth.uid() -- see own pending request
  );

drop policy if exists "join requests insertable by self" on public.room_members;
create policy "join requests insertable by self"
  on public.room_members for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and status = 'pending'
    and public.user_room_role(auth.uid(), room_id) is null -- not already member
  );

drop policy if exists "member management by owner" on public.room_members;
create policy "member management by owner"
  on public.room_members for update
  to authenticated
  using (exists (
    select 1 from public.case_rooms cr
    where cr.id = room_id and cr.owner_id = auth.uid()
  ));

-- ---------------------------------------------------------------------------
-- Room-scoped content tables. Pattern for all: SELECT for approved members
-- (some permission-gated), INSERT gated by the relevant permission key,
-- UPDATE restricted to permitted roles (or owner), DELETE minimal.
-- ---------------------------------------------------------------------------

-- evidence_items: view for members, upload gated by upload_evidence.
drop policy if exists "evidence visible to room members" on public.evidence_items;
create policy "evidence visible to room members"
  on public.evidence_items for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

drop policy if exists "evidence upload by permitted members" on public.evidence_items;
create policy "evidence upload by permitted members"
  on public.evidence_items for insert
  to authenticated
  with check (
    uploader_id = auth.uid()
    and public.user_room_permission(room_id, 'upload_evidence')
  );

drop policy if exists "evidence delete by owner only" on public.evidence_items;
create policy "evidence delete by owner only"
  on public.evidence_items for delete
  to authenticated
  using (exists (
    select 1 from public.case_rooms cr
    where cr.id = room_id and cr.owner_id = auth.uid()
  ));

-- timeline_events: manual events editable by permitted roles; edits are
-- themselves logged by app logic (PRD §6.5) — the policy keeps
-- room-scoping while permission keys gate writes.
drop policy if exists "timeline visible to room members" on public.timeline_events;
create policy "timeline visible to room members"
  on public.timeline_events for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

drop policy if exists "timeline manual events by permitted members" on public.timeline_events;
create policy "timeline manual events by permitted members"
  on public.timeline_events for insert
  to authenticated
  with check (
    actor_id = auth.uid()
    and event_type = 'manual'
    and public.user_room_permission(room_id, 'edit_case')
  );

drop policy if exists "timeline edits by permitted members" on public.timeline_events;
create policy "timeline edits by permitted members"
  on public.timeline_events for update
  to authenticated
  using (
    actor_id = auth.uid()
    and event_type = 'manual'
    and public.user_room_permission(room_id, 'edit_case')
  );

-- audit_log: SELECT for members; INSERT happens via security-definer
-- trigger functions (Sprint 3/4), NOT direct client inserts — so no
-- insert policy exists here. UPDATE/DELETE impossible (migration 0003).
drop policy if exists "audit log visible to room members" on public.audit_log;
create policy "audit log visible to room members"
  on public.audit_log for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

-- discussion_messages: comment permission gates posting/editing own.
drop policy if exists "discussion visible to room members" on public.discussion_messages;
create policy "discussion visible to room members"
  on public.discussion_messages for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

drop policy if exists "discussion posting by permitted members" on public.discussion_messages;
create policy "discussion posting by permitted members"
  on public.discussion_messages for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and public.user_room_permission(room_id, 'comment')
  );

drop policy if exists "discussion edit own by permitted members" on public.discussion_messages;
create policy "discussion edit own by permitted members"
  on public.discussion_messages for update
  to authenticated
  using (
    author_id = auth.uid()
    and public.user_room_permission(room_id, 'comment')
  );

-- tasks: view for members; create/assign gated by edit_case; assignee may
-- update status only (app layer narrows the UPDATE payload).
drop policy if exists "tasks visible to room members" on public.tasks;
create policy "tasks visible to room members"
  on public.tasks for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

drop policy if exists "tasks created by permitted members" on public.tasks;
create policy "tasks created by permitted members"
  on public.tasks for insert
  to authenticated
  with check (
    created_by = auth.uid()
    and public.user_room_permission(room_id, 'edit_case')
  );

drop policy if exists "tasks updatable by permitted members or assignee" on public.tasks;
create policy "tasks updatable by permitted members or assignee"
  on public.tasks for update
  to authenticated
  using (
    public.user_room_permission(room_id, 'edit_case')
    or assignee_id = auth.uid()
  );

-- ai_suggestions: Phase 3 feature — deny-all for now except member reads
-- (harness tests assert inserts fail; agents will insert via Edge
-- Function with service role, never the client, per Architecture.md §4).
drop policy if exists "ai suggestions visible to room members" on public.ai_suggestions;
create policy "ai suggestions visible to room members"
  on public.ai_suggestions for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

-- entities / entity_relationships: Phase 2 — member reads only, no writes.
drop policy if exists "entities visible to room members" on public.entities;
create policy "entities visible to room members"
  on public.entities for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

drop policy if exists "entity relationships visible to room members" on public.entity_relationships;
create policy "entity relationships visible to room members"
  on public.entity_relationships for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);
