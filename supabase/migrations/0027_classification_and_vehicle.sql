-- CaseThread migration 0027: Fact/Claim/Finding/Unknown classification
-- + vehicle entity type (PDF §10/§13).
--
-- Additive-only (Architecture.md §14): existing rows are NULL/unclassified
-- by default; backfill is a separate decision, not required to ship.
--
-- entities.type extended to include 'vehicle' — satisfies the
-- CCTV → Event → Vehicle → Location → Person chain from the PDF.

-- ---------------------------------------------------------------------------
-- entities: add 'vehicle' to the entity_type CHECK (single value
-- addition, not a restructure — Architecture-Phase5.md §2.8).
-- ---------------------------------------------------------------------------
alter table public.entities
  add check (entity_type in ('person', 'org', 'location', 'evidence', 'vehicle'));

-- ---------------------------------------------------------------------------
-- evidence_items: classification column (PRD §4.1).
-- Nullable — existing rows stay unclassified until reviewed.
-- ---------------------------------------------------------------------------
alter table public.evidence_items
  add column classification text check (classification in (
    'fact', 'claim', 'finding', 'unknown'
  ));

-- ---------------------------------------------------------------------------
-- timeline_events: classification column (PRD §4.1).
-- Nullable — existing rows stay unclassified until reviewed.
-- ---------------------------------------------------------------------------
alter table public.timeline_events
  add column classification text check (classification in (
    'fact', 'claim', 'finding', 'unknown'
  ));
