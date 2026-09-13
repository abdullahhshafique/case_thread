-- CaseThread migration 0016: entity-relationship map v1 (Phase 2,
-- Phases.md §3; Architecture.md §5: recursive CTEs first — evaluate a
-- graph extension only with real volume).
--
-- v1 scope: members with edit_case may build the map (create entities
-- + typed relationships); everyone in the room reads it. The map RPC
-- returns nodes + edges in one round-trip; transitive connections use
-- a recursive CTE (the "how the pieces connect" view for e.g.
-- person -> org -> evidence chains).

-- Writes for permitted members (edit_case controls map authorship).
drop policy if exists "entities writable by permitted members" on public.entities;
create policy "entities writable by permitted members"
  on public.entities for insert
  to authenticated
  with check (public.user_room_permission(room_id, 'edit_case'));

drop policy if exists "entity relationships writable by permitted members" on public.entity_relationships;
create policy "entity relationships writable by permitted members"
  on public.entity_relationships for insert
  to authenticated
  with check (
    public.user_room_permission(room_id, 'edit_case')
    -- Both endpoints must exist in the SAME room (no cross-room edges).
    and exists (
      select 1 from public.entities e1, public.entities e2
      where e1.id = entity_relationships.from_entity_id
        and e2.id = entity_relationships.to_entity_id
        and e1.room_id = entity_relationships.room_id
        and e2.room_id = entity_relationships.room_id
    )
  );

-- ---------------------------------------------------------------------------
-- Map reader: nodes + edges for a room, plus transitive links
-- (person -> org -> evidence) via recursive CTE — Architecture.md's
-- chosen approach for v1 volume.
-- ---------------------------------------------------------------------------
create or replace function public.get_entity_map(target_room uuid)
returns jsonb
language sql
stable
security definer set search_path = public
as $$
  select jsonb_build_object(
    'nodes', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', e.id,
        'type', e.entity_type,
        'name', e.name,
        'attributes', public.redact_payload(target_room, e.attributes)
      ) order by e.entity_type, e.name), '[]'::jsonb)
      from public.entities e
      where e.room_id = target_room
    ),
    'edges', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', er.id,
        'from', er.from_entity_id,
        'to', er.to_entity_id,
        'type', er.relationship_type
      )), '[]'::jsonb)
      from public.entity_relationships er
      where er.room_id = target_room
    ),
    'transitive', (
      -- Recursive CTE: entity -> entity via any edge chain (max depth 4
      -- keeps cycles bounded; case graphs are small in practice).
      with recursive chain(from_id, to_id, depth, path) as (
        select from_entity_id, to_entity_id, 1,
               array[from_entity_id, to_entity_id]
        from public.entity_relationships
        where room_id = target_room
        union
        select c.from_id, er.to_entity_id, c.depth + 1,
               c.path || er.to_entity_id
        from chain c
        join public.entity_relationships er
          on er.from_entity_id = c.to_id
         and er.room_id = target_room
        where c.depth < 4
          and not (er.to_entity_id = any (c.path))  -- cycle guard
      )
      select coalesce(jsonb_agg(distinct
        jsonb_build_object('from', from_id, 'to', to_id)
      )), '[]'::jsonb)
      from (
        select distinct from_id, to_id
        from chain
        where depth > 1
      ) t
    )
  );
$$;
