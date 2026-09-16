-- Phase 4 contract tests (0022): cross-case search.
-- Allow AND deny per Rules.md §7: member scoping (no cross-room leaks),
-- per-object-type hits, prefix matching, empty/short queries, and the
-- redaction boundary (privileged payload text is NOT searchable by
-- roles lacking view_privileged).

begin;
select plan(10);

select tests.unimpersonate();
select tests.create_test_user('search-lead@example.com');
select tests.create_test_user('search-analyst@example.com');
select tests.create_test_user('search-outsider@example.com');

-- Two rooms: lead owns both; analyst is a member of A only.
select tests.impersonate('search-lead@example.com');
insert into tests.fixtures (key, room_id)
select 'room-a', (result).room_id
from public.create_case_room('Alpha Fraud Matter', 'legal') as result;

select tests.impersonate('search-lead@example.com');
insert into tests.fixtures (key, room_id)
select 'room-b', (result).room_id
from public.create_case_room('Beta Contract Dispute', 'legal') as result;

select tests.unimpersonate();
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'room-a'),
  'search-analyst@example.com', 'analyst'
);

select tests.unimpersonate();
-- Content in room A: discussion + timeline (incl. a privileged manual
-- event) + task + evidence, all seeded as postgres.
insert into public.discussion_messages (room_id, author_id, body)
select f.room_id, (select user_id from tests.fixtures where key = 'search-analyst@example.com'),
       'The witness memo mentions the shell company ledger.'
from tests.fixtures f
where f.key = 'room-a';

insert into public.timeline_events (room_id, event_type, actor_id, payload)
select f.room_id, 'manual', (select user_id from tests.fixtures where key = 'search-analyst@example.com'),
  '{"summary": "Filed the quarterly report", "privileged": {"summary": "secret grand jury detail"}}'
from tests.fixtures f
where f.key = 'room-a';

insert into public.tasks (room_id, title, created_by)
select f.room_id, 'Review the ledger entries', (select user_id from tests.fixtures where key = 'search-analyst@example.com')
from tests.fixtures f
where f.key = 'room-a';

insert into public.evidence_items (
  room_id, uploader_id, filename, storage_path, file_hash, file_size_bytes
)
select f.room_id, (select user_id from tests.fixtures where key = 'search-analyst@example.com'), 'ledger-scan.pdf',
       'rooms/' || f.room_id::text || '/ledger-scan.pdf',
       repeat('a', 64), 2048
from tests.fixtures f
where f.key = 'room-a';

-- Content in room B (analyst NOT a member): the leak probe.
insert into public.discussion_messages (room_id, author_id, body)
select f.room_id,
       (select user_id from tests.fixtures where key = 'search-lead@example.com'),
       'Beta room private chatter about the merger memo.'
from tests.fixtures f
where f.key = 'room-b';

-- 1. Member search hits discussion content in their room.
select tests.impersonate('search-analyst@example.com');
select is(
  (select count(*) from (
    select * from public.search_cases('memo')
  ) s where object_type = 'discussion'),
  1::bigint,
  'member finds discussion content in their room'
);

-- 2. Prefix matching: 'ledg' matches ledger (room A only — analyst has
--    no room-B visibility).
select is(
  (select count(*) from public.search_cases('ledg')),
  3::bigint,
  'prefix query matches discussion, task, and evidence hits'
);
select is(
  (select count(*) from (
    select * from public.search_cases('ledg')
  ) s where object_type = 'evidence'),
  1::bigint,
  'evidence filename hits carry the filename as snippet'
);

-- 3. Task titles searchable.
select is(
  (select count(*) from public.search_cases('Review the ledger entries')),
  1::bigint,
  'task title is searchable'
);

-- 4. Room names searchable by members.
select is(
  (select count(*) from public.search_cases('Alpha Fraud')),
  1::bigint,
  'room name is searchable by a member'
);

-- 5. Non-member rooms never leak: analyst searching 'merger' (only in
--    room B) gets ZERO hits — RLS does the scoping, deny proof.
select is(
  (select count(*) from public.search_cases('merger')),
  0::bigint,
  'rooms the caller is not a member of are not searched (RLS deny)'
);

-- 6. Outsider sees nothing at all (no rooms, no content).
select tests.impersonate('search-outsider@example.com');
select is(
  (select count(*) from public.search_cases('ledger')),
  0::bigint,
  'outsider gets zero hits across all content'
);

-- 7. Redaction boundary: the privileged manual-event summary lives in
--    payload->privileged->summary. v_timeline strips it for the
--    analyst (view_privileged=false) BEFORE matching — the non-
--    privileged sibling summary stays findable.
select tests.impersonate('search-analyst@example.com');
select is(
  (select count(*) from public.search_cases('grand jury')),
  0::bigint,
  'privileged payload text is not searchable (redaction hold)'
);
select is(
  (select count(*) from public.search_cases('quarterly report')),
  1::bigint,
  'non-privileged summary text is searchable'
);

-- 8. Short/garbage queries return empty, not errors.
select is(
  (select count(*) from public.search_cases('x')),
  0::bigint,
  'single-character query returns empty'
);

select * from finish();
rollback;
