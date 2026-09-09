-- Liquor-Log initial schema.
--
-- THIS FILE AND ITS SWIFT MIRROR ARE A PAIRED EDIT.
-- IOS/Packages/LiquorData/Sources/LiquorData/Schema/Migrations.swift must match
-- this column for column. Nothing at runtime notices when they drift: a column
-- present in one and absent from the other syncs into a void with no error.
-- scripts/check_schema_mirror.py catches it, and CI runs it.
--
-- TIMESTAMPS ARE UNIX MILLISECONDS AS BIGINT, never ISO strings and never
-- timestamptz. Two reasons: an integer compares and orders identically on every
-- client without a parser in the path, and last-write-wins needs a total order
-- that cannot be perturbed by a timezone or a DST boundary.
--
-- Every synced table carries exactly two clocks:
--
--   updated_at         written by the DEVICE at the moment of the edit. This is
--                      the last-write-wins key. It has to be the device's:
--                      resolving conflicts by arrival time would make whichever
--                      device syncs last win regardless of when the user
--                      actually made the change.
--
--   server_updated_at  written by the SERVER on every insert and update, never
--                      by a client. The pull filters and orders on THIS one.
--
-- Filtering one by the other loses rows permanently and silently. See
-- shared/contracts/sync.md for the worked example.
--
-- `dirty` is deliberately absent. It is a local-only push queue on the client
-- and never crosses the wire.

begin;

-- Supabase already provides auth.users, and does NOT grant the SQL editor
-- rights inside the auth schema -- that schema is owned by supabase_auth_admin.
-- Creating it unconditionally fails with "permission denied for schema auth".
--
-- CI applies this file to a bare Postgres where auth.users does not exist, so
-- the stub still has to happen there. Hence the guard: create it only when it
-- is genuinely missing, and never touch it when Supabase owns it.
--
-- EXECUTE rather than plain DDL so the statements are not even parsed on a
-- database where the branch is skipped.
do $$
begin
  if to_regclass('auth.users') is null then
    execute 'create schema if not exists auth';
    execute 'create table auth.users (id uuid primary key)';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Server clock
-- ---------------------------------------------------------------------------

-- Stamps server_updated_at on every write. A client that sets this column is
-- ignored: the trigger overwrites it unconditionally.
create or replace function set_server_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.server_updated_at := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  return new;
end;
$$;

-- Drops an update whose updated_at is OLDER than the row already stored.
--
-- Last-write-wins has to be enforced somewhere, and it cannot be the client:
-- two devices can push concurrently, so neither is in a position to arbitrate.
--
-- The push still returns 2xx. From the pusher's point of view the write was
-- accepted and then superseded, which is exactly what happened, and its next
-- pull brings back the winning version.
--
-- Equal timestamps fall through to the write. Two edits in the same millisecond
-- are a coin toss whichever way it is resolved, and letting the arriving row
-- win keeps the rule to one comparison.
create or replace function reject_stale_writes()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and new.updated_at < old.updated_at then
    return null;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Closed vocabularies
-- ---------------------------------------------------------------------------
--
-- Free text here is how "Kentucky Straight Bourbon" and "KY straight bourbon"
-- become two products. These strings are the raw values of the Swift enums in
-- LiquorEngine/Classification.swift; check_schema_mirror.py asserts the two
-- lists agree.

create domain class_type as text
  check (value in (
    'bourbon', 'straightBourbon', 'kentuckyStraightBourbon', 'blendOfStraightBourbon',
    'rye', 'straightRye', 'wheatWhiskey', 'straightWheatWhiskey',
    'cornWhiskey', 'straightCornWhiskey', 'tennesseeWhiskey', 'americanSingleMalt',
    'lightWhiskey', 'blendedWhiskey', 'singleMaltScotch', 'blendedMaltScotch',
    'singleGrainScotch', 'blendedScotch', 'irishWhiskey', 'singlePotStillIrish',
    'singleMaltIrish', 'canadianWhisky', 'japaneseWhisky', 'tequilaBlanco',
    'tequilaReposado', 'tequilaAnejo', 'tequilaExtraAnejo', 'mezcal',
    'rum', 'rhumAgricole', 'londonDryGin', 'distilledGin',
    'genever', 'vodka', 'aquavit', 'cognac',
    'armagnac', 'calvados', 'brandy', 'pisco',
    'liqueur', 'amaro', 'vermouth', 'absinthe',
    'maltBeverage'
  ));

