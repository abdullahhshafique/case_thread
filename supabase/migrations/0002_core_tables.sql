-- CaseThread migration 0002: core tables (Architecture.md §5).
--
-- Every table from the logical schema. AI/entity tables (ai_suggestions,
-- entities, entity_relationships) are created NOW for forward
-- compatibility (ExecutionPlan.md Sprint 2) but get deny-all RLS until
-- their features ship — Phase 2–3 code extends rather than migrates.
-- All changes are additive (Architecture.md §14).

-- ---------------------------------------------------------------------------
-- case_rooms: the core unit of the product (PRD §11 glossary).
-- access_code_hash: never plaintext (Architecture.md §9).
-- ---------------------------------------------------------------------------
create table public.case_rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  case_type text not null, -- FK to case_types added below (seed table)
  owner_id uuid not null references auth.users (id) on delete cascade,
  access_code_hash text not null,
  code_rotated_at timestamptz not null default now(),
  status text not null default 'active'
    check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Keep name/owner pairs unique so "recreating" a room can't shadow an old one.
create unique index case_rooms_owner_name_unique
  on public.case_rooms (owner_id, lower(name));

-- ---------------------------------------------------------------------------
-- case_types: domain modules are DATA, not code (Architecture.md §2).
-- allowed_roles drives the join-flow role picker (PRD §6.2).
-- ---------------------------------------------------------------------------
create table public.case_types (
  id text primary key, -- e.g. 'legal', 'academic'
  display_name text not null,
  description text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.case_rooms
  add constraint case_rooms_case_type_fkey
  foreign key (case_type) references public.case_types (id);

-- ---------------------------------------------------------------------------
-- roles: permission matrix per role, per case type (PRD §6.3).
-- permissions JSONB keys (draft grid in docs/permission-matrix-draft.md):
--   view_case, edit_case, upload_evidence, comment, approve_ai_findings,
--   manage_members, export_reports, view_privileged
-- RLS policies read these keys via ->>bool (Architecture.md §5).
-- ---------------------------------------------------------------------------
create table public.roles (
  id text primary key, -- e.g. 'lead_investigator'
  case_type text not null references public.case_types (id) on delete cascade,
  display_name text not null,
  is_lead_tier boolean not null default false, -- can approve AI findings
  permissions jsonb not null,
  created_at timestamptz not null default now(),
  unique (case_type, id)
);

-- ---------------------------------------------------------------------------
-- room_members: one user → one room → one active role (PRD §6.2–6.3).
-- status 'pending' = awaiting owner approval.
-- ---------------------------------------------------------------------------
create table public.room_members (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role_id text not null references public.roles (id),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'revoked')),
  requested_at timestamptz not null default now(),
  joined_at timestamptz, -- set on approval
  unique (room_id, user_id)
);

create index room_members_user_idx on public.room_members (user_id);
create index room_members_room_idx on public.room_members (room_id, status);

-- ---------------------------------------------------------------------------
-- evidence_items: the shared vault (PRD §6.4).
-- file_hash for chain-of-custody; version for duplicate-name suffixing.
-- ---------------------------------------------------------------------------
create table public.evidence_items (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  uploader_id uuid not null references auth.users (id) on delete cascade,
  filename text not null,
  storage_path text not null,
  file_hash text not null,
  mime_type text not null default 'application/octet-stream',
  file_size_bytes bigint not null check (file_size_bytes >= 0),
  version integer not null default 1,
  uploaded_at timestamptz not null default now(),
  unique (room_id, storage_path)
);

create index evidence_items_room_idx on public.evidence_items (room_id, uploaded_at desc);

-- ---------------------------------------------------------------------------
-- timeline_events: manual + system + ai_suggestion types (PRD §6.5).
-- ---------------------------------------------------------------------------
create table public.timeline_events (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  event_type text not null
    check (event_type in ('manual', 'system', 'ai_suggestion')),
  actor_id uuid references auth.users (id) on delete set null, -- null = system
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index timeline_events_room_idx on public.timeline_events (room_id, occurred_at desc);

-- ---------------------------------------------------------------------------
-- audit_log: append-only (PRD §6.5, Architecture.md §4/§9).
-- Immutability enforced in migration 0003 (grants + trigger).
-- ---------------------------------------------------------------------------
create table public.audit_log (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  actor_id uuid references auth.users (id) on delete set null,
  action_type text not null,
  object_type text not null,
  object_id text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index audit_log_room_idx on public.audit_log (room_id, created_at desc);
create index audit_log_action_idx on public.audit_log (action_type);

-- ---------------------------------------------------------------------------
-- discussion_messages: threaded, @mentions (PRD §6.6).
-- Thread structure: parent_message_id null = top-level entry.
-- ---------------------------------------------------------------------------
create table public.discussion_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  parent_message_id uuid references public.discussion_messages (id) on delete cascade,
  author_id uuid not null references auth.users (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  mentions uuid[] not null default '{}',
  created_at timestamptz not null default now()
);

create index discussion_messages_room_idx on public.discussion_messages (room_id, created_at desc);

-- ---------------------------------------------------------------------------
-- tasks (PRD §6.6).
-- ---------------------------------------------------------------------------
create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 200),
  assignee_id uuid references auth.users (id) on delete set null,
  created_by uuid not null references auth.users (id) on delete cascade,
  due_date date,
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'done')),
  linked_evidence_id uuid references public.evidence_items (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tasks_room_idx on public.tasks (room_id, status);

-- ---------------------------------------------------------------------------
-- ai_suggestions: AI output lands ONLY here, never in case tables
-- (Rules.md §11, Architecture.md §2 human-in-the-loop).
-- ---------------------------------------------------------------------------
create table public.ai_suggestions (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  agent_type text not null,
  input_ref text not null default '',
  output jsonb not null,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'edited', 'dismissed')),
  reviewed_by uuid references auth.users (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index ai_suggestions_room_idx on public.ai_suggestions (room_id, status);

-- ---------------------------------------------------------------------------
-- entities + entity_relationships: Phase 2 relationship map (Architecture.md §5).
-- ---------------------------------------------------------------------------
create table public.entities (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  entity_type text not null
    check (entity_type in ('person', 'org', 'location', 'evidence')),
  name text not null check (char_length(name) between 1 and 200),
  attributes jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Expression uniqueness needs an index, not a table constraint.
create unique index entities_room_type_name_unique
  on public.entities (room_id, entity_type, lower(name));

create table public.entity_relationships (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  from_entity_id uuid not null references public.entities (id) on delete cascade,
  to_entity_id uuid not null references public.entities (id) on delete cascade,
  relationship_type text not null,
  created_at timestamptz not null default now(),
  unique (from_entity_id, to_entity_id, relationship_type),
  check (from_entity_id <> to_entity_id)
);
