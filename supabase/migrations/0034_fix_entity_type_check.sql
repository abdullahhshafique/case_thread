-- CaseThread migration 0034: remove the stale entity_type CHECK left by
-- the originally-shipped 0027 (which added the vehicle-inclusive check
-- WITHOUT dropping 0002's original constraint — both coexisted and the
-- old one rejected 'vehicle' rows, breaking the demo seed).
--
-- Dynamic drop: removes every entity_type CHECK that does not include
-- 'vehicle' (no-op on fresh environments where 0027's fixed version
-- already replaced it). Named replacement below guarantees exactly one
-- correct constraint regardless of prior state.

do $$
declare r record;
begin
  for r in
    select conname from pg_constraint
    where conrelid = 'public.entities'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%entity_type%'
      and pg_get_constraintdef(oid) not like '%vehicle%'
  loop
    execute format('alter table public.entities drop constraint %I', r.conname);
  end loop;
end $$;

alter table public.entities
  drop constraint if exists entities_entity_type_check;
alter table public.entities
  add constraint entities_entity_type_check
  check (entity_type in ('person', 'org', 'location', 'evidence', 'vehicle'));
