-- RLS contract tests: evidence vault — storage.objects policies +
-- register_evidence RPC (0009 migration). Rules.md §7: allowed AND
-- denied cases for every policy.

begin;
select plan(10);

select tests.unimpersonate();
select tests.create_test_user('vault-lead@example.com');
select tests.create_test_user('vault-analyst@example.com');
select tests.create_test_user('vault-observer@example.com');
select tests.create_test_user('vault-outsider@example.com');

-- Room owned by lead; analyst + observer are approved members.
select tests.impersonate('vault-lead@example.com');
insert into tests.fixtures (key, room_id)
select 'vault-room', (result).room_id
from public.create_case_room('Vault Test Room', 'legal') as result;

select tests.unimpersonate();
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'vault-room'),
  'vault-analyst@example.com', 'analyst'
);
select tests.add_approved_member(
  (select room_id from tests.fixtures where key = 'vault-room'),
  'vault-observer@example.com', 'observer'
);

-- 1. register_evidence works for a permitted member (analyst).
select tests.impersonate('vault-analyst@example.com');
insert into tests.fixtures (key, member_id, text_value)
select 'vault-ev-1', (r).evidence_id, (r).version_no::text
from public.register_evidence(
  (select room_id from tests.fixtures where key = 'vault-room'),
  'contract.pdf',
  'rooms/' || (select room_id from tests.fixtures where key = 'vault-room') || '/contract.pdf',
  'application/pdf', 2048,
  repeat('a', 64)
) as r;

select is(
  (text_value = '1' and member_id is not null),
  true,
  'register_evidence returns id and version 1 for permitted member'
) from tests.fixtures where key = 'vault-ev-1';

-- 2. Duplicate filename auto-versions (PRD §6.4 edge case).
select tests.impersonate('vault-lead@example.com');
insert into tests.fixtures (key, text_value)
select 'vault-ev-2', (r).version_no::text
from public.register_evidence(
  (select room_id from tests.fixtures where key = 'vault-room'),
  'contract.pdf', -- same name, different case on disk path is same room
  'rooms/' || (select room_id from tests.fixtures where key = 'vault-room') || '/contract-v2.pdf',
  'application/pdf', 2048,
  repeat('b', 64)
) as r;

select is(
  text_value,
  '2',
  'duplicate filename auto-versions to 2'
) from tests.fixtures where key = 'vault-ev-2';

-- 3. Observer (upload_evidence false) is rejected by the RPC.
select tests.impersonate('vault-observer@example.com');
select throws_ok(
  'select * from public.register_evidence('
    || quote_literal((select room_id from tests.fixtures where key = 'vault-room'))
    || ', ''sneak.pdf'', '
    || '''rooms/'' || ' || quote_literal((select room_id from tests.fixtures where key = 'vault-room'))
    || ' || ''/sneak.pdf'', ''application/pdf'', 10, repeat(''c'', 64))',
  'Your role cannot upload evidence in this room.',
  'observer register_evidence rejected (upload_evidence false)'
);

-- 4. Cross-room path rejected.
select tests.impersonate('vault-analyst@example.com');
select throws_ok(
  'select * from public.register_evidence('
    || quote_literal((select room_id from tests.fixtures where key = 'vault-room'))
    || ', ''evil.pdf'', ''rooms/00000000-0000-0000-0000-000000000000/evil.pdf'', '
    || '''application/pdf'', 10, repeat(''d'', 64))',
  'Evidence path does not match the room.',
  'cross-room path rejected'
);

-- 5. Oversize file rejected by the RPC (server-side 50MB).
select throws_ok(
  'select * from public.register_evidence('
    || quote_literal((select room_id from tests.fixtures where key = 'vault-room'))
    || ', ''big.pdf'', '
    || '''rooms/'' || ' || quote_literal((select room_id from tests.fixtures where key = 'vault-room'))
    || ' || ''/big.pdf'', ''application/pdf'', 52428801, repeat(''e'', 64))',
  'File exceeds the 50MB limit.',
  'oversize file rejected server-side'
);

-- 6. Bad hash rejected.
select throws_ok(
  'select * from public.register_evidence('
    || quote_literal((select room_id from tests.fixtures where key = 'vault-room'))
    || ', ''bad.pdf'', '
    || '''rooms/'' || ' || quote_literal((select room_id from tests.fixtures where key = 'vault-room'))
    || ' || ''/bad.pdf'', ''application/pdf'', 10, ''nothex'')',
  'Invalid file hash.',
  'non-sha256 hash rejected'
);

-- 7. Direct evidence_items INSERT is no longer permitted (RPC is the
-- only sanctioned path — the generic policy was removed in 0009).
select throws_ok(
  'insert into public.evidence_items ('
    || 'room_id, uploader_id, filename, storage_path, file_hash, file_size_bytes) '
    || 'values (' || quote_literal((select room_id from tests.fixtures where key = 'vault-room'))
    || ', auth.uid(), ''direct.pdf'', ''rooms/x/direct.pdf'', '
    || 'repeat(''f'', 64), 10)',
  'new row violates row-level security policy for table "evidence_items"',
  'direct evidence_items INSERT rejected (RPC-only)'
);

-- 8. storage.objects: analyst (permitted) can upload into room path.
insert into storage.objects (
  bucket_id, name, owner, metadata
)
values (
  'evidence',
  'rooms/' || (select room_id from tests.fixtures where key = 'vault-room') || '/contract.pdf',
  auth.uid(),
  '{"size":2048,"mimetype":"application/pdf"}'::jsonb
);
select is(
  count(*),
  1::bigint,
  'storage upload allowed for permitted member in room path'
) from storage.objects
where bucket_id = 'evidence';

-- 9. storage.objects: upload into another room's path rejected.
select throws_ok(
  'insert into storage.objects (bucket_id, name, owner, metadata) '
    || 'values (''evidence'', ''rooms/00000000-0000-0000-0000-000000000000/stolen.pdf'', '
    || 'auth.uid(), ''{"size":1,"mimetype":"application/pdf"}''::jsonb)',
  'new row violates row-level security policy for table "objects"',
  'storage upload rejected for non-member room path'
);

-- 10. Audit entry written for the first upload (checked as owner).
select tests.impersonate('vault-lead@example.com');
select is(
  count(*),
  2::bigint,
  'evidence uploads logged to audit trail'
) from public.audit_log
where room_id = (select room_id from tests.fixtures where key = 'vault-room')
  and action_type = 'evidence_uploaded';

select * from finish();
rollback;
