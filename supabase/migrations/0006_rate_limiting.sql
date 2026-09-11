-- CaseThread migration 0006: join-attempt rate limiting (PRD §6.2,
-- Architecture.md §9: resist brute-forcing the 8-char code space).
--
-- Sprint 3's join flow calls public.check_join_rate_limit() before
-- validating a code. Attempts are recorded per user AND per IP; either
-- exceeding the window rejects the attempt with no information about
-- whether the code existed.

create table public.join_attempts (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete cascade,
  ip_address inet not null,
  succeeded boolean not null default false,
  attempted_at timestamptz not null default now()
);

create index join_attempts_user_time_idx
  on public.join_attempts (user_id, attempted_at desc);
create index join_attempts_ip_time_idx
  on public.join_attempts (ip_address, attempted_at desc);

alter table public.join_attempts enable row level security;
-- No SELECT/INSERT policies: clients never read or write this table
-- directly; the security-definer functions below manage it.

-- Constants: 10 attempts per user and 30 per IP in a 10-minute window.
-- Tunable per deployment by editing this migration's successor — never
-- this file (migrations are immutable history).
create or replace function public.join_rate_limits()
returns table (max_per_user int, max_per_ip int, window_minutes int)
language sql
stable
as $$
  select 10, 30, 10;
$$;

-- Returns true if the caller is within the rate limit and should be
-- allowed to attempt a join. Raises no detail about the code itself.
create or replace function public.check_join_rate_limit()
returns boolean
language plpgsql
security definer set search_path = public
as $$
declare
  limits record;
  user_attempts int;
  ip_attempts int;
  caller_ip inet;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into limits from public.join_rate_limits();

  caller_ip := coalesce(
    nullif(current_setting('request.headers.x-forwarded-for', true), '')::inet,
    '127.0.0.1'::inet
  );

  select count(*) into user_attempts
  from public.join_attempts
  where user_id = auth.uid()
    and attempted_at > now() - (limits.window_minutes || ' minutes')::interval;

  select count(*) into ip_attempts
  from public.join_attempts
  where ip_address = caller_ip
    and attempted_at > now() - (limits.window_minutes || ' minutes')::interval;

  return user_attempts < limits.max_per_user and ip_attempts < limits.max_per_ip;
end;
$$;

-- Records a join attempt outcome (called by the join flow after the
-- check). Security definer so the client never touches the table.
create or replace function public.record_join_attempt(was_successful boolean)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  caller_ip inet;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  caller_ip := coalesce(
    nullif(current_setting('request.headers.x-forwarded-for', true), '')::inet,
    '127.0.0.1'::inet
  );

  insert into public.join_attempts (user_id, ip_address, succeeded)
  values (auth.uid(), caller_ip, was_successful);
end;
$$;
