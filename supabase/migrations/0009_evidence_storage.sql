-- CaseThread migration 0009: evidence vault storage (Sprint 4,
-- ExecutionPlan.md §3 — vault: bucket, limits, hashing, versioning).
--
-- Authority model (Rules.md §10): size/mime limits and permission
-- checks are enforced SERVER-SIDE. The client pre-validates for UX;
-- the database refuses regardless.
--   - Bucket: private, 50MB per object (PRD §6.4), mime whitelist.
--   - storage.objects policies: uploads scoped to the caller's room
--     path (rooms/<room_id>/...) AND gated by upload_evidence.
--   - register_evidence(): the ONLY sanctioned evidence_items insert
--     path — audit-logged, sha256-hashed, duplicate names versioned.

-- ---------------------------------------------------------------------------
-- Bucket: private; object paths are room-scoped: rooms/<room_id>/<name>
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'evidence',
  'evidence',
  false,
  52428800, -- 50MB per PRD §6.4
  array[
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/msword',
    'image/png',
    'image/jpeg',
    'image/webp',
    'text/plain',
    'audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/x-wav', 'audio/webm', 'audio/ogg'
  ]
)
on conflict (id) do update
  set file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types,
      public = false;

-- ---------------------------------------------------------------------------
-- storage.objects RLS: CRUD scoped to the room extracted from the path
-- (rooms/<room_id>/...). Upload/download gated by membership + permission;
-- delete is owner-only. The helper below resolves path -> room_id + role.
-- ---------------------------------------------------------------------------

create or replace function public.evidence_room_from_path(object_path text)
returns uuid
language sql
stable
as $$
  -- Path convention: rooms/<room_id>/<filename...>
  select nullif(split_part(split_part(object_path, '/', 2), '/', 1), '')::uuid
$$;

-- Can the caller upload into this room? (permission key: upload_evidence)
drop policy if exists "evidence uploads by permitted members" on storage.objects;
create policy "evidence uploads by permitted members"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'evidence'
    and public.evidence_room_from_path(name) is not null
    and public.user_room_permission(public.evidence_room_from_path(name), 'upload_evidence')
  );

-- Members can read (download) evidence for their rooms.
drop policy if exists "evidence readable by room members" on storage.objects;
create policy "evidence readable by room members"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'evidence'
    and public.user_room_role(auth.uid(), public.evidence_room_from_path(name)) is not null
  );

-- Only the room owner may delete evidence objects.
drop policy if exists "evidence deletion by room owner" on storage.objects;
create policy "evidence deletion by room owner"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'evidence'
    and exists (
      select 1 from public.case_rooms cr
      where cr.id = public.evidence_room_from_path(name)
        and cr.owner_id = auth.uid()
    )
  );

-- No update policy on purpose: stored evidence files are immutable;
-- "new version" = a new object + new evidence_items row.

-- ---------------------------------------------------------------------------
-- register_evidence(): sanctioned evidence_items insert (replaces the
-- generic INSERT policy removed in this migration — clients can no
-- longer insert evidence rows directly). Enforces:
--   - caller is authenticated and an approved member with upload_evidence
--   - storage_path is inside the caller's room (rooms/<room_id>/...)
--   - sha256 hex hash recorded for chain-of-custody (PRD §6.4)
--   - duplicate filenames auto-versioned: contract v2, contract v2-1...
--   - audit entry appended (0007 append_audit)
-- ---------------------------------------------------------------------------
drop policy if exists "evidence upload by permitted members" on public.evidence_items;

create or replace function public.register_evidence(
  target_room uuid,
  original_name text,
  object_path text,
  file_mime text,
  file_size bigint,
  file_sha256 text
)
returns table (evidence_id uuid, version_no int)
language plpgsql
security definer set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  room_ok boolean;
  path_room uuid;
  next_version int;
  new_id uuid;
begin
  if caller_id is null then
    raise exception 'Not authenticated';
  end if;

  if not public.user_room_permission(target_room, 'upload_evidence') then
    raise exception 'Your role cannot upload evidence in this room.';
  end if;

  -- Path must live inside the target room's prefix (no cross-room writes).
  path_room := public.evidence_room_from_path(object_path);
  if path_room is null or path_room <> target_room then
    raise exception 'Evidence path does not match the room.';
  end if;

  if not (file_sha256 ~ '^[0-9a-f]{64}$') then
    raise exception 'Invalid file hash.';
  end if;

  if file_size < 0 or file_size > 52428800 then
    raise exception 'File exceeds the 50MB limit.';
  end if;

  -- Duplicate filename → next version suffix (PRD §6.4 edge case).
  select coalesce(max(version), 0) + 1 into next_version
  from public.evidence_items
  where room_id = target_room
    and lower(filename) = lower(original_name);

  insert into public.evidence_items (
    room_id, uploader_id, filename, storage_path, file_hash,
    mime_type, file_size_bytes, version
  )
  values (
    target_room, caller_id, original_name, object_path, file_sha256,
    file_mime, file_size, next_version
  )
  returning id into new_id;

  perform public.append_audit(
    target_room, caller_id, 'evidence_uploaded', 'evidence_item', new_id::text,
    jsonb_build_object(
      'filename', original_name,
      'version', next_version,
      'sha256', file_sha256,
      'size_bytes', file_size
    )
  );

  return query select new_id, next_version;
end;
$$;
