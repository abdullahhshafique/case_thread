-- 0042: case_rooms.briefing — Phase 2 briefing card / Phase 6 editor.
-- Null = no briefing yet (the card shows the honest placeholder).
-- Reads ride the existing case_rooms SELECT policies; writes ride the
-- existing UPDATE policy (edit_case / owner), so no new RLS here.
alter table public.case_rooms
  add column if not exists briefing text;
