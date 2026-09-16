-- Patch 0008, 16 September 2026, for a project with 0001 and patches
-- 0002-0007 applied: community price and drip reports, and hosted menus.
-- Re-runnable. Run shared/schema/rls/policies.sql after it.

-- ---------------------------------------------------------------------------
-- price_reports
-- ---------------------------------------------------------------------------
--
-- One person's sighting of a shelf price: what it cost, where, when. The only
-- price data the app can honestly own -- an observation is the observer's to
-- contribute, carries no licence and gets better with use. Never a valuation.
-- Pushed only when the person has switched sharing on; read back by everyone
-- through the community_prices view, which carries no user id.

create table if not exists price_reports (
  id                  text primary key,
  user_id             uuid not null references auth.users (id) on delete cascade,
  catalog_product_id  text not null,
  cents               integer not null,
  -- Coarse: a US state or a country code. Prices differ more between
  -- states than between shops, so a national figure is one nobody recognises.
  region              text,
  seen_at             bigint not null,
  created_at          bigint not null,
  updated_at          bigint not null,
  deleted_at          bigint,
  server_updated_at   bigint not null default 0,

  constraint price_report_is_positive check (cents > 0)
);

-- ---------------------------------------------------------------------------
-- drip_reports
-- ---------------------------------------------------------------------------
--
-- A wax drip measured from a photo, as a fraction of the bottle's height,
-- for the Maker's Mark question "is mine long". Read back as quartiles.

create table if not exists drip_reports (
  id                  text primary key,
  user_id             uuid not null references auth.users (id) on delete cascade,
  catalog_product_id  text not null,
  fraction            double precision not null,
  created_at          bigint not null,
  updated_at          bigint not null,
  deleted_at          bigint,
  server_updated_at   bigint not null default 0,

  constraint drip_report_is_a_fraction check (fraction >= 0 and fraction <= 1)
);

-- ---------------------------------------------------------------------------
-- menus
-- ---------------------------------------------------------------------------
--
-- A published "what's open": the menu as rendered text, under a slug that
-- the menu Edge Function serves as a page. Owner-only to write; the
-- function reads it with the service role, so no read policy is opened.

create table if not exists menus (
  id                  text primary key,
  user_id             uuid not null references auth.users (id) on delete cascade,
  slug                text not null unique,
  title               text not null,
  body                text not null,
  published_at        bigint not null,
  created_at          bigint not null,
  updated_at          bigint not null,
  deleted_at          bigint,
  server_updated_at   bigint not null default 0,

  constraint slug_is_short check (char_length(slug) between 6 and 64)
);

do $$
declare t text;
begin
  foreach t in array array['price_reports', 'drip_reports', 'menus'] loop
    execute format('drop trigger if exists a_%I_reject_stale on %I', t, t);
    execute format('create trigger a_%I_reject_stale before update on %I '
                   || 'for each row execute function reject_stale_writes()', t, t);
    execute format('drop trigger if exists %I_server_clock on %I', t, t);
    execute format('create trigger %I_server_clock before insert or update on %I '
                   || 'for each row execute function set_server_updated_at()', t, t);
    execute format('create index if not exists %I_pull on %I (user_id, server_updated_at)', t, t);
  end loop;
end $$;

create index if not exists price_reports_by_product on price_reports (catalog_product_id, region);
create index if not exists drip_reports_by_product on drip_reports (catalog_product_id);

-- ---------------------------------------------------------------------------
-- Community views
-- ---------------------------------------------------------------------------
--
-- Aggregates over everyone's reports, readable by anyone with the anon key.
-- They expose counts and medians and never a user id. Deleted reports are
-- left out; a report a person withdraws stops counting.

-- One row per product and region, plus one per product across every
-- region (is_all). Only sightings from the last 540 days count: a shelf
-- price three years old presented as current is worse than none.
create or replace view community_prices
with (security_invoker = false) as
  select
    catalog_product_id,
    case when grouping(region) = 1 then null else region end            as region,
    grouping(region) = 1                                                as is_all,
    count(*)::integer                                                   as reports,
    (percentile_cont(0.5) within group (order by cents))::integer       as median_cents,
    min(cents)                                                          as lowest_cents,
    max(cents)                                                          as highest_cents,
    min(seen_at)                                                        as oldest_seen_at,
    max(seen_at)                                                        as latest_seen_at
  from price_reports
  where deleted_at is null
    and seen_at > (extract(epoch from now()) * 1000)::bigint - 540::bigint * 86400000
  group by grouping sets ((catalog_product_id, region), (catalog_product_id));

create or replace view community_drips
with (security_invoker = false) as
  select
    catalog_product_id,
    count(*)::integer                                                   as reports,
    percentile_cont(0.25) within group (order by fraction)              as p25,
    percentile_cont(0.5)  within group (order by fraction)              as p50,
    percentile_cont(0.75) within group (order by fraction)              as p75
  from drip_reports
  where deleted_at is null
  group by catalog_product_id;

-- The Supabase roles; guarded so the file also applies to a plain Postgres
-- in CI, which has neither.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    grant select on community_prices to anon;
    grant select on community_drips  to anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant select on community_prices to authenticated;
    grant select on community_drips  to authenticated;
  end if;
end $$;

