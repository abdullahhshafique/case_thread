-- 0044 entity-seed import contract tests (Phases.md §13 step 4):
--   1. edit_case holder imports a published template's seed
--      (placeholders substituted, keys resolved to real entity ids).
--   2. Observer (edit_case false) is denied.
--   3. Re-import is idempotent — no duplicate (room, name) rows.
--   4. Unpublished / seedless templates are rejected.
--   5. Missing placeholder values are rejected with a typed error.
--   6. Every import lands exactly one audit entry.

begin;
select plan(8);

select tests.unimpersonate();
select tests.create_test_user('seed-lead@example.com');
select tests.create_test_user('seed-observer@example.com');

-- Published template carrying the seed (authored by the lead so its
-- visibility policy also matches).
select tests.impersonate('seed-lead@example.com');
insert into public.case_type_templates
  (display_name, slug, owner_role, roles, is_published, entity_seed)
values (
  'Robbery Starter', 'robbery-starter-test', 'lead_investigator',
  '[{"slug": "lead_investigator", "display_name": "Lead", "is_lead_tier": true, "permissions": {"edit_case": true}}]'::jsonb,
  true,
  '{
    "entities": [
      {"key": "suspect", "entity_type": "person", "name": "{{suspect_name}}"},
      {"key": "scene", "entity_type": "location", "name": "Dock 7 Warehouse"}
    ],
    "relationships": [
      {"from": "suspect", "to": "scene", "type": "present_at"}
    ]
  }'::jsonb
) returning id::text;
insert into tests.fixtures (key, text_value)
select 'seed-template', id::text from public.case_type_templates
where slug = 'robbery-starter-test';

-- Room the lead owns.
insert into tests.fixtures (key, room_id)
select 'seed-room', (result).room_id
from public.create_case_room('Entity Seed Test Room', 'legal') as result;

select tests.unimpersonate();
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'seed-room'),
  'seed-observer@example.com', 'observer'
);

-- 1. Happy path: lead imports with the placeholder filled.
select tests.impersonate('seed-lead@example.com');
select is(
  public.materialize_entity_seed(
    (select room_id from tests.fixtures where key = 'seed-room'),
    (select text_value::uuid from tests.fixtures where key = 'seed-template'),
    '{"suspect_name": "Marcus Vale"}'::jsonb
  ),
  2,
  'import creates 2 new entities (placeholder substituted + scene)'
);

select is(
  count(*),
  1::bigint,
  'seed relationship resolved from keys and inserted'
) from public.entity_relationships
where room_id = (select room_id from tests.fixtures where key = 'seed-room')
  and relationship_type = 'present_at';

-- 2. Re-import is idempotent: same values → 0 new entities, no dup edges.
select is(
  public.materialize_entity_seed(
    (select room_id from tests.fixtures where key = 'seed-room'),
    (select text_value::uuid from tests.fixtures where key = 'seed-template'),
    '{"suspect_name": "Marcus Vale"}'::jsonb
  ),
  0,
  're-import creates 0 new entities (idempotent by (room, name))'
);

select is(
  count(*),
  1::bigint,
  'no duplicate relationship rows on re-import'
) from public.entity_relationships
where room_id = (select room_id from tests.fixtures where key = 'seed-room')
  and relationship_type = 'present_at';

-- 3. Observer (edit_case false) is denied.
select tests.impersonate('seed-observer@example.com');
select throws_ok(
  $q$select public.materialize_entity_seed(
    (select room_id from tests.fixtures where key = 'seed-room'),
    (select text_value::uuid from tests.fixtures where key = 'seed-template'),
    '{"suspect_name": "Sneaky Sam"}'::jsonb)$q$,
  'Permission denied: cannot import entities into this room',
  'observer import denied (edit_case false)'
);

-- 4. Unpublished/seedless template rejected (use a bogus uuid).
select tests.impersonate('seed-lead@example.com');
select throws_ok(
  $q$select public.materialize_entity_seed(
    (select room_id from tests.fixtures where key = 'seed-room'),
    '00000000-0000-0000-0000-00000000dead'::uuid,
    '{}'::jsonb)$q$,
  'Template not found, unpublished, or has no entity seed',
  'unknown/unpublished template rejected'
);

-- 5. Missing placeholder value rejected.
select throws_ok(
  $q$select public.materialize_entity_seed(
    (select room_id from tests.fixtures where key = 'seed-room'),
    (select text_value::uuid from tests.fixtures where key = 'seed-template'),
    '{}'::jsonb)$q$,
  'Missing value for a template placeholder',
  'unresolved placeholder rejected'
);

-- 6. Exactly one audit entry for the two successful imports.
select is(
  count(*),
  2::bigint,
  'one audit entry per successful import'
) from public.audit_log
where room_id = (select room_id from tests.fixtures where key = 'seed-room')
  and action_type = 'entities_imported';

select * from finish();
rollback;
