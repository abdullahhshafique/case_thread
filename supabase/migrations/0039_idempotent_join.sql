-- CaseThread migration 0039: idempotent join request.
--
-- Double-submitting the join form (or two racing requests) could both
-- pass the existing-member check and insert, hitting
-- room_members_room_id_user_id_key with 23505 (caught in the field
-- 2026-09-20). The re-join paths above this insert already return the
-- existing row; the ON CONFLICT here covers only the insert race.

-- (body unchanged from 0007 apart from the conflict clause; recreated
-- so the statement carries it)

create or replace function public.request_room_join(
  code text,
  requested_role text
)
returns table (member_id uuid, member_status text)
language plpgsql
security definer set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  found_room public.case_rooms%rowtype;
  role_ok boolean;
  existing_membership public.room_members%rowtype;
  new_status text;
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
    return query select existing_membership.id, 'pending';
  end if;

  insert into public.room_members (room_id, user_id, role_id, status)
  values (found_room.id, caller_id, requested_role, 'pending')
  on conflict (room_id, user_id) do update
    set role_id = excluded.role_id
  returning id, room_members.status into member_id, new_status;

  perform public.append_audit(
    found_room.id, caller_id, 'join_requested', 'room_member', member_id::text,
    jsonb_build_object('requested_role', requested_role)
  );

  return query select member_id, new_status;
end;
$$;
