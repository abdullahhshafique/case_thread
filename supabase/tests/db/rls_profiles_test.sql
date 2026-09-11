-- RLS contract tests: profiles table (0001 migration).
-- Rules.md §7: every policy proves BOTH the allowed and denied case.

begin;
select plan(4);

-- Fixtures: two users, created in postgres context.
select tests.unimpersonate();
select tests.create_test_user('alice@example.com') as alice_id \gset
select tests.create_test_user('bob@example.com') as bob_id \gset

-- Owner can read their own profile (policy: profiles_select_own).
select tests.impersonate(:'alice_id');
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
select tests.impersonate(:'alice_id');
update public.profiles set display_name = 'Alice Edited' where id = :'alice_id';
select is(
  display_name,
  'Alice Edited',
  'user can update own display_name'
) from public.profiles where id = :'alice_id';

-- Update of someone else's row must not apply (row invisible → 0 rows).
update public.profiles set display_name = 'Hacked' where id = :'bob_id';
select is(
  display_name,
  'bob',
  'cannot update another user profile (row filtered out)'
) from public.profiles where id = :'bob_id';

select * from finish();
rollback;