create domain production_type as text
  check (value in ('singleBarrel', 'smallBatch', 'blend', 'singleCask', 'unspecified'));

create domain category as text
  check (value in ('spirit', 'beer'));

create domain tasting_stage as text
  check (value in ('nose', 'entry', 'mid', 'finish'));

-- ---------------------------------------------------------------------------
-- custom_catalog_entries
-- ---------------------------------------------------------------------------
--
-- The user's own additions to the catalog. The BUNDLED catalog is not a table
-- at all: it ships as shared/data/spirits.v1.json and is loaded read-only on
-- the device. So bottles.catalog_product_id has no foreign key -- it resolves
-- against the bundled catalog first and these rows second.

create table custom_catalog_entries (
  id                  text primary key,
  user_id             uuid not null references auth.users (id) on delete cascade,
  distillery          text not null,
  brand               text not null,
  expression          text not null default '',
  class_type          class_type not null,
  production_type     production_type not null default 'unspecified',
  is_barrel_proof     boolean not null default false,
  is_bottled_in_bond  boolean not null default false,
  abv                 double precision,
  stated_age_years    integer,
  recipe_code         text,

  -- A published SHELF price, not a market value: a state control board's
  -- posted price, or a producer's stated SRP. Every one names its source,
  -- because a price with no provenance is a number nobody can check.
  -- NULL is the honest value for anything with no published figure.
  msrp_cents          integer,
  msrp_source         text,
  msrp_as_of_year     integer,

  created_at          bigint not null,
  updated_at          bigint not null,
  deleted_at          bigint,
  server_updated_at   bigint not null default 0,

  -- Bonded whiskey is exactly 100 proof by definition, and at least four years
  -- old. Enforced here as well as in the engine because a bad row can arrive
  -- from any client, including an old build.
  constraint bond_is_fifty_percent
    check (not is_bottled_in_bond or abv is null or abv = 50.0),
  constraint bond_is_four_years
    check (not is_bottled_in_bond or stated_age_years is null or stated_age_years >= 4),
  constraint abv_is_plausible
    check (abv is null or (abv > 0.5 and abv <= 95.0)),
  constraint msrp_is_not_negative
    check (msrp_cents is null or msrp_cents >= 0),
  -- A figure with no source cannot be shown to the user, so it may not be
  -- stored either.
  constraint msrp_cites_a_source
    check (msrp_cents is null or msrp_source is not null)
);

-- ---------------------------------------------------------------------------
-- bottles
-- ---------------------------------------------------------------------------
--
-- The physical bottle. Product-level facts live on the catalog entry; the
-- RELEASE -- batch, pick, barrel, measured proof, vintage -- lives here,
-- because you only ever meet a release through a bottle.

