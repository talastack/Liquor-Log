-- Patch 0014, 21 September 2026: the k-anonymity threshold moves into the
-- views, where it cannot be bypassed.
-- Re-runnable. Apply after 0013.
--
-- The app has always refused to show a community figure until enough people
-- have reported it -- three for a price, four for a drip. That rule lived in
-- Swift (`CommunityPrice.minimumReports`, `WaxDrip.Standing.minimumReports`)
-- and the views returned every group, single-report ones included.
--
-- The publishable key ships in every binary, on purpose, because RLS is what
-- protects the data. So anyone could skip the app and ask the view directly:
--
--     GET /rest/v1/community_prices?reports=eq.1
--
-- and read one person's exact price, their region and the day they saw it.
-- No user id, but a single report is exactly what the threshold exists to
-- prevent. A rule enforced only in the client is not enforced.
--
-- ON security_invoker: these views stay SECURITY DEFINER (the default,
-- written explicitly below). Supabase's linter flags that as critical, and
-- for these two views it is wrong. `price_reports` and `drip_reports` carry
-- owner-only RLS; an invoker-rights view would aggregate nothing but the
-- caller's own reports, which is not a community figure at all. The
-- protection here is that the view exposes counts and percentiles and never
-- a user id -- plus, from this patch on, never a group small enough to be
-- one person. Do not "fix" the warning by flipping this.

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
  group by grouping sets ((catalog_product_id, region), (catalog_product_id))
  -- Three, matching CommunityPrice.minimumReports. Applies to the regional
  -- groups and to the national rollup alike: a product only one person has
  -- ever reported must not appear even with the region rolled away.
  having count(*) >= 3;

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
  group by catalog_product_id
  -- Four, matching WaxDrip.Standing.minimumReports. A quartile drawn from
  -- three measurements is not a quartile.
  having count(*) >= 4;
