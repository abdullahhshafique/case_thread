-- CaseThread migration 0008: member-list display names.
--
-- PostgREST relationship embeds (room_members → profiles) need a
-- declared FK. room_members.user_id references auth.users; adding the
-- explicit FK to profiles.id (1:1 with auth.users via 0001) makes
-- `room_members?select=*,profiles(display_name)` resolvable and lets
-- the co-member visibility policy (0007) join cleanly.

alter table public.room_members
  add constraint room_members_profile_fkey
  foreign key (user_id) references public.profiles (id) on delete cascade;
