-- CaseThread migration 0001: profiles table (Architecture.md §5).
--
-- DRAFT for Sprint 2 schema work — apply via `supabase db push` or the
-- Supabase SQL editor once the dev project is provisioned. The full core
-- schema (case_rooms, room_members, roles, evidence_items, timeline_events,
-- audit_log, discussion_messages, tasks) lands as migration 0002+ per the
-- ExecutionPlan.md Sprint 2 plan; every RLS policy ships with its contract
-- tests in the same PR (Rules.md §7).

-- Display names/avatars live here rather than in auth.users metadata so
-- they're queryable and joinable (auth schema is not directly writable).
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 80),
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- A new auth user gets a profile row automatically; display_name falls
-- back to the email local-part, matching the client's fallback logic.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;

-- Users can read their own profile (and nothing else — Sprint 2 extends
-- this to room-scoped member reads).
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);
