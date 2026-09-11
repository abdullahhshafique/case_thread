-- Shared pgTAP helpers for CaseThread RLS contract tests.
--
-- supabase test db runs EVERY .sql file in this directory as its own
-- psql session (alphabetically — the underscore keeps this first).
-- This file is therefore NOT wrapped in begin/rollback: its schema,
-- fixtures table, and helper functions COMMIT here so later test
-- files can use them. It declares a 1-test plan (helpers installed)
-- so pg_prove counts it as passing.
--
-- Test files after this one use the standard pgTAP pattern:
--   begin; select plan(n); ... select * from finish(); rollback;
-- so their fixtures roll back and never leak between files.
--
-- No psql client metacommands (\gset etc.) — values pass between
-- statements via the tests.fixtures table instead.

begin;
select plan(1);

create schema if not exists tests;

-- pgTAP assertion helpers execute with SET ROLE from the caller's
-- context; grant the runner everything on the tests schema.
grant usage, create on schema tests to public;
grant all on all tables in schema tests to public;
grant all on all functions in schema tests to public;

create table if not exists tests.fixtures (
  key text primary key,
  user_id uuid,
  room_id uuid,
  member_id uuid,
  text_value text
);

create or replace function tests.create_test_user(user_email text)
returns uuid
language plpgsql
as $$
declare
  new_id uuid := gen_random_uuid();
begin
  insert into auth.users (
    instance_id, id, aud, role, email,
    encrypted_password, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', new_id, 'authenticated',
    'authenticated', user_email,
    -- Schema-qualified: crypt/gen_salt live in the extensions schema.
    extensions.crypt(user_email, extensions.gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('display_name', split_part(user_email, '@', 1))
  );
  insert into tests.fixtures (key, user_id) values (user_email, new_id)
  on conflict (key) do update set user_id = excluded.user_id;
  return new_id;
end;
$$;

-- Impersonate a user for subsequent statements in this session:
-- sets the JWT claim PostgREST would send, so auth.uid() resolves.
create or replace function tests.impersonate(user_email text)
returns void
language plpgsql
as $$
declare
  target uuid;
begin
  select user_id into target from tests.fixtures where key = user_email;
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', target,
      'role', 'authenticated',
      'aud', 'authenticated'
    )::text,
    true -- transaction-local: test files wrap everything in
         -- begin; ... rollback; so this resets with the rollback.
  );
  perform set_config('role', 'authenticated', true);
end;
$$;

-- Reset back to superuser context (for fixture setup between
-- impersonations).
create or replace function tests.unimpersonate()
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'postgres', true);
end;
$$;

-- Create an approved member fixture directly (bypasses RLS since this
-- helper runs as postgres in tests).
create or replace function tests.add_approved_member(
  target_room uuid, member_email text, member_role text
)
returns uuid
language plpgsql
as $$
declare
  row_id uuid;
  member uuid;
begin
  select user_id into member from tests.fixtures where key = member_email;
  insert into public.room_members (room_id, user_id, role_id, status, joined_at)
  values (target_room, member, member_role, 'approved', now())
  returning id into row_id;
  return row_id;
end;
$$;

-- The one assertion: every helper the test files depend on exists.
select is(
  (select count(*) = 4 from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'tests'
     and p.proname in (
       'create_test_user', 'impersonate', 'unimpersonate', 'add_approved_member'
     )),
  true,
  'test helpers installed'
);

select * from finish();
commit; -- keep schema + helpers for subsequent test files
