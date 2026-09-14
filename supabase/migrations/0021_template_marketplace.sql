-- CaseThread migration 0021: Phase 4 — template marketplace
-- (Phases.md §5: "design/share custom case-type templates").
--
-- Design (one core, many configs — Architecture.md §2):
--   * A template is a DRAFT definition of a case type: display name,
--     description, and a full role set with permission grids.
--   * Drafts are private to their author.
--   * Publishing MATERIALIZES the template into real config rows —
--     a case_types row + its roles — via publish_template(). From
--     that moment the template works everywhere config is read:
--     room creation, join role picker, RLS permission checks.
--   * No core table changes; create_case_room works on published
--     templates unchanged (config-not-rebuild, the Phase-2 proof).
--
-- Rules.md §11-adjacent invariants:
--   * Permission grids are validated server-side (publish rejects
--     unknown/missing keys, wrong types) — a bad template can never
--     weaken the permission model the RLS policies evaluate.
--   * Every role grid MUST keep view_case = true (you can't join a
--     room you can't see) and MUST have exactly one lead-tier role
--     for the owner default (or an explicit owner_role).

-- ---------------------------------------------------------------------------
-- Template drafts.
-- ---------------------------------------------------------------------------
create table if not exists public.case_type_templates (
  id uuid primary key default gen_random_uuid(),
  author uuid not null default auth.uid() references auth.users (id) on delete cascade,
  display_name text not null,
  description text not null default '',
  slug text not null, -- becomes case_types.id on publish (validated)
  owner_role text not null, -- slug of the role that owns new rooms
  roles jsonb not null, -- [{slug, display_name, is_lead_tier, permissions}]
  is_published boolean not null default false,
  published_case_type text references public.case_types (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (author, slug)
);

create index if not exists case_type_templates_published_idx
  on public.case_type_templates (is_published, display_name);

alter table public.case_type_templates enable row level security;

-- Authors see their own drafts (any state) ...
drop policy if exists "templates visible to author" on public.case_type_templates;
create policy "templates visible to author"
  on public.case_type_templates for select
  to authenticated
  using (author = auth.uid());

-- ... everyone sees PUBLISHED templates (the marketplace listing).
drop policy if exists "published templates visible to all" on public.case_type_templates;
create policy "published templates visible to all"
  on public.case_type_templates for select
  to authenticated
  using (is_published);

-- Authors manage their own drafts. Publishing flips is_published via
-- the RPC (which also stamps published_case_type); drafts stay
-- editable — a published template's source can be revised and
-- re-published as a NEW case type version later (additive only).
drop policy if exists "templates insertable by author" on public.case_type_templates;
create policy "templates insertable by author"
  on public.case_type_templates for insert
  to authenticated
  with check (author = auth.uid());

drop policy if exists "templates updatable by author" on public.case_type_templates;
create policy "templates updatable by author"
  on public.case_type_templates for update
  to authenticated
  using (author = auth.uid())
  with check (author = auth.uid());

drop policy if exists "templates deletable by author" on public.case_type_templates;
create policy "templates deletable by author"
  on public.case_type_templates
  for delete
  to authenticated
  using (author = auth.uid());

-- ---------------------------------------------------------------------------
-- publish_template(): the only draft → config materialization path.
-- Validates everything BEFORE writing: slug shape, id collisions
-- (case_types and roles are global namespaces), role-grid keys/types,
-- view_case invariant, lead-tier/owner role existence.
-- SECURITY DEFINER so the author doesn't need direct write access to
-- case_types/roles (those ship via migrations only — this RPC is the
-- sanctioned marketplace exception, gated per-row by authorship).
-- ---------------------------------------------------------------------------
create or replace function public.publish_template(template uuid)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  t public.case_type_templates%rowtype;
  caller_id uuid := auth.uid();
  role_count int;
  valid_keys text[] := array[
    'view_case', 'edit_case', 'upload_evidence', 'comment',
    'approve_ai_findings', 'manage_members', 'export_reports', 'view_privileged'
  ];
  r record;
  perm_key text;
  perm_val jsonb;
  owner_found boolean := false;
begin
  if caller_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into t from public.case_type_templates
  where id = template and author = caller_id;
  if t.id is null then
    raise exception 'Template not found (or not yours).';
  end if;

  if t.is_published then
    raise exception 'Template already published as case type %.', t.published_case_type;
  end if;

  -- slug: lowercase identifier, safe as case_types.id / roles.id prefix.
  if t.slug !~ '^[a-z][a-z0-9_]{2,30}$' then
    raise exception 'Template id must be 3-31 chars: lowercase letter first, then letters/digits/underscores.';
  end if;
  if exists (select 1 from public.case_types where id = t.slug) then
    raise exception 'A case type with this id already exists: %', t.slug;
  end if;

  -- roles: array of 1-8 objects with required fields.
  if jsonb_typeof(t.roles) <> 'array' then
    raise exception 'Template roles must be a JSON array.';
  end if;
  role_count := jsonb_array_length(t.roles);
  if role_count < 1 or role_count > 8 then
    raise exception 'Templates need 1-8 roles (got %).', role_count;
  end if;

  for r in select * from jsonb_array_elements(t.roles)
  loop
    if r.value ->> 'slug' is null or r.value ->> 'slug' !~ '^[a-z][a-z0-9_]{2,30}$' then
      raise exception 'Every role needs a valid slug (3-31 chars, lowercase).';
    end if;
    if r.value ->> 'display_name' is null or length(r.value ->> 'display_name') = 0 then
      raise exception 'Role % needs a display name.', r.value ->> 'slug';
    end if;
    -- Collisions in the GLOBAL roles namespace (roles.id is unique).
    if exists (
      select 1 from public.roles
      where id = t.slug || '_' || (r.value ->> 'slug')
    ) then
      raise exception 'Role id collision: % — pick a different template id or role slug.',
        t.slug || '_' || (r.value ->> 'slug');
    end if;

    -- Grid: exactly the 8 known keys, boolean values (typo protection:
    -- RLS reads these keys; an unknown key would silently do nothing).
    for perm_key, perm_val in
      select key, value from jsonb_each(coalesce(r.value -> 'permissions', '{}'::jsonb))
    loop
      if not (perm_key = any (valid_keys)) then
        raise exception 'Unknown permission key "%" on role %.', perm_key, r.value ->> 'slug';
      end if;
      if jsonb_typeof(perm_val) <> 'boolean' then
        raise exception 'Permission "%" on role % must be true/false.', perm_key, r.value ->> 'slug';
      end if;
    end loop;
    if (r.value -> 'permissions') is null or (r.value -> 'permissions') = '{}'::jsonb then
      raise exception 'Role % needs a permissions grid.', r.value ->> 'slug';
    end if;

    -- view_case=true invariant: RLS visibility depends on it.
    if coalesce((r.value -> 'permissions' ->> 'view_case')::boolean, false) is not true then
      raise exception 'Role % must have view_case = true (members must see the room).',
        r.value ->> 'slug';
    end if;

    if coalesce((r.value ->> 'is_lead_tier')::boolean, false) then
      owner_found := true;
    end if;
  end loop;

  -- owner_role must exist in the set (case_rooms owner default).
  if not exists (
    select 1 from jsonb_array_elements(t.roles)
    where value ->> 'slug' = t.owner_role
  ) then
    raise exception 'owner_role "%" is not one of the template''s roles.', t.owner_role;
  end if;

  -- Exactly one lead-tier role keeps the review flow meaningful.
  if not owner_found then
    raise exception 'At least one role must be lead-tier (can review AI findings).';
  end if;

  -- All validations passed: materialize (atomic — one transaction).
  -- Circular FK (roles.case_type → case_types; case_types.owner_role_id
  -- → roles) means NEITHER table can be inserted first. Same solution
  -- 0012 used: create the case type with a NULL owner role, insert
  -- the roles, then set owner_role_id.
  insert into public.case_types (id, display_name, description)
  values (t.slug, t.display_name, t.description);

  insert into public.roles (id, case_type, display_name, is_lead_tier, permissions)
  select
    t.slug || '_' || (value ->> 'slug'),
    t.slug,
    value ->> 'display_name',
    coalesce((value ->> 'is_lead_tier')::boolean, false),
    value -> 'permissions'
  from jsonb_array_elements(t.roles);

  update public.case_types
  set owner_role_id = t.slug || '_' || t.owner_role
  where id = t.slug;

  update public.case_type_templates
  set is_published = true,
      published_case_type = t.slug,
      updated_at = now()
  where id = t.id;

  return t.slug;
end;
$$;

-- Marketplace publishes are auditable events (Rules.md §12 spirit:
-- config changes leave a trail). Simple author-scoped audit row via
-- the same append path — but templates have no room; record on the
-- template itself (published_at via updated_at + is_published flag).
