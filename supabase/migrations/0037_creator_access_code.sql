-- CaseThread migration 0037: creator-chosen access codes.
--
-- The room creator may now SET the join code instead of receiving a
-- generated one (user request 2026-09-20). The server still owns
-- hashing — the plaintext code is returned ONCE to the creator
-- (PRD §6.1) and only the sha256 hash is stored. Validation holds
-- creator codes to the same unambiguous alphabet
-- generate_access_code() uses, and a uniqueness guard prevents two
-- rooms from claiming the same code.

create or replace function public.create_case_room(
  room_name text,
  type_id text,
  p_access_code text default null
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

  if p_access_code is null or btrim(p_access_code) = '' then
    plain_code := public.generate_access_code();
  else
    -- Creator-chosen code: normalize (trim + upper) and hold it to the
    -- same unambiguous alphabet as generate_access_code().
    plain_code := upper(regexp_replace(btrim(p_access_code), '\s', '', 'g'));
    if plain_code !~ '^[A-HJ-NP-Z2-9]{6,16}$' then
      raise exception
        'Access code must be 6-16 characters: A-Z (no I or O) and digits 2-9';
    end if;
  end if;

  if exists (
    select 1 from public.case_rooms
    where access_code_hash = public.hash_access_code(plain_code)
  ) then
    raise exception 'That access code is already in use — pick another.';
  end if;

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

revoke execute on function public.create_case_room(text, text)
from public, anon;
revoke execute on function public.create_case_room(text, text, text)
from public, anon;
grant execute on function public.create_case_room(text, text, text)
to authenticated;
