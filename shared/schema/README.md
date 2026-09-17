# Applying the schema to the Supabase project

Everything the app needs on the server, in the order to run it. Every file
is re-runnable, and CI applies the same sequence to a fresh Postgres on
every push.

## A new project

1. `postgres/0001_init.sql` — every table, trigger, index and view.
2. `rls/policies.sql` — row-level security, owner-only.

## A project that already has 0001 applied

Run the patches in order, then the policies again (they cover the new
tables):

1. `postgres/patches/0002_topper_photo_source.sql` — sections 0002–0007
   (topper letter, photo, tasting source, wax, staves, DSP, samples,
   infinity bottles). Skip any section already applied; each is guarded.
2. `postgres/patches/0008_community.sql` — price and drip reports, hosted
   menus, the two community views.
3. `postgres/patches/0009_households.sql` — sharing a shelf with a partner:
   households, invite codes, the functions the app calls.
4. `postgres/patches/0010_weight_and_blind.sql` — a tare weight per bottle,
   a blind flag per tasting.
5. `postgres/patches/0011_sightings.sql` — the hunt log: sightings and
   lottery entries, and the household touch told about the table.
6. `postgres/patches/0012_visits.sql` — the passport: distillery visits.
7. `postgres/patches/0013_delete_account.sql` — the function behind
   "Delete my account" (App Store guideline 5.1.1(v)).
8. `rls/policies.sql` — now "yours, or a household member's" on every
   data table, the hunt log and the passport included.

Paste each file whole into the SQL editor (Database → SQL) and run it.

## Proving an account's data is actually saved

CI applies this schema to a bare Postgres with no auth and no RLS, so the
one thing it cannot answer is whether a signed-in person's rows land, come
back, stay theirs and survive an edit. `scripts/verify_sync.py` asks the
live project directly, over the same REST calls the app makes:

    python scripts/verify_sync.py --host <ref>.supabase.co         --key sb_publishable_...         --a a@yours.com:password --b b@yours.com:password

Make the two users first in Authentication -> Users -> Add user, with
**Auto Confirm User** ticked (otherwise they cannot sign in until they
click a link). The script writes and removes its own rows, uses no
service-role key, and is bound by exactly the policies the app is bound
by. Run it after any schema change.

## The menu page

The hosted menu is served by an Edge Function. From the repo root, with
the Supabase CLI signed in and linked to the project:

    supabase functions deploy menu --no-verify-jwt

The app builds the link as `https://<host>/functions/v1/menu/<slug>`.

## The app

`IOS/Secrets.xcconfig` (gitignored) carries `SUPABASE_HOST` (host only, no
scheme) and `SUPABASE_ANON_KEY`. Without it the app runs fully offline and
every server feature stays hidden.
