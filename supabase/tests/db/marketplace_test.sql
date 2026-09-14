-- Phase 4 contract tests (0021): template marketplace.
-- Allow AND deny per Rules.md §7: draft privacy, author-only writes,
-- publish materialization + every validation path, room-from-template.

begin;
select plan(16);

select tests.unimpersonate();
select tests.create_test_user('tpl-author@example.com');
select tests.create_test_user('tpl-other@example.com');

-- 1. Author creates a draft (client path — 0021 RLS).
select tests.impersonate('tpl-author@example.com');
insert into public.case_type_templates (
  id, author, display_name, description, slug, owner_role, roles
) values (
  'd3000000-0000-4000-8000-000000000001',
  (select user_id from tests.fixtures where key = 'tpl-author@example.com'),
  'Journalism Room', 'Editorial investigations with a custom role set.',
  'journalism', 'editor',
  '[
    {"slug": "editor", "display_name": "Editor", "is_lead_tier": true,
     "permissions": {"view_case": true, "edit_case": true, "upload_evidence": true,
       "comment": true, "approve_ai_findings": true, "manage_members": true,
       "export_reports": true, "view_privileged": true}},
    {"slug": "contributor", "display_name": "Contributor", "is_lead_tier": false,
     "permissions": {"view_case": true, "edit_case": true, "upload_evidence": true,
       "comment": true, "approve_ai_findings": false, "manage_members": false,
       "export_reports": false, "view_privileged": false}}
  ]'::jsonb
);
select is(
  (select count(*) from public.case_type_templates
   where slug = 'journalism' and not is_published),
  1::bigint,
  'author can create a draft template'
);

-- 2. Other users CANNOT see someone else's unpublished draft.
select tests.impersonate('tpl-other@example.com');
select is(
  (select count(*) from public.case_type_templates where slug = 'journalism'),
  0::bigint,
  'drafts are private to the author'
);

-- 3. Other users CANNOT edit the draft (silent 0-row no-op).
update public.case_type_templates
set display_name = 'Hacked'
where slug = 'journalism';
select tests.unimpersonate();
select is(
  (select display_name from public.case_type_templates where slug = 'journalism'),
  'Journalism Room',
  'non-author UPDATE is a no-op'
);

-- 4. Non-author CANNOT publish (RPC enforces authorship).
select tests.impersonate('tpl-other@example.com');
select throws_ok(
  'select public.publish_template(''d3000000-0000-4000-8000-000000000001'')',
  'Template not found (or not yours).',
  'non-author publish rejected'
);

-- 5. Author publishes → case_types + roles materialize.
select tests.impersonate('tpl-author@example.com');
select is(
  public.publish_template('d3000000-0000-4000-8000-000000000001')::text,
  'journalism',
  'publish returns the new case type id'
);

-- 6. Config rows materialized: case type + 2 roles, correct shapes.
select is(
  (select row(id, owner_role_id)::text from public.case_types where id = 'journalism'),
  '(journalism,journalism_editor)',
  'case_types row created with prefixed owner role'
);
select is(
  (select count(*) from public.roles
   where case_type = 'journalism'
     and id in ('journalism_editor', 'journalism_contributor')),
  2::bigint,
  'roles materialized with slug-prefixed ids'
);
select is(
  (select permissions ->> 'approve_ai_findings' from public.roles
   where id = 'journalism_editor'),
  'true',
  'editor grid carried through (lead-tier permission intact)'
);

-- 7. Template flips to published + published_case_type stamped.
select is(
  (select is_published and published_case_type = 'journalism'
   from public.case_type_templates where slug = 'journalism'),
  true,
  'template marked published with case type reference'
);

-- 8. NOW other users see it (marketplace listing contract).
select tests.impersonate('tpl-other@example.com');
select is(
  (select count(*) from public.case_type_templates where slug = 'journalism'),
  1::bigint,
  'published templates visible to everyone'
);

-- 9. A room created from the published template works end-to-end
--    (create_case_room unchanged — config-not-rebuild proof).
select tests.impersonate('tpl-other@example.com');
insert into tests.fixtures (key, room_id)
select 'tpl-room', (result).room_id
from public.create_case_room('Room From Template', 'journalism') as result;
select is(
  (select case_type from public.case_rooms
   where id = (select room_id from tests.fixtures where key = 'tpl-room')),
  'journalism',
  'room creation works from a published template'
);

-- 10. Owner got the template's owner role (member row).
select is(
  (select role_id from public.room_members
   where room_id = (select room_id from tests.fixtures where key = 'tpl-room')
     and user_id = (select user_id from tests.fixtures where key = 'tpl-other@example.com')),
  'journalism_editor',
  'room owner assigned the template owner role'
);

-- 11. Double publish rejected.
select tests.impersonate('tpl-author@example.com');
select throws_ok(
  'select public.publish_template(''d3000000-0000-4000-8000-000000000001'')',
  'Template already published as case type journalism.',
  'double publish rejected'
);

-- 12. slug collision with an existing case type rejected.
select tests.unimpersonate();
insert into public.case_type_templates (
  author, display_name, slug, owner_role, roles
) values (
  (select user_id from tests.fixtures where key = 'tpl-author@example.com'),
  'Fake Legal', 'legal', 'lead_investigator',
  '[{"slug": "x", "display_name": "X", "is_lead_tier": true,
     "permissions": {"view_case": true}}]'::jsonb
);
select tests.impersonate('tpl-author@example.com');
select throws_ok(
  'select public.publish_template((select id from public.case_type_templates where slug = ''legal'' and author = (select user_id from tests.fixtures where key = ''tpl-author@example.com''))::uuid)',
  'A case type with this id already exists: legal',
  'case-type id collision rejected'
);

-- 13. view_case=false role rejected (RLS visibility invariant).
select tests.unimpersonate();
insert into public.case_type_templates (
  author, display_name, slug, owner_role, roles
) values (
  (select user_id from tests.fixtures where key = 'tpl-author@example.com'),
  'Blind Roles', 'blindroles', 'lead',
  '[{"slug": "lead", "display_name": "Lead", "is_lead_tier": true,
     "permissions": {"view_case": false}}]'::jsonb
);
select tests.impersonate('tpl-author@example.com');
select throws_ok(
  'select public.publish_template((select id from public.case_type_templates where slug = ''blindroles''))::uuid',
  'Role lead must have view_case = true (members must see the room).',
  'view_case=false grid rejected'
);

-- 14. Unknown permission key rejected (typo protection — a silently
--     unknown key would make RLS read a missing permission as false).
select tests.unimpersonate();
insert into public.case_type_templates (
  author, display_name, slug, owner_role, roles
) values (
  (select user_id from tests.fixtures where key = 'tpl-author@example.com'),
  'Typo Grid', 'typogrid', 'lead',
  '[{"slug": "lead", "display_name": "Lead", "is_lead_tier": true,
     "permissions": {"view_case": true, "veiw_case": true}}]'::jsonb
);
select tests.impersonate('tpl-author@example.com');
select throws_ok(
  'select public.publish_template((select id from public.case_type_templates where slug = ''typogrid''))::uuid',
  'Unknown permission key "veiw_case" on role lead.',
  'unknown permission key rejected'
);

select * from finish();
rollback;