create table bottles (
  id                  text primary key,
  user_id             uuid not null references auth.users (id) on delete cascade,
  catalog_product_id  text,
  category            category not null default 'spirit',

  -- Free-text fallback for a bottle matched to nothing at all.
  custom_name         text,

  is_store_pick       boolean not null default false,
  pick_store          text,
  pick_name           text,
  barrel_number       text,
  batch_number        text,

  -- WHAT A STORE PICK ACTUALLY PRINTS, and what most apps drop on the floor.
  -- A Four Roses pick states its recipe, warehouse and age to the month; a
  -- Willett states barrel and bottle count; a Buffalo Trace pick states the
  -- warehouse and floor. None of this is product-level: the next barrel out of
  -- the same programme is a different whiskey.
  --
  -- pick_group is who SELECTED it, which is often not who sells it -- a club,
  -- a bar or a society picks the barrel and a shop puts it on the shelf.
  pick_group          text,
  -- Blanton's prints "Warehouse H / Rick #41 / Barrel 421" and collectors chase
  -- specific warehouses and floors, so these are three fields rather than one
  -- string somebody has to parse back out later.
  warehouse           text,
  rick                text,
  floor               text,
  -- Bottle-level recipe code. For a Four Roses pick the code is on THIS label
  -- and differs barrel to barrel, so it overrides the product's standard one.
  recipe_code         text,
  -- Age at bottling in months, because a single barrel is 9 years 4 months and
  -- rounding that to 9 throws away the thing the pick was chosen for.
  age_months          integer,
  entry_proof         double precision,
  char_level          integer,
  -- Secondary cask, where there is one: port, sherry, toasted oak.
  finish              text,
  bottle_number       integer,
  bottles_in_batch    integer,
  -- Dump date. More precise than a bottling year and often the only date on
  -- the label.
  dumped_at           bigint,

  -- MEASURED strength of this bottle, which for a barrel-proof release differs
  -- from the catalog's standard figure batch to batch.
  abv                 double precision,

  -- Chill filtration. Null means the label does not say, which is the common
  -- case: only producers who skip it tend to advertise it.
  chill_filtered      boolean,

  distilled_year      integer,
  bottled_year        integer,
  vintage_year        integer,

  volume_ml           double precision not null,
  -- User-configurable. 44.36 ml (1.5 US fl oz) is the default, not a constant.
  pour_size_ml        double precision not null default 44.36029434375,

  purchase_date       bigint,
  purchase_price_cents integer,
  purchase_store      text,

  -- The price ON THE SHELF, which is not always what you paid: a sale, a club
  -- discount and a bundle all make the two differ.
  --
  -- This is the app's price reference, and it belongs to the USER. Third-party
  -- price data is a licensing question in every direction -- state boards
  -- assert rights, retailers have terms, and resale figures have no free and
  -- stable source at all. What somebody wrote down about a shelf they stood in
  -- front of has none of those problems, never goes stale in a way that
  -- misleads them, and gets better the more they use the app.
  shelf_price_cents   integer,

  -- The barcode on THIS bottle, when somebody has scanned it.
  --
  -- A shortcut, never an identity. The whole argument of this product is that
  -- a UPC identifies a SKU and cannot identify a barrel: a store pick usually
  -- carries the base product's barcode, sometimes a generic "barrel select"
  -- one, and sometimes a sticker over the original. Scanning is therefore
  -- allowed to answer "you have this LINE" and never "you own this barrel" --
  -- which is a verdict ShelfCheck already distinguishes.
  --
  -- There is no UPC database behind this and there is not meant to be. Those
  -- are paid or scraped, both excluded. This column is the user's OWN lookup
  -- table: scan a bottle once, say what it is, and it is recognised forever
  -- after. It works offline and improves with use.
  barcode             text,

  -- Where the bottle physically IS. Collections scatter across closets,
  -- basements and boxes, and people report this mattering more than remembering
  -- what they own.
  storage_location    text,

  -- The user's OWN number, keyed to a sticker on the actual glass. Distinct
  -- from bottle_number, which is the "47 of 240" the pick was bottled with.
  -- It is what bridges a shelf to a database.
  shelf_number        integer,

  opened_at           bigint,
  finished_at         bigint,

  -- Last time a human laid eyes on this bottle during a shelf walk. Every
  -- long-running collection decays -- people buy, drink and trade faster than
  -- they log -- and the coping mechanism they arrive at independently is a
  -- periodic re-inventory. This column is what orders that walk.
  last_verified_at    bigint,

  created_at          bigint not null,
  updated_at          bigint not null,
  deleted_at          bigint,
  server_updated_at   bigint not null default 0,

  constraint volume_is_positive check (volume_ml > 0),
  constraint pour_size_is_positive check (pour_size_ml > 0),
  constraint abv_is_plausible check (abv is null or (abv > 0.5 and abv <= 95.0)),
  constraint price_is_not_negative
    check (purchase_price_cents is null or purchase_price_cents >= 0),
  constraint shelf_price_is_not_negative
    check (shelf_price_cents is null or shelf_price_cents >= 0),
  constraint age_months_is_positive
    check (age_months is null or age_months > 0),
  -- Char levels run #1 to #4 in practice; the range is wider than that so an
  -- unusual cooperage spec is recorded rather than rejected.
  constraint char_level_is_a_char_level
    check (char_level is null or char_level between 1 and 7),
  constraint entry_proof_is_plausible
    check (entry_proof is null or (entry_proof > 1 and entry_proof <= 190)),
  constraint bottle_number_is_positive
    check (bottle_number is null or bottle_number > 0),
  constraint shelf_number_is_positive
    check (shelf_number is null or shelf_number > 0),
  constraint batch_size_is_positive
    check (bottles_in_batch is null or bottles_in_batch > 0),
  constraint bottle_number_fits_the_batch
    check (bottle_number is null or bottles_in_batch is null
           or bottle_number <= bottles_in_batch),
  -- A bottle has to be identified by something.
  constraint has_an_identity
    check (catalog_product_id is not null or custom_name is not null)
);

