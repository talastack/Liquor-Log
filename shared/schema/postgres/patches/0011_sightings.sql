-- Patch 0011, 16 September 2026: the hunt log.
-- Re-runnable. Apply after 0010; then re-run shared/schema/rls/policies.sql,
-- which enables row level security on the new table and gives it the same
-- "yours, or a household member's" policies as everything else.

-- ---------------------------------------------------------------------------
-- sightings
-- ---------------------------------------------------------------------------
--
-- The hunt log: a bottle seen on a shelf (where, at what, how many), or a
-- lottery entered and how it came out. The half of collecting that happens
-- before a bottle is bought, kept so the stores that actually get the good
-- stuff, and your own lottery luck, can be read back from a record instead
-- of guessed. A sighting names a catalogue product or a typed name.

create table if not exists sightings (
  id                  text primary key,
  user_id             uuid not null references auth.users (id) on delete cascade,
  catalog_product_id  text,
  custom_name         text,
  -- 'seen' on a shelf, or 'entered' in a lottery or raffle.
  kind                text not null default 'seen',
  -- For an entry: 'won' or 'lost' once known; null while pending.
  outcome             text,
  -- The shop, or the board that runs the lottery ("Virginia ABC").
  store               text not null,
  region              text,
  cents               integer,
  -- How many were on the shelf. Zero is a sighting too: sold out.
  count               integer,
  -- Set once the bottle was bought and is on the shelf.
  bottle_id           text,
  note                text,
  seen_at             bigint not null,
  created_at          bigint not null,
  updated_at          bigint not null,
  deleted_at          bigint,
  server_updated_at   bigint not null default 0,

  constraint sighting_names_something check (catalog_product_id is not null or custom_name is not null),
  constraint sighting_kind_is_known check (kind in ('seen', 'entered')),
  constraint sighting_outcome_is_known check (outcome is null or outcome in ('won', 'lost')),
  constraint sighting_price_is_positive check (cents is null or cents > 0),
  constraint sighting_count_is_a_count check (count is null or count >= 0)
);

do $$
begin
  drop trigger if exists a_sightings_reject_stale on sightings;
  create trigger a_sightings_reject_stale before update on sightings
    for each row execute function reject_stale_writes();
  drop trigger if exists sightings_server_clock on sightings;
  create trigger sightings_server_clock before insert or update on sightings
    for each row execute function set_server_updated_at();
end $$;

create index if not exists sightings_pull on sightings (user_id, server_updated_at);
create index if not exists sightings_by_product on sightings (user_id, catalog_product_id, seen_at);

-- The household touch (patch 0009) has to know the table, or a partner's
-- sightings would not be re-pulled when a household forms.
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
    'wishlist_items', 'knowledge_notes', 'sightings'
  ] loop
    execute format(
      'update %I set server_updated_at = (extract(epoch from clock_timestamp()) * 1000)::bigint '
      || 'where user_id = any($1)', t) using members;
  end loop;
end $$;
