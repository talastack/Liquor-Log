-- Patch 0012, 16 September 2026: the passport.
-- Re-runnable. Apply after 0011; then re-run shared/schema/rls/policies.sql.

-- ---------------------------------------------------------------------------
-- visits
-- ---------------------------------------------------------------------------
--
-- The passport: a distillery stood in, on a date, with a note. Read back
-- as stamps against the shelf -- which bottles came from a place you have
-- been, which distilleries on the shelf you have not been to.

create table if not exists visits (
  id                  text primary key,
  user_id             uuid not null references auth.users (id) on delete cascade,
  distillery          text not null,
  visited_at          bigint not null,
  note                text,
  created_at          bigint not null,
  updated_at          bigint not null,
  deleted_at          bigint,
  server_updated_at   bigint not null default 0,

  constraint visit_names_a_place check (char_length(distillery) > 0)
);

do $$
begin
  drop trigger if exists a_visits_reject_stale on visits;
  create trigger a_visits_reject_stale before update on visits
    for each row execute function reject_stale_writes();
  drop trigger if exists visits_server_clock on visits;
  create trigger visits_server_clock before insert or update on visits
    for each row execute function set_server_updated_at();
end $$;

create index if not exists visits_pull on visits (user_id, server_updated_at);

-- The household touch (patch 0009) has to know the table.
create or replace function touch_household_rows(members uuid[])
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  t text;
begin
  foreach t in array array[
    'custom_catalog_entries', 'bottles', 'pours', 'fill_readings', 'blend_additions',
    'price_reports', 'drip_reports', 'menus', 'tastings', 'tasting_notes',
    'wishlist_items', 'knowledge_notes', 'sightings', 'visits'
  ] loop
    execute format(
      'update %I set server_updated_at = (extract(epoch from clock_timestamp()) * 1000)::bigint '
      || 'where user_id = any($1)', t) using members;
  end loop;
end $$;