-- ---------------------------------------------------------------------------
-- pours
-- ---------------------------------------------------------------------------
--
-- The pour log is the source of truth for what is left. remaining_ml is DERIVED
-- from these rows and is deliberately not a column: a mutable counter beside an
-- event log is a second source of truth that will disagree with the first.

create table pours (
  id                 text primary key,
  user_id            uuid not null references auth.users (id) on delete cascade,
  bottle_id          text not null references bottles (id) on delete cascade,
  poured_at          bigint not null,
  volume_ml          double precision not null,
  note               text,
  created_at         bigint not null,
  updated_at         bigint not null,
  deleted_at         bigint,
  server_updated_at  bigint not null default 0,

  constraint pour_is_positive check (volume_ml > 0)
);

-- ---------------------------------------------------------------------------
-- fill_readings
-- ---------------------------------------------------------------------------
--
-- "There is this much left in the bottle, and I am looking at it right now."
--
-- The pour log alone cannot answer that. It assumes every bottle started full
-- and that every pour since was logged, and both are routinely false: people
-- add bottles they opened years ago, and pour for guests without reaching for
-- a phone. An app that can only say "750 ml minus what you told me" is wrong
-- about most real shelves, and it is wrong in the direction that makes the
-- oxidation estimate and the cost-per-pour figure quietly useless.
--
-- So a reading is an OBSERVATION at a moment, and the fill is derived as:
--
--     remaining = latest reading  -  pours logged after that reading
--
-- with the bottle's capacity standing in when there has never been a reading.
-- That keeps the pour log as the record of what you drank while letting a
-- human overrule it, and it means correcting a bottle never rewrites history:
-- the pours you logged stay logged.
--
-- Readings accumulate rather than replace each other. Two readings a year
-- apart on the same bottle are a real record of how fast it went down.

create table fill_readings (
  id                 text primary key,
  user_id            uuid not null references auth.users (id) on delete cascade,
  bottle_id          text not null references bottles (id) on delete cascade,

  -- When the level was OBSERVED, which is not necessarily when it was typed
  -- in. Ordering is on this column, so a reading backdated to the day a bottle
  -- was opened behaves correctly against pours logged since.
  read_at            bigint not null,

  -- Millilitres, always. A percentage is what the user may type, but a
  -- percentage stored against a bottle whose size is later corrected would
  -- silently change how much whiskey the app thinks is in it.
  remaining_ml       double precision not null,

  -- How the figure was arrived at, for the user's own benefit: eyeballed
  -- against the label, weighed, measured.
  note               text,

  created_at         bigint not null,
  updated_at         bigint not null,
  deleted_at         bigint,
  server_updated_at  bigint not null default 0,

  constraint reading_is_not_negative check (remaining_ml >= 0)
  -- Deliberately NOT constrained against the bottle's capacity. A cross-table
  -- check cannot be expressed here, and a bottle filled slightly over its
  -- stated size is a real thing. The engine clamps on read instead.
);

-- ---------------------------------------------------------------------------
-- tastings
-- ---------------------------------------------------------------------------
--
-- A tasting hangs off a BOTTLE or a PRODUCT, not only a bottle. Without that,
-- there is no way to record something you drank at a bar and never owned --
-- and the shelf check has a verdict for exactly that case.

