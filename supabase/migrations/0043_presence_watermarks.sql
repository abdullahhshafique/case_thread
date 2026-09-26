-- 0043: presence — approved co-members may read each other's
-- room_last_seen watermark (Phase 7 presence dots / "active Xm ago").
-- Writes stay own-watermark only; nothing here loosens writes.
drop policy if exists "own watermark readable" on public.room_last_seen;
create policy "room member watermarks readable"
  on public.room_last_seen for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.room_members m
      where m.room_id = room_last_seen.room_id
        and m.user_id = auth.uid()
        and m.status = 'approved'
    )
  );
