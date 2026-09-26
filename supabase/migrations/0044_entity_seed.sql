-- 0044: Obsidian-style templated entity import (Phases.md §13 step 4).
-- case_type_templates gains an optional `entity_seed` JSONB block:
--   {"entities":       [{"key": "suspect_1", "entity_type": "person",
--                         "name": "{{suspect_1_name}}", "attributes": {...}}],
--    "relationships":  [{"from": "suspect_1", "to": "scene",
--                        "type": "present_at"}]}
-- Relationships reference stable KEYS (like Obsidian wikilinks), not
-- UUIDs — the RPC resolves keys → real ids in one audited transaction.

alter table public.case_type_templates
  add column if not exists entity_seed jsonb;

-- Shape-only CHECK (contents are validated in the RPC — CHECK
-- constraints cannot contain subqueries, Rules.md gotcha).
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'case_type_templates_entity_seed_shape'
  ) then
    alter table public.case_type_templates
      add constraint case_type_templates_entity_seed_shape
      check (entity_seed is null or (
        jsonb_typeof(entity_seed) = 'object'
        and jsonb_typeof(entity_seed -> 'entities') = 'array'
        and jsonb_typeof(entity_seed -> 'relationships') = 'array'
      ));
  end if;
end $$;

-- materialize_entity_seed(): the ONLY import path. edit_case-gated,
-- placeholder-substituted, key-resolved, idempotent per (room, name),
-- and audit-logged as one entry.
create or replace function public.materialize_entity_seed(
  p_room uuid,
  p_template_id uuid,
  p_values jsonb default '{}'::jsonb
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seed jsonb;
  v_entity jsonb;
  v_rel jsonb;
  v_name text;
  v_type text;
  v_key text;
  v_id uuid;
  v_from uuid;
  v_to uuid;
  v_created integer := 0;
  v_rels integer := 0;
  v_key_map jsonb := '{}'::jsonb;
begin
  -- The template must exist, be published, and carry a seed.
  select entity_seed into v_seed
    from public.case_type_templates
    where id = p_template_id
      and is_published;

  if v_seed is null then
    raise exception 'Template not found, unpublished, or has no entity seed';
  end if;

  -- Permission: edit_case in the target room (the DB re-checks RLS
  -- intent here because the function is security definer).
  if not public.user_room_permission(p_room, 'edit_case') then
    raise exception 'Permission denied: cannot import entities into this room';
  end if;

  -- ── Entities: substitute {{placeholders}}, resolve stable keys ──
  for v_entity in select e from jsonb_array_elements(v_seed -> 'entities') as e
  loop
    v_type := v_entity ->> 'entity_type';
    if v_type not in ('person', 'org', 'location', 'evidence', 'vehicle') then
      raise exception 'Invalid entity_type in seed: %', v_type;
    end if;

    v_name := coalesce(v_entity ->> 'name', '');
    -- Replace every {{key}} with p_values ->> key.
    for v_key in select k from jsonb_object_keys(p_values) as k
    loop
      v_name := replace(v_name, '{{' || v_key || '}}',
                        coalesce(p_values ->> v_key, ''));
    end loop;
    v_name := btrim(v_name);

    -- An unresolved placeholder means the caller owes us a value.
    if v_name = '' or v_name like '%{{%' then
      raise exception 'Missing value for a template placeholder';
    end if;

    -- Idempotency: (room, name) already present → reuse its id.
    select id into v_id
      from public.entities
      where room_id = p_room and name = v_name;

    if v_id is null then
      insert into public.entities (room_id, entity_type, name, attributes)
      values (
        p_room,
        v_type,
        v_name,
        coalesce(v_entity -> 'attributes', '{}'::jsonb)
      )
      returning id into v_id;
      v_created := v_created + 1;
    end if;

    v_key_map := jsonb_set(v_key_map,
                           array[v_entity ->> 'key'], to_jsonb(v_id));
  end loop;

  -- ── Relationships: keys → ids; skip self/duplicate edges ──
  for v_rel in select r from jsonb_array_elements(coalesce(v_seed -> 'relationships', '[]'::jsonb)) as r
  loop
    v_from := (v_key_map ->> (v_rel ->> 'from'))::uuid;
    v_to := (v_key_map ->> (v_rel ->> 'to'))::uuid;

    if v_from is null or v_to is null or v_from = v_to then
      continue; -- dangling key or self-loop: skip, never fail the import
    end if;

    if not exists (
      select 1 from public.entity_relationships
      where room_id = p_room
        and from_entity_id = v_from
        and to_entity_id = v_to
        and relationship_type = coalesce(v_rel ->> 'type', 'related_to')
    ) then
      insert into public.entity_relationships
        (room_id, from_entity_id, to_entity_id, relationship_type)
      values
        (p_room, v_from, v_to, coalesce(v_rel ->> 'type', 'related_to'));
      v_rels := v_rels + 1;
    end if;
  end loop;

  -- One audit entry for the whole import (client never writes audit).
  perform public.append_audit(
    p_room,
    auth.uid(),
    'entities_imported',
    'template',
    p_template_id::text,
    jsonb_build_object('entities_created', v_created,
                       'relationships_added', v_rels)
  );

  return v_created;
end $$;

-- Revoke direct writes from anon; the RPC is the only door.
revoke all on function public.materialize_entity_seed(uuid, uuid, jsonb) from anon;