create table tastings (
  id                  text primary key,
  user_id             uuid not null references auth.users (id) on delete cascade,
  bottle_id           text references bottles (id) on delete cascade,
  catalog_product_id  text,

  -- The specific pour this tasting is of, when there was one.
  --
  -- This is what makes the oxidation clock checkable instead of merely
  -- asserted: three tastings of one bottle, each tied to a pour on a known
  -- date, is a record of how that bottle actually changed after opening.
  -- Nullable, because plenty of tastings happen at a bar with no bottle of
  -- your own behind them.
  --
  -- ON DELETE SET NULL, not cascade: deleting a pour must never take the note
  -- with it. The opinion outlives the ounce and a tasting is far more
  -- expensive to re-create than a pour row.
  pour_id             text references pours (id) on delete set null,

  tasted_at           bigint not null,
  rating              integer,
  would_rebuy         text,
  worth_the_price     boolean,

  -- How hot it actually drank, 1-5.
  --
  -- The question behind "do I taste 62.6%": a barrel-proof bourbon that goes
  -- down easy is a different bottle from one that scorches at the same
  -- strength, and the label cannot tell you which you have. 1-5 because that
  -- is the resolution a person actually has; anything finer is invented
  -- precision.
  perceived_heat      integer,

  -- How long the finish lasted, in seconds. Recorded because length is the
  -- part of a finish people compare between bottles, and it is the one
  -- dimension free text is worst at holding still.
  finish_seconds      integer,

  liked               text,
  disliked            text,
  created_at          bigint not null,
  updated_at          bigint not null,
  deleted_at          bigint,
  server_updated_at   bigint not null default 0,

  constraint rating_is_one_to_ten check (rating is null or (rating between 1 and 10)),
  -- An hour is already absurd for a finish; the ceiling is there to catch a
  -- minutes-entered-as-seconds slip, not to judge anybody's palate.
  constraint perceived_heat_is_one_to_five
    check (perceived_heat is null or (perceived_heat between 1 and 5)),
  constraint finish_seconds_is_plausible
    check (finish_seconds is null or (finish_seconds > 0 and finish_seconds <= 3600)),
  constraint rebuy_is_known
    check (would_rebuy is null or would_rebuy in ('yes', 'maybe', 'no')),
  constraint tasting_has_a_subject
    check (bottle_id is not null or catalog_product_id is not null)
);

-- ---------------------------------------------------------------------------
-- tasting_notes
-- ---------------------------------------------------------------------------
--
-- Flavour-wheel picks, one row per descriptor per stage. Referenced last in the
-- push order because it depends on tastings.

create table tasting_notes (
  id                 text primary key,
  user_id            uuid not null references auth.users (id) on delete cascade,
  tasting_id         text not null references tastings (id) on delete cascade,
  stage              tasting_stage not null,
  descriptor_key     text not null,
  intensity          integer,
  created_at         bigint not null,
  updated_at         bigint not null,
  deleted_at         bigint,
  server_updated_at  bigint not null default 0,

  constraint intensity_is_one_to_five
    check (intensity is null or (intensity between 1 and 5))
);

-- ---------------------------------------------------------------------------
-- wishlist_items
-- ---------------------------------------------------------------------------
--
-- Its own table rather than a flag on bottles. A wanted bottle has no purchase
-- date, no open date, no pours and no fill level; a shared table would be
-- two-thirds nullable and every query would need a filter it will eventually
-- forget.

create table wishlist_items (
  id                  text primary key,
  user_id             uuid not null references auth.users (id) on delete cascade,
  catalog_product_id  text,
  custom_name         text,
  target_price_cents  integer,
  note                text,
  created_at          bigint not null,
  updated_at          bigint not null,
  deleted_at          bigint,
  server_updated_at   bigint not null default 0,

  constraint target_price_is_not_negative
    check (target_price_cents is null or target_price_cents >= 0),
  constraint has_an_identity
    check (catalog_product_id is not null or custom_name is not null)
);

-- ---------------------------------------------------------------------------
-- knowledge_notes
-- ---------------------------------------------------------------------------
--
-- The user-editable knowledge base. v2 uses these as the retrieval corpus, so
-- the table exists now to avoid a migration later.

create table knowledge_notes (
  id                 text primary key,
  user_id            uuid not null references auth.users (id) on delete cascade,
  title              text not null,
  body               text not null default '',
  subject_kind       text,
  subject_id         text,
  created_at         bigint not null,
  updated_at         bigint not null,
  deleted_at         bigint,
  server_updated_at  bigint not null default 0
);

