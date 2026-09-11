-- CaseThread migration 0007: room service functions (Sprint 3,
-- ExecutionPlan.md §3 — server-side code generation, join flow, rotation).
--
-- Everything the client cannot be trusted with runs in security-definer
-- SQL: access-code generation/hashing/rotation, join validation, and the
-- audit-log appends (Rules.md §10 client trust boundary). The client
-- never sees a code hash and never writes audit rows directly.

-- ---------------------------------------------------------------------------
-- Owner-default roles: which role a room OWNER gets automatically per
-- case type (Lead-tier roles seeded in 0004). Kept as config data so a
-- new case type needs no code change (Architecture.md §2).
-- Additive ALTERs on case_types (Architecture.md §14).
-- ---------------------------------------------------------------------------
alter table public.case_types
  add column if not exists owner_role_id text;

update public.case_types
  set owner_role_id = 'lead_investigator'
  where id = 'legal' and owner_role_id is null;

update public.case_types
  set owner_role_id = 'integrity_officer'
  where id = 'academic' and owner_role_id is null;

alter table public.case_types
  add constraint case_types_owner_role_fkey
  foreign key (owner_role_id) references public.roles (id);

-- ---------------------------------------------------------------------------
-- pgcrypto: digest() for code hashing (self-contained migration — the
-- extension is a no-op if already present).
-- ---------------------------------------------------------------------------
create extension if not exists pgcrypto;

-- Code alphabet: 8 chars, unambiguous (no 0/O/1/I — PRD §6.1), generated
-- server-side with pgcrypto. Codes are stored ONLY as sha256 hashes.
-- ---------------------------------------------------------------------------
create or replace function public.generate_access_code()
returns text
language sql
volatile
as $$
  -- 32-char alphabet of unambiguous uppercase letters+digits.
  select string_agg(
    substr(
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
      1 + floor(random() * 32)::int,
      1
    ),
    ''
  )
  from generate_series(1, 8);
$$;

create or replace function public.hash_access_code(code text)
returns text
language sql
immutable
as $$
  -- Schema-qualified: digest() lives in the extensions schema, which is
  -- not on this function's search_path in Supabase.
  select encode(extensions.digest(upper(code), 'sha256'), 'hex');
$$;

-- ---------------------------------------------------------------------------
-- Audit append helper: the ONLY sanctioned write path into audit_log
-- (security definer; RLS has no insert policy for clients — see 0005).
-- Callers pass the acting user; system events use actor => null.
-- ---------------------------------------------------------------------------
create or replace function public.append_audit(
  target_room uuid,
  actor uuid,
  action text,
  obj_type text,
  obj_id text default '',
  meta jsonb default '{}'::jsonb
)
returns void
language sql
security definer set search_path = public
as $$
  insert into public.audit_log
    (room_id, actor_id, action_type, object_type, object_id, metadata)
  values
    (target_room, actor, action, obj_type, obj_id, meta);
$$;

-- ---------------------------------------------------------------------------
-- Create a room: generates + hashes the code server-side, inserts the
-- room, auto-approves the creator as owner with the case type's
-- owner-default role, and writes the first audit entry. Returns the
-- plaintext code ONCE to the caller (PRD §6.1).
-- ---------------------------------------------------------------------------
create or replace function public.create_case_room(
  room_name text,
  type_id text
)
returns table (room_id uuid, access_code text)
language plpgsql
security definer set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  new_room uuid;
  plain_code text;
  owner_role text;
begin
  if caller_id is null then
    raise exception 'Not authenticated';
  end if;

  select ct.owner_role_id into owner_role
  from public.case_types ct
  where ct.id = type_id and ct.is_active;

  if owner_role is null then
    raise exception 'Unknown or inactive case type: %', type_id;
  end if;

  plain_code := public.generate_access_code();

  insert into public.case_rooms (name, case_type, owner_id, access_code_hash)
  values (room_name, type_id, caller_id, public.hash_access_code(plain_code))
  returning id into new_room;

  -- Owner is auto-approved with the owner-default role.
  insert into public.room_members
    (room_id, user_id, role_id, status, joined_at)
  values
    (new_room, caller_id, owner_role, 'approved', now());

  perform public.append_audit(
    new_room, caller_id, 'room_created', 'case_room', new_room::text,
    jsonb_build_object('name', room_name, 'case_type', type_id)
  );

  return query select new_room, plain_code;
end;
$$;

-- ---------------------------------------------------------------------------
-- Join preview: given a code, tell the caller the room name + case type
-- so they can pick a role — without revealing anything if the code is
-- wrong (PRD §6.2: no information leaked on invalid/expired codes).
-- Rate-limit checked first; attempt recorded for BOTH valid + invalid.
-- ---------------------------------------------------------------------------
create or replace function public.preview_room_by_code(code text)
returns table (room_id uuid, room_name text, case_type_id text)
language plpgsql
security definer set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  found_room public.case_rooms%rowtype;
begin
  if caller_id is null then
    raise exception 'Not authenticated';
  end if;

  if not public.check_join_rate_limit() then
    raise exception 'Too many join attempts. Try again later.';
  end if;

  select * into found_room
  from public.case_rooms
  where access_code_hash = public.hash_access_code(code)
    and case_rooms.status = 'active'
  limit 1;

  perform public.record_join_attempt(found_room.id is not null);

  if found_room.id is null then
    -- Same error shape as any other invalid code (PRD §6.2).
    raise exception 'Invalid or inactive room code.';
  end if;

  return query select found_room.id, found_room.name, found_room.case_type;
end;
$$;

