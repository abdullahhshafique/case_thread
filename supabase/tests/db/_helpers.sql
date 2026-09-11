-- Shared pgTAP helpers for CaseThread RLS contract tests.
--
-- Loaded before each test file by supabase test db (files run
-- alphabetically; the underscore prefix keeps this first). Everything
-- runs inside the runner's transaction and rolls back, so tests can
-- freely create fixtures.
--
-- NOTE: no psql client metacommands (\gset etc.) — the Supabase CLI test
-- runner is not psql; values pass between statements via tables/DO
-- blocks instead.

-- Fixture store: test-owned users/rooms/members addressable by email.
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

-- Impersonate a user for subsequent statements in the test transaction:
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
    true -- transaction-scoped: resets on rollback
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
