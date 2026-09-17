-- CaseThread migration 0032: enable RLS on Phase 5 tables.
--
-- 0025 created the investigation tables and 0028 created their
-- policies, but neither ENABLED row level security on them —
-- CREATE POLICY alone does not activate RLS, so the tables were
-- readable/writable by any authenticated user (caught in E2E
-- testing 2026-09-17: an outsider read another room's alibis).
--
-- case_rooms RLS was already enabled in 0005; its new
-- investigation_status column is covered by the existing policies.

alter table public.alibis enable row level security;
alter table public.alibi_evidence_links enable row level security;
alter table public.contradictions enable row level security;
alter table public.contradiction_sources enable row level security;
alter table public.investigation_gaps enable row level security;
alter table public.case_closed_summaries enable row level security;
