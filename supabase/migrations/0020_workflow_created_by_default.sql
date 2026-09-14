-- CaseThread migration 0020: hotfix for 0018 — client-side workflow
-- creation failed live (created_by NOT NULL with no default; the
-- builder sheet inserts room_id/name/steps only). Recorded as its own
-- migration per the recorded-migration discipline: fresh environments
-- get the fix via 0018 itself (edited in place before any other env
-- applied it is NOT the policy — 0018 already shipped to cloud, so
-- this is the additive correction).
--
-- auth.uid() default: client inserts never send created_by; the
-- insert RLS policy already requires edit_case, so a non-member
-- cannot reach the default at all.

alter table public.ai_workflows
  alter column created_by set default auth.uid();
