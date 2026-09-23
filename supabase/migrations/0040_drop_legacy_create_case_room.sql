-- CaseThread migration 0040: drop the superseded 2-arg create_case_room.
--
-- 0037 added p_access_code with a default, but `create or replace`
-- with a changed signature creates an overload rather than replacing
-- the original — leaving two functions matching a (text, text) call
-- ("function is not unique", SQLSTATE 42725). The 3-arg version is
-- behaviorally identical when the code is omitted, so the 0007
-- original is dead weight.

drop function if exists public.create_case_room(text, text);
