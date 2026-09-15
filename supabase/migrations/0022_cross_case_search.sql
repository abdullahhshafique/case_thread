-- CaseThread migration 0022: Phase 4 — cross-case search
-- (Phases.md §5 "cross-case search" P2; PRD P1 story "search across all
-- my cases" — one of the most-requested pilot items).
--
-- Design (Architecture.md §9: the server is the security boundary):
--   * Postgres full-text search across the content a member can ALREADY
--     read: room names, discussion bodies, timeline manual-event
--     summaries, task titles, evidence filenames.
--   * The search RPC is SECURITY INVOKER and reads through the SAME
--     base tables + redacted views the client reads — RLS member
--     policies do the row scoping, redact_payload (0013) does the
--     field masking. No new permission surface: if you couldn't
--     SELECT it, search won't find it.
--   * The tsvector expression is computed inline (a GIN index would
--     only help at thousands of rooms; Rules.md §9 — measure first,
--     index when a real workload asks for it).
--
-- Rules.md §11-adjacent invariants:
--   * Privileged timeline payload sub-objects NEVER enter search text
--     (v_timeline strips them per caller BEFORE matching).
--   * Search hits carry no privileged fields.

-- ---------------------------------------------------------------------------
-- search_cases(): prefix full-text search across the CALLER's visible
-- content (typo tolerance is out of scope; 'contra' matches 'contract'
-- via the :* prefix form). One row per hit with room context.
-- SECURITY DEFINER is NOT used on purpose — invoker rights keep RLS +
-- redaction in the loop, exactly like every client read.
-- ---------------------------------------------------------------------------
create or replace function public.search_cases(query text)
returns table (
  room_id uuid,
  room_name text,
  case_type text,
  object_type text, -- 'room' | 'discussion' | 'timeline' | 'task' | 'evidence'
  object_id text,
  snippet text, -- matched text, redaction-aware
  created_at timestamptz
)
language plpgsql
stable
as $$
declare
  ts_query tsquery;
begin
  -- Sanitize to word characters only: to_tsquery would otherwise throw
  -- on operators like '&' or '!' typed by the user ('simple' has no
  -- stop-words, so every surviving token participates).
  ts_query := to_tsquery('simple', coalesce((
    select string_agg(lexeme || ':*', ' & ')
    from unnest(string_to_array(
      regexp_replace(coalesce(query, ''), '[^a-zA-Z0-9\s]+', ' ', 'g'),
      ' '
    )) as lexeme
    where lexeme <> ''
  ), ''));

  if ts_query is null then
    return; -- nothing sensible to match
  end if;

  return query
  select cr.id, cr.name, cr.case_type,
         s.object_type, s.object_id, s.snippet, s.created_at
  from (
    -- Room names (any member's rooms).
    select cr.id as room_id, 'room'::text as object_type,
           ''::text as object_id, cr.name as snippet,
           cr.created_at
    from public.case_rooms cr
    where to_tsvector('simple', cr.name) @@ ts_query

    union all
    -- Discussion bodies (member-visible via base-table RLS).
    select dm.room_id, 'discussion', dm.id::text,
           dm.body, dm.created_at
    from public.discussion_messages dm
    where to_tsvector('simple', dm.body) @@ ts_query

    union all
    -- Manual timeline summaries — read through v_timeline so the
    -- privileged sub-object is stripped per caller BEFORE matching.
    select te.room_id, 'timeline', te.id::text,
           coalesce(te.payload ->> 'summary', ''), te.occurred_at
    from public.v_timeline te
    where te.event_type = 'manual'
      and to_tsvector('simple', coalesce(te.payload ->> 'summary', ''))
        @@ ts_query

    union all
    -- Task titles.
    select tk.room_id, 'task', tk.id::text, tk.title, tk.created_at
    from public.tasks tk
    where to_tsvector('simple', tk.title) @@ ts_query

    union all
    -- Evidence filenames (names only — never hashes/paths in snippets).
    select ev.room_id, 'evidence', ev.id::text, ev.filename,
           ev.uploaded_at
    from public.evidence_items ev
    where to_tsvector('simple', ev.filename) @@ ts_query
  ) s
  join public.case_rooms cr on cr.id = s.room_id
  order by s.created_at desc
  limit 50; -- Rules.md §9: bound every client-facing query
end;
$$;

-- PostgREST callable by authenticated users only (the function itself
-- enforces visibility via RLS — being callable is not being trusted).
revoke execute on function public.search_cases(text) from public, anon;
grant execute on function public.search_cases(text) to authenticated;
