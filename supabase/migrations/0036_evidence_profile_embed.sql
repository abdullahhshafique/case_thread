-- CaseThread migration 0036: evidence_items → profiles display-name embed.
--
-- 0002 pointed evidence_items.uploader_id at auth.users; 0011 added the
-- profile-FK embed pattern for timeline_events + tasks but never
-- evidence_items — so the vault's
-- `profiles!evidence_items_uploader_id_fkey` embed fails with PGRST200
-- (caught in the field 2026-09-20). Mirror the 0011 pattern: backfill
-- any profile the 0001 trigger missed, then re-point the FK at
-- public.profiles under the exact name the client hints.

insert into public.profiles (id, display_name)
select u.id,
       coalesce(u.raw_user_meta_data ->> 'display_name',
                split_part(u.email, '@', 1))
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict (id) do nothing;

alter table public.evidence_items
  drop constraint if exists evidence_items_uploader_id_fkey;

alter table public.evidence_items
  add constraint evidence_items_uploader_id_fkey
  foreign key (uploader_id) references public.profiles (id) on delete cascade;
