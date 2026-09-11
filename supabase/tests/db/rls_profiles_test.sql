-- RLS contract tests: profiles table (0001 migration).
-- Rules.md §7: every policy proves BOTH the allowed and denied case.
-- No psql metacommands — values pass via the tests.fixtures table.

begin;
select plan(4);

select tests.unimpersonate();
select tests.create_test_user('alice@example.com');
select tests.create_test_user('bob@example.com');

-- Owner can read their own profile (policy: profiles_select_own).
select tests.impersonate('alice@example.com');
select is(
  count(*),
  1::bigint,
  'user sees exactly their own profile'
) from public.profiles;

-- Cannot see the other user's profile row.
select is(
  count(*),
  0::bigint,
  'user cannot see another user profile row'
) from public.profiles
where display_name like 'bob%';

select tests.unimpersonate();

-- Owner can update own profile.
select tests.impersonate('alice@example.com');
update public.profiles
set display_name = 'Alice Edited'
where id = (select user_id from tests.fixtures where key = 'alice@example.com');
select is(
  display_name,
  'Alice Edited',
  'user can update own display_name'
) from public.profiles
where id = (select user_id from tests.fixtures where key = 'alice@example.com');

-- Update of someone else's row must not apply (row invisible → 0 rows).
update public.profiles set display_name = 'Hacked'
where id = (select user_id from tests.fixtures where key = 'bob@example.com');
select is(
  display_name,
  'bob',
  'cannot update another user profile (row filtered out)'
) from public.profiles
where id = (select user_id from tests.fixtures where key = 'bob@example.com');

select * from finish();
rollback;
