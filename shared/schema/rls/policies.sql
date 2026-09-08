-- Row level security.
--
-- RLS is what actually protects the data. The Supabase publishable key ships in
-- every binary and is not a secret; these policies are the only thing standing
-- between one account and another.
--
-- VERIFY THESE BY DIRECT API CALL, NOT THROUGH THE APP. An empty database
-- returns [] whether RLS is enforcing or absent, so an empty anonymous read
-- proves nothing at all. Insert a row as user A, then read it anonymously and
-- as user B, with curl and the publishable key, against the live project.

begin;

alter table custom_catalog_entries enable row level security;
alter table bottles               enable row level security;
alter table pours                 enable row level security;
alter table tastings              enable row level security;
alter table tasting_notes         enable row level security;
alter table wishlist_items        enable row level security;
alter table knowledge_notes       enable row level security;
alter table subscriptions         enable row level security;

-- Owner-only, for everything the client writes.
--
-- USING governs which existing rows are visible to select/update/delete;
-- WITH CHECK governs which new or changed rows may be written. Both are
-- required: USING alone would let a user rewrite a row's user_id and hand it to
-- somebody else.
do $$
declare t text;
begin
  foreach t in array array[
    'custom_catalog_entries', 'bottles', 'pours', 'tastings',
    'tasting_notes', 'wishlist_items', 'knowledge_notes'
  ]
  loop
    execute format(
      'create policy %I_owner_select on %I for select using (auth.uid() = user_id)', t, t);
    execute format(
      'create policy %I_owner_insert on %I for insert with check (auth.uid() = user_id)', t, t);
    execute format(
      'create policy %I_owner_update on %I for update using (auth.uid() = user_id) '
      || 'with check (auth.uid() = user_id)', t, t);
    -- No delete policy anywhere, deliberately. Deletes are soft: an update
    -- setting deleted_at, which travels through the same path as any other
    -- change. A hard delete breaks sync and destroys the history the product
    -- is sold on.
  end loop;
end $$;

-- Server-owned. Pulled, never pushed: no insert or update policy exists, so a
-- client attempting either is refused by RLS rather than by client-side code.
create policy subscriptions_owner_select on subscriptions
  for select using (auth.uid() = user_id);

commit;
