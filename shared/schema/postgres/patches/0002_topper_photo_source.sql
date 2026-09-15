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

-- 0003, 15 September 2026: the wax on a Maker's Mark.
alter table bottles add column if not exists wax_color      text;
alter table bottles add column if not exists drip_fraction  double precision;
alter table bottles add column if not exists drip_length_mm double precision;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'drip_is_a_fraction') then
    alter table bottles add constraint drip_is_a_fraction
      check (drip_fraction is null or (drip_fraction >= 0 and drip_fraction <= 1));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'wax_color_is_known') then
    alter table bottles add constraint wax_color_is_known
      check (wax_color is null or wax_color in ('red', 'black', 'gold', 'green', 'purple', 'blue', 'white', 'other'));
  end if;
end $$;

-- 0004, 15 September 2026: the Private Select stave recipe.
alter table bottles add column if not exists stave_recipe text;

-- 0005, 15 September 2026: the DSP permit number on the label.
alter table bottles add column if not exists dsp text;

-- 0006, 15 September 2026: samples, and who a pour was for.
alter table bottles add column if not exists is_sample     boolean not null default false;
alter table bottles add column if not exists sample_from   text;
alter table bottles add column if not exists sample_source text;
alter table pours   add column if not exists given_to      text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'sample_source_is_known') then
    alter table bottles add constraint sample_source_is_known
      check (sample_source is null or sample_source in ('gift', 'swap', 'bought', 'decant'));
  end if;
end $$;
