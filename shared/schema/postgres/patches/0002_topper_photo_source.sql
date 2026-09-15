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

-- 0007, 15 September 2026: infinity bottles.
alter table bottles add column if not exists is_infinity    boolean not null default false;
alter table pours   add column if not exists into_bottle_id text;

create table if not exists blend_additions (
  id                 text primary key,
  user_id            uuid not null references auth.users (id) on delete cascade,
  blend_bottle_id    text not null references bottles (id) on delete cascade,
  source_bottle_id   text,
  source_name        text,
  abv                double precision,
  volume_ml          double precision not null,
  pour_id            text,
  added_at           bigint not null,
  note               text,
  created_at         bigint not null,
  updated_at         bigint not null,
  deleted_at         bigint,
  server_updated_at  bigint not null default 0,
  constraint addition_is_positive check (volume_ml > 0),
  constraint addition_abv_is_plausible check (abv is null or (abv > 0.5 and abv <= 95.0)),
  constraint addition_has_a_source check (source_bottle_id is not null or source_name is not null)
);

drop trigger if exists a_blend_additions_reject_stale on blend_additions;
create trigger a_blend_additions_reject_stale
  before update on blend_additions
  for each row execute function reject_stale_writes();
drop trigger if exists blend_additions_server_clock on blend_additions;
create trigger blend_additions_server_clock
  before insert or update on blend_additions
  for each row execute function set_server_updated_at();

create index if not exists blend_additions_pull on blend_additions (user_id, server_updated_at);
create index if not exists blend_additions_by_blend on blend_additions (blend_bottle_id, added_at);

-- Then re-run shared/schema/rls/policies.sql, which now covers the table.
