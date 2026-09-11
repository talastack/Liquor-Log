-- Patch for a Supabase project that already has 0001_init.sql applied.
--
-- 0001_init.sql is edited in place while the app is pre-release, so a live
-- project needs the difference as ALTERs. Re-runnable: every statement is
-- guarded with IF NOT EXISTS.
--
-- Adds, from 11 September 2026:
--   bottles.topper_letter    the Blanton's cork letter
--   bottles.photo_file       file name of a device-local photo (bytes never sync)
--   tastings.source          where a tasting happened when not your own bottle
--   tastings.source_note     the venue or the friend

alter table bottles  add column if not exists topper_letter text;
alter table bottles  add column if not exists photo_file    text;
alter table tastings add column if not exists source        text;
alter table tastings add column if not exists source_note   text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'source_is_known'
  ) then
    alter table tastings add constraint source_is_known
      check (source is null or source in ('bar', 'friend', 'sample', 'store', 'event', 'other'));
  end if;
end $$;
