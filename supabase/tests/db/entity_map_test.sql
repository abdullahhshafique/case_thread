-- Phase 2 entity-map contract tests (0016): permitted members build the
-- map; observer can read but not write; cross-room edges rejected;
-- the recursive map returns transitive chains.

begin;
select plan(6);

select tests.unimpersonate();
select tests.create_test_user('em-lead@example.com');
select tests.create_test_user('em-analyst@example.com');
select tests.create_test_user('em-observer@example.com');

select tests.impersonate('em-lead@example.com');
insert into tests.fixtures (key, room_id)
select 'em-room', (result).room_id
from public.create_case_room('Entity Map Test Room', 'legal') as result;

select tests.unimpersonate();
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'em-room'),
  'em-analyst@example.com', 'analyst'
);
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'em-room'),
  'em-observer@example.com', 'observer'
);

-- Analyst (edit_case true) creates entities: person, org, evidence.
select tests.impersonate('em-analyst@example.com');
insert into public.entities (room_id, entity_type, name, attributes)
select (select room_id from tests.fixtures where key = 'em-room'),
       'person', 'J. Doe',
       '{"privileged": {"contact": "+1-555-0100"}, "role": "witness"}'::jsonb
returning id::text;
insert into tests.fixtures (key, text_value)
select 'em-person', id::text from public.entities
where room_id = (select room_id from tests.fixtures where key = 'em-room')
  and name = 'J. Doe';

insert into public.entities (room_id, entity_type, name)
select (select room_id from tests.fixtures where key = 'em-room'),
       'org', 'Riverbend Ltd'
returning id::text;
insert into tests.fixtures (key, text_value)
select 'em-org', id::text from public.entities
where room_id = (select room_id from tests.fixtures where key = 'em-room')
  and name = 'Riverbend Ltd';

-- 1. Analyst could create entities (rows landed).
select is(
  count(*),
  2::bigint,
  'permitted member creates entities (edit_case true)'
) from public.entities
where room_id = (select room_id from tests.fixtures where key = 'em-room');

-- 2. Edges: person works-for org (same room — allowed).
insert into public.entity_relationships (room_id, from_entity_id, to_entity_id, relationship_type)
select (select room_id from tests.fixtures where key = 'em-room'),
       (select text_value::uuid from tests.fixtures where key = 'em-person'),
       (select text_value::uuid from tests.fixtures where key = 'em-org'),
       'works_for';

select is(
  count(*),
  1::bigint,
  'same-room edge created'
) from public.entity_relationships
where room_id = (select room_id from tests.fixtures where key = 'em-room');

-- 3. Observer (edit_case false) cannot write entities.
select tests.impersonate('em-observer@example.com');
select throws_ok(
  'insert into public.entities (room_id, entity_type, name) '
    || 'values ((select room_id from tests.fixtures where key = ''em-room''), '
    || '''evidence'', ''sneak.png'')',
  'new row violates row-level security policy for table "entities"',
  'observer entity write rejected (edit_case false)'
);

-- 4. Observer CAN read the map — but the person entity's privileged
--    attributes are redacted (analyst also lacks view_privileged).
select is(
  (map -> 'nodes' -> 0 -> 'attributes' ? 'privileged'),
  false,
  'map nodes redacted for non-privileged readers'
) from public.get_entity_map(
  (select room_id from tests.fixtures where key = 'em-room')
) as map;

-- 5. Map returns both nodes and the edge.
select is(
  (jsonb_array_length(map -> 'nodes') = 2
   and jsonb_array_length(map -> 'edges') = 1),
  true,
  'map returns 2 nodes + 1 edge'
) from public.get_entity_map(
  (select room_id from tests.fixtures where key = 'em-room')
) as map;

-- 6. Transitive: build org -> evidence-edge, expect person->evidence
--    to appear in the transitive list (person -works_for-> org -has-> evidence).
select tests.impersonate('em-analyst@example.com');
insert into public.entities (room_id, entity_type, name)
select (select room_id from tests.fixtures where key = 'em-room'),
       'evidence', 'contract.pdf'
returning id::text;
insert into tests.fixtures (key, text_value)
select 'em-evidence', id::text from public.entities
where room_id = (select room_id from tests.fixtures where key = 'em-room')
  and name = 'contract.pdf';

insert into public.entity_relationships (room_id, from_entity_id, to_entity_id, relationship_type)
select (select room_id from tests.fixtures where key = 'em-room'),
       (select text_value::uuid from tests.fixtures where key = 'em-org'),
       (select text_value::uuid from tests.fixtures where key = 'em-evidence'),
       'has';

with m as (
  select (get_entity_map(
    (select room_id from tests.fixtures where key = 'em-room')
  )) as map
), t_edges as (
  select e.value as edge
  from m, jsonb_array_elements(m.map -> 'transitive') e
)
select is(
  exists (
    select 1 from t_edges
    where edge ->> 'from' = (select text_value from tests.fixtures where key = 'em-person')
      and edge ->> 'to' = (select text_value from tests.fixtures where key = 'em-evidence')
  ),
  true,
  'recursive CTE finds transitive person->evidence connection'
);

select * from finish();
rollback;
