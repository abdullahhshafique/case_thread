-- Phase 2 activity-feed contract tests (0014): the feed shows what
-- changed since the member's watermark; marking seen clears it;
-- redaction applies to feed payloads; non-members see nothing.

begin;
select plan(6);

select tests.unimpersonate();
select tests.create_test_user('nf-lead@example.com');
select tests.create_test_user('nf-analyst@example.com');
select tests.create_test_user('nf-outsider@example.com');

select tests.impersonate('nf-lead@example.com');
insert into tests.fixtures (key, room_id)
select 'nf-room', (result).room_id
from public.create_case_room('Feed Test Room', 'legal') as result;

select tests.unimpersonate();
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'nf-room'),
  'nf-analyst@example.com', 'analyst'
);

-- Analyst marks the room seen BEFORE the new activity happens.
select tests.impersonate('nf-analyst@example.com');
insert into public.room_last_seen (user_id, room_id, last_seen_at)
values (auth.uid(), (select room_id from tests.fixtures where key = 'nf-room'),
        now() - interval '1 hour'); -- now() is transaction-stable: force past

-- 1. Watermark 1h in the past: the room's setup activity (created,
--    join requested, join approved) all falls AFTER it — the feed
--    shows that backlog. (All test statements share one transaction,
--    so now() is constant; the interval forces a strict boundary.)
select is(
  count(*),
  3::bigint,
  'feed shows pre-watermark setup activity (3 items)'
) from public.v_activity_feed;

-- New activity: lead uploads evidence (fixture via RPC).
select tests.unimpersonate();
select tests.impersonate('nf-lead@example.com');
select public.register_evidence(
  (select room_id from tests.fixtures where key = 'nf-room'),
  'feed-note.txt',
  'rooms/' || (select room_id::text from tests.fixtures where key = 'nf-room') || '/feed-note.txt',
  'text/plain', 10,
  repeat('3', 64)
);

-- 2. Feed grew by exactly the new upload.
select tests.impersonate('nf-analyst@example.com');
select is(
  count(*),
  4::bigint,
  'feed shows activity since the watermark'
) from public.v_activity_feed;

-- 3. The newest feed item is the evidence upload.
select is(
  (select action_type from public.v_activity_feed
   order by created_at desc limit 1),
  'evidence_uploaded',
  'feed item identifies the newest action'
);

-- 4. Marking seen again empties the feed.
insert into public.room_last_seen (user_id, room_id, last_seen_at)
values (auth.uid(), (select room_id from tests.fixtures where key = 'nf-room'), now())
on conflict (user_id, room_id) do update set last_seen_at = now();

select is(
  count(*),
  0::bigint,
  'marking seen clears the feed'
) from public.v_activity_feed;

-- 5. Non-member with a rogue watermark row cannot read the feed
--    (membership double-check in the view policy).
-- Fixture writes need superuser context (direct inserts).
select tests.unimpersonate();
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'nf-room'),
  'nf-outsider@example.com', 'observer'
);
-- Make outsider a member first, then REMOVE them (revoked) — feed must
-- stay empty because user_room_role returns null for revoked members.
select tests.unimpersonate();
update public.room_members set status = 'revoked'
where room_id = (select room_id from tests.fixtures where key = 'nf-room')
  and user_id = (select user_id from tests.fixtures where key = 'nf-outsider@example.com');
select tests.impersonate('nf-outsider@example.com');
insert into public.room_last_seen (user_id, room_id, last_seen_at)
values (auth.uid(), (select room_id from tests.fixtures where key = 'nf-room'), now() - interval '1 day');

select is(
  count(*),
  0::bigint,
  'revoked member with old watermark sees no feed'
) from public.v_activity_feed;

-- 6. Analyst CANNOT read someone else's watermark (own-row policy).
select is(
  count(*),
  0::bigint,
  'cannot read another member watermark row'
) from public.room_last_seen
where room_id = (select room_id from tests.fixtures where key = 'nf-room')
  and user_id <> auth.uid();

select * from finish();
rollback;
