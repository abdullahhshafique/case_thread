-- CaseThread migration 0028: RLS policies for all Phase 5
-- new objects (Architecture-Phase5.md §6, Rules.md §7).
--
-- Every new table/view gets explicit allow/deny RLS
-- contract tests (non-negotiable DoD).
-- Pattern follows migration 0005:
--   user_room_role()/user_room_permission() for scoping.

-- ---------------------------------------------------------------------------
-- alibis
-- ---------------------------------------------------------------------------
drop policy if exists "alibis visible to room members" on public.alibis;
create policy "alibis visible to room members"
  on public.alibis for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

drop policy if exists "alibis created by permitted members" on public.alibis;
create policy "alibis created by permitted members"
  on public.alibis for insert
  to authenticated
  with check (
    created_by = auth.uid()
    and public.user_room_permission(room_id, 'edit_case')
  );

drop policy if exists "alibis updated by permitted members" on public.alibis;
create policy "alibis updated by permitted members"
  on public.alibis for update
  to authenticated
  using (
    public.user_room_permission(room_id, 'edit_case')
    or created_by = auth.uid()
  );

-- ---------------------------------------------------------------------------
-- alibi_evidence_links (inherits parent evidence/timeline RLS —
-- a role that can't see an evidence item must not see it linked)
-- ---------------------------------------------------------------------------
drop policy if exists "alibi evidence links visible to room members"
  on public.alibi_evidence_links;
create policy "alibi evidence links visible to room members"
  on public.alibi_evidence_links for select
  to authenticated
  using (
    public.user_room_role(auth.uid(),
      (select room_id from public.alibis a where a.id = alibi_id))
    is not null
  );

drop policy if exists "alibi evidence links created by permitted members"
  on public.alibi_evidence_links;
create policy "alibi evidence links created by permitted members"
  on public.alibi_evidence_links for insert
  to authenticated
  with check (
    public.user_room_permission(
      (select room_id from public.alibis a where a.id = alibi_id),
      'edit_case'
    )
  );

-- ---------------------------------------------------------------------------
-- contradictions
-- ---------------------------------------------------------------------------
drop policy if exists "contradictions visible to room members"
  on public.contradictions;
create policy "contradictions visible to room members"
  on public.contradictions for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

drop policy if exists "contradictions created by permitted members"
  on public.contradictions;
create policy "contradictions created by permitted members"
  on public.contradictions for insert
  to authenticated
  with check (
    flagged_by = auth.uid()
    and source_type = 'manual'
    and public.user_room_permission(room_id, 'edit_case')
  );

drop policy if exists "contradictions resolved by lead tier"
  on public.contradictions;
create policy "contradictions resolved by lead tier"
  on public.contradictions for update
  to authenticated
  using (
    public.user_room_permission(room_id, 'approve_ai_findings')
  );

-- ---------------------------------------------------------------------------
-- contradiction_sources
-- ---------------------------------------------------------------------------
drop policy if exists "contradiction sources visible to room members"
  on public.contradiction_sources;
create policy "contradiction sources visible to room members"
  on public.contradiction_sources for select
  to authenticated
  using (
    public.user_room_role(auth.uid(),
      (select room_id from public.contradictions c
        where c.id = contradiction_id))
    is not null
  );

drop policy if exists "contradiction sources created by permitted members"
  on public.contradiction_sources;
create policy "contradiction sources created by permitted members"
  on public.contradiction_sources for insert
  to authenticated
  with check (
    public.user_room_permission(
      (select room_id from public.contradictions c
        where c.id = contradiction_id),
      'edit_case'
    )
  );

-- ---------------------------------------------------------------------------
-- investigation_gaps
-- ---------------------------------------------------------------------------
drop policy if exists "investigation gaps visible to room members"
  on public.investigation_gaps;
create policy "investigation gaps visible to room members"
  on public.investigation_gaps for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

drop policy if exists "investigation gaps created by permitted members"
  on public.investigation_gaps;
create policy "investigation gaps created by permitted members"
  on public.investigation_gaps for insert
  to authenticated
  with check (
    created_by = auth.uid()
    and public.user_room_permission(room_id, 'edit_case')
  );

drop policy if exists "investigation gaps updated by permitted members"
  on public.investigation_gaps;
create policy "investigation gaps updated by permitted members"
  on public.investigation_gaps for update
  to authenticated
  using (
    public.user_room_permission(room_id, 'edit_case')
    or created_by = auth.uid()
  );

-- ---------------------------------------------------------------------------
-- case_closed_summaries
-- ---------------------------------------------------------------------------
drop policy if exists "closed summaries visible to room members"
  on public.case_closed_summaries;
create policy "closed summaries visible to room members"
  on public.case_closed_summaries for select
  to authenticated
  using (public.user_room_role(auth.uid(), room_id) is not null);

-- ---------------------------------------------------------------------------
-- v_case_statistics — SELECT granted above (grant select).
-- No insert/update/delete — read-only view.
-- ---------------------------------------------------------------------------