-- ---------------------------------------------------------------------------
-- Join: validates the code + role against the case type's allowed roles,
-- creates the pending request (or routes existing members straight in —
-- PRD §6.2 edge case). Pending approvals on a rotated code stay valid is
-- handled at the member row level: the request is keyed to the room, not
-- the code (PRD §6.1 edge case).
-- ---------------------------------------------------------------------------
create or replace function public.request_room_join(
  code text,
  requested_role text
)
-- OUT param named member_status (not "status") to avoid column-name
-- ambiguity with room_members.status throughout the body (SQLSTATE 42702).
returns table (member_id uuid, member_status text)
language plpgsql
security definer set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  found_room public.case_rooms%rowtype;
  role_ok boolean;
  existing_membership public.room_members%rowtype;
  new_status text; -- avoids OUT-param/column name collision
begin
  if caller_id is null then
    raise exception 'Not authenticated';
  end if;

  if not public.check_join_rate_limit() then
    raise exception 'Too many join attempts. Try again later.';
  end if;

  select * into found_room
  from public.case_rooms
  where access_code_hash = public.hash_access_code(code)
    and case_rooms.status = 'active'
  limit 1;

  perform public.record_join_attempt(found_room.id is not null);

  if found_room.id is null then
    raise exception 'Invalid or inactive room code.';
  end if;

  -- Requested role must belong to this room's case type.
  select exists(
    select 1 from public.roles r
    where r.id = requested_role and r.case_type = found_room.case_type
  ) into role_ok;

  if not role_ok then
    raise exception 'That role is not available for this case type.';
  end if;

  -- Existing member re-join: route straight back in (PRD §6.2 edge case).
  select * into existing_membership
  from public.room_members
  where room_id = found_room.id and user_id = caller_id;

  if existing_membership.id is not null then
    if existing_membership.status = 'approved' then
      return query select existing_membership.id, 'approved';
    elsif existing_membership.status = 'revoked' then
      raise exception 'Your access to this room was revoked by the owner.';
    end if;
    -- Still pending — return the pending state unchanged.
    return query select existing_membership.id, 'pending';
  end if;

  insert into public.room_members (room_id, user_id, role_id, status)
  values (found_room.id, caller_id, requested_role, 'pending')
  -- INTO targets renamed: the OUT parameter "status" would be ambiguous
  -- against the column name here (SQLSTATE 42702).
  returning id, room_members.status into member_id, new_status;

  perform public.append_audit(
    found_room.id, caller_id, 'join_requested', 'room_member', member_id::text,
    jsonb_build_object('requested_role', requested_role)
  );

  return query select member_id, new_status;
end;
$$;

-- ---------------------------------------------------------------------------
-- Approve / deny a pending join (owner-only). Also used for revoking
-- an approved member. Returns the member's new status.
-- ---------------------------------------------------------------------------
create or replace function public.decide_join_request(
  target_room uuid,
  target_member uuid,
  decision text -- 'approved' | 'revoked'
)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  is_owner boolean;
  member_row public.room_members%rowtype;
begin
  if caller_id is null then
    raise exception 'Not authenticated';
  end if;

  if decision not in ('approved', 'revoked') then
    raise exception 'Decision must be approved or revoked.';
  end if;

  select exists(
    select 1 from public.case_rooms cr
    where cr.id = target_room and cr.owner_id = caller_id
  ) into is_owner;

  if not is_owner then
    raise exception 'Only the room owner can manage members.';
  end if;

  select * into member_row
  from public.room_members
  where id = target_member and room_id = target_room;

  if member_row.id is null then
    raise exception 'Member not found in this room.';
  end if;

  update public.room_members
  set status = decision,
      joined_at = case when decision = 'approved' then now() else joined_at end
  where id = target_member
  -- Qualified: avoids column/parameter ambiguity in RETURNING.
  returning room_members.status into decision;

  perform public.append_audit(
    target_room, caller_id,
    case decision when 'approved' then 'join_approved' else 'member_revoked' end,
    'room_member', target_member::text
  );

  return decision;
end;
$$;

-- ---------------------------------------------------------------------------
-- Rotate the access code (owner-only). Old code invalidates for NEW
-- joins immediately; pending requests on the old code remain valid
-- (they're keyed to the room, not the code — PRD §6.1 edge case).
-- Returns the new plaintext code once.
-- ---------------------------------------------------------------------------
create or replace function public.rotate_room_code(target_room uuid)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  is_owner boolean;
  new_code text;
begin
  if caller_id is null then
    raise exception 'Not authenticated';
  end if;

  select exists(
    select 1 from public.case_rooms cr
    where cr.id = target_room and cr.owner_id = caller_id
  ) into is_owner;

  if not is_owner then
    raise exception 'Only the room owner can rotate the code.';
  end if;

  new_code := public.generate_access_code();

  update public.case_rooms
  set access_code_hash = public.hash_access_code(new_code),
      code_rotated_at = now()
  where id = target_room;

  perform public.append_audit(
    target_room, caller_id, 'code_rotated', 'case_room', target_room::text
  );

  return new_code;
end;
$$;

-- ---------------------------------------------------------------------------
-- Co-member visibility: approved members of a room can see each other's
-- display names (member list, @mentions). Additive policy on profiles.
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;

drop policy if exists "profiles visible to room co-members" on public.profiles;
create policy "profiles visible to room co-members"
  on public.profiles for select
  to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1
      from public.room_members mine
      join public.room_members theirs
        on theirs.room_id = mine.room_id
      where mine.user_id = auth.uid()
        and mine.status = 'approved'
        and theirs.status = 'approved'
        and theirs.user_id = profiles.id
    )
  );