-- ---------------------------------------------------------------------------
-- subscriptions
-- ---------------------------------------------------------------------------
--
-- Server-owned. Absent from the push order on purpose: its RLS policy is
-- SELECT-only, so it is pulled and never pushed.

create table subscriptions (
  id                 text primary key,
  user_id            uuid not null references auth.users (id) on delete cascade,
  tier               text not null default 'free',
  expires_at         bigint,
  created_at         bigint not null,
  updated_at         bigint not null,
  deleted_at         bigint,
  server_updated_at  bigint not null default 0,

  constraint tier_is_known check (tier in ('free', 'pro'))
);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

-- Named a_* so they fire BEFORE the server_clock triggers: Postgres runs
-- BEFORE triggers in name order, and a rejected write must not be stamped.
create trigger a_custom_catalog_entries_reject_stale
  before update on custom_catalog_entries
  for each row execute function reject_stale_writes();
create trigger a_bottles_reject_stale
  before update on bottles
  for each row execute function reject_stale_writes();
create trigger a_pours_reject_stale
  before update on pours
  for each row execute function reject_stale_writes();
create trigger a_fill_readings_reject_stale
  before update on fill_readings
  for each row execute function reject_stale_writes();
create trigger a_tastings_reject_stale
  before update on tastings
  for each row execute function reject_stale_writes();
create trigger a_tasting_notes_reject_stale
  before update on tasting_notes
  for each row execute function reject_stale_writes();
create trigger a_wishlist_items_reject_stale
  before update on wishlist_items
  for each row execute function reject_stale_writes();
create trigger a_knowledge_notes_reject_stale
  before update on knowledge_notes
  for each row execute function reject_stale_writes();

create trigger custom_catalog_entries_server_clock
  before insert or update on custom_catalog_entries
  for each row execute function set_server_updated_at();
create trigger bottles_server_clock
  before insert or update on bottles
  for each row execute function set_server_updated_at();
create trigger pours_server_clock
  before insert or update on pours
  for each row execute function set_server_updated_at();
create trigger fill_readings_server_clock
  before insert or update on fill_readings
  for each row execute function set_server_updated_at();
create trigger tastings_server_clock
  before insert or update on tastings
  for each row execute function set_server_updated_at();
create trigger tasting_notes_server_clock
  before insert or update on tasting_notes
  for each row execute function set_server_updated_at();
create trigger wishlist_items_server_clock
  before insert or update on wishlist_items
  for each row execute function set_server_updated_at();
create trigger knowledge_notes_server_clock
  before insert or update on knowledge_notes
  for each row execute function set_server_updated_at();
create trigger subscriptions_server_clock
  before insert or update on subscriptions
  for each row execute function set_server_updated_at();

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
--
-- Step 3 of the sync contract is "every row for this user newer than the
-- cursor", so every synced table is indexed for exactly that query.

create index custom_catalog_entries_pull on custom_catalog_entries (user_id, server_updated_at);
create index bottles_pull on bottles (user_id, server_updated_at);
create index pours_pull on pours (user_id, server_updated_at);
create index fill_readings_pull on fill_readings (user_id, server_updated_at);
create index tastings_pull on tastings (user_id, server_updated_at);
create index tasting_notes_pull on tasting_notes (user_id, server_updated_at);
create index wishlist_items_pull on wishlist_items (user_id, server_updated_at);
create index knowledge_notes_pull on knowledge_notes (user_id, server_updated_at);
create index subscriptions_pull on subscriptions (user_id, server_updated_at);

-- Reads the app actually makes.
create index pours_by_bottle on pours (bottle_id, poured_at);
-- Deriving a fill means finding the newest reading for a bottle and then the
-- pours after it, so both halves of that read are indexed.
create index fill_readings_by_bottle on fill_readings (bottle_id, read_at);
create index tastings_by_bottle on tastings (bottle_id, tasted_at);
create index tastings_by_product on tastings (catalog_product_id, tasted_at);
create index tasting_notes_by_tasting on tasting_notes (tasting_id);
create index bottles_by_product on bottles (user_id, catalog_product_id);

commit;
