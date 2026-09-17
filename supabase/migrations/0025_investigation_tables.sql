-- CaseThread migration 0025: Investigation Intelligence — core tables.
--
-- Adds three first-class investigation objects + two join tables:
--   alibis, alibi_evidence_links, contradictions, contradiction_sources,
--   investigation_gaps.
-- All tables are room-scoped (room_id FK → case_rooms, on delete cascade).
-- All enums implemented as CHECK constraints (existing project convention,
-- Architecture.md §5). All writes audited (audit_log, per PRD §6.5).
-- All changes additive (Architecture.md §14).
--
-- Follows the RLS-first model from migration 0005: member-scoped SELECT,
-- permission-gated INSERT/UPDATE via user_room_permission()/is_lead_tier.

-- ---------------------------------------------------------------------------
-- alibis: a claimed alibi for a person (entity), with a verification status
-- and a required human-readable reason. Never a bare status (PRD §4.2).
-- ---------------------------------------------------------------------------
create table public.alibis (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  entity_id uuid references public.entities (id) on delete set null, -- the person
  claimed_window_start timestamptz not null,
  claimed_window_end timestamptz not null,
  claim_text text not null check (char_length(claim_text) between 1 and 2000),
  source text not null default '',
  status text check (status in (
    'verified', 'partially_verified', 'conflict', 'insufficient_data'
  )),
  status_reason text check (
    (status is not null and status_reason is not null and char_length(status_reason) >= 1)
    or (status is null and status_reason is null)
  ),
  created_by uuid references auth.users (id) on delete set null,
  verified_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  verified_at timestamptz,
  unique (room_id, entity_id, claimed_window_start, claimed_window_end)
);

create index alibis_room_idx on public.alibis (room_id, created_at desc);
create index alibis_entity_idx on public.alibis (entity_id) where entity_id is not null;

-- ---------------------------------------------------------------------------
-- alibi_evidence_links: which evidence supports or contradicts each alibi.
-- Polymorphic: exactly one of evidence_item_id / timeline_event_id populated.
-- ---------------------------------------------------------------------------
create table public.alibi_evidence_links (
  id uuid primary key default gen_random_uuid(),
  alibi_id uuid not null references public.alibis (id) on delete cascade,
  evidence_item_id uuid references public.evidence_items (id) on delete cascade,
  timeline_event_id uuid references public.timeline_events (id) on delete cascade,
  relation text not null check (relation in ('supports', 'conflicts')),
  unique (alibi_id, evidence_item_id, timeline_event_id, relation),
  check (
    (evidence_item_id is not null and timeline_event_id is null)
    or (evidence_item_id is null and timeline_event_id is not null)
  )
);

create index alibi_evidence_links_alibi_idx on public.alibi_evidence_links (alibi_id);

-- ---------------------------------------------------------------------------
-- contradictions: a conflict between two or more sources, reviewable and
-- resolvable independent of which agent (or human) raised it (PRD §4.3).
-- ---------------------------------------------------------------------------
create table public.contradictions (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  source_type text not null check (source_type in ('manual', 'ai_suggestion')),
  ai_suggestion_id uuid references public.ai_suggestions (id) on delete set null,
  conflicting_detail text not null check (char_length(conflicting_detail) between 1 and 2000),
  relevant_time timestamptz,
  relevant_location text,
  flagged_reason text not null check (char_length(flagged_reason) between 1 and 2000),
  status text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  resolution_note text,
  linked_task_id uuid references public.tasks (id) on delete set null,
  flagged_by uuid references auth.users (id) on delete set null,
  resolved_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (
    (source_type = 'ai_suggestion' and ai_suggestion_id is not null)
    or (source_type = 'manual' and ai_suggestion_id is null)
  )
);

create index contradictions_room_idx on public.contradictions (room_id, created_at desc);
create index contradictions_status_idx on public.contradictions (room_id, status);

-- ---------------------------------------------------------------------------
-- contradiction_sources: the two-or-more conflicting items. Each row links
-- to exactly one polymorphic parent (evidence / timeline / alibi).
-- ---------------------------------------------------------------------------
create table public.contradiction_sources (
  id uuid primary key default gen_random_uuid(),
  contradiction_id uuid not null references public.contradictions (id) on delete cascade,
  evidence_item_id uuid references public.evidence_items (id) on delete cascade,
  timeline_event_id uuid references public.timeline_events (id) on delete cascade,
  alibi_id uuid references public.alibis (id) on delete cascade,
  unique (contradiction_id, evidence_item_id, timeline_event_id, alibi_id),
  check (
    coalesce(evidence_item_id is not null, false)::int
    + coalesce(timeline_event_id is not null, false)::int
    + coalesce(alibi_id is not null, false)::int = 1
  )
);

create index contradiction_sources_contradiction_idx on public.contradiction_sources (contradiction_id);

-- ---------------------------------------------------------------------------
-- investigation_gaps: structured record of what the case does NOT yet
-- establish (PRD §4.4 / §16). The PDF's "major feature."
-- ---------------------------------------------------------------------------
create table public.investigation_gaps (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.case_rooms (id) on delete cascade,
  gap_type text not null default 'unknown', -- free-form or config-table lookup (Arch §1)
  description text not null check (char_length(description) between 1 and 2000),
  source_type text not null check (source_type in ('manual', 'ai_suggestion')),
  ai_suggestion_id uuid references public.ai_suggestions (id) on delete set null,
  status text not null default 'open' check (status in ('open', 'in_progress', 'resolved')),
  linked_task_id uuid references public.tasks (id) on delete set null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (
    (source_type = 'ai_suggestion' and ai_suggestion_id is not null)
    or (source_type = 'manual' and ai_suggestion_id is null)
  )
);

create index investigation_gaps_room_idx on public.investigation_gaps (room_id, created_at desc);
create index investigation_gaps_status_idx on public.investigation_gaps (room_id, status);
