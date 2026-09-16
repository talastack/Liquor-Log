-- Patch 0009, 16 September 2026: sharing a collection with a partner.
-- For a project with 0001 and patches 0002-0008 applied. Re-runnable. Run
-- shared/schema/rls/policies.sql after it: the owner-only rule on every
-- data table becomes "yours, or a household member's".
--
-- A household is two or more accounts that see one shelf. One row per
-- household, one per membership; an invite code is how the second person
-- gets in. Membership changes are made through the two functions below,
-- which run as the definer so a member can add themselves without a
-- policy that lets anyone add anyone.

-- ---------------------------------------------------------------------------
-- households, household_members
-- ---------------------------------------------------------------------------

create table if not exists households (
  id           text primary key,
  name         text not null,
  created_by   uuid not null references auth.users (id) on delete cascade,
  invite_code  text not null unique,
  created_at   bigint not null,

  constraint invite_code_shape check (invite_code ~ '^[A-Z2-9]{6}$')
);

create table if not exists household_members (
  household_id text not null references households (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  joined_at    bigint not null,
  primary key (household_id, user_id)
);

create index if not exists household_members_by_user on household_members (user_id);

-- ---------------------------------------------------------------------------
-- Who shares a shelf with me
-- ---------------------------------------------------------------------------
--
-- Security definer so it can read household_members whatever the policies
-- on that table say; stable so a policy can call it per row cheaply.

-- plpgsql rather than sql: a sql function's body is checked when it is
-- created, and auth.uid() does not exist yet when CI applies this file to
-- a bare Postgres.
create or replace function household_user_ids()
returns setof uuid
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
    select m2.user_id
    from household_members m1
    join household_members m2 on m2.household_id = m1.household_id
    where m1.user_id = auth.uid();
end $$;

-- ---------------------------------------------------------------------------
-- Creating, joining, leaving
-- ---------------------------------------------------------------------------
--
-- Every data table's server clock is bumped for everyone involved when a
-- membership changes, so each phone's next pull -- "rows newer than my
-- cursor" -- brings the other person's shelf across. The clock is not the
-- last-write-wins key (updated_at is), so touching it changes nothing about
-- which edit wins.

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
    'wishlist_items', 'knowledge_notes'
  ] loop
    execute format(
      'update %I set server_updated_at = (extract(epoch from clock_timestamp()) * 1000)::bigint '
      || 'where user_id = any($1)', t) using members;
  end loop;
end $$;

create or replace function create_household(household_name text)
returns table (id text, name text, invite_code text, members integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id text := gen_random_uuid()::text;
  code text;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  if exists (select 1 from household_members where user_id = auth.uid()) then
    raise exception 'already in a household';
  end if;
  -- Six characters from an alphabet with no 0/O or 1/I to misread.
  code := (
    select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', (floor(random() * 32) + 1)::int, 1), '')
    from generate_series(1, 6));
  insert into households (id, name, created_by, invite_code, created_at)
    values (new_id, coalesce(nullif(trim(household_name), ''), 'Our shelf'), auth.uid(), code,
            (extract(epoch from clock_timestamp()) * 1000)::bigint);
  insert into household_members (household_id, user_id, joined_at)
    values (new_id, auth.uid(), (extract(epoch from clock_timestamp()) * 1000)::bigint);
  return query select h.id, h.name, h.invite_code, 1 from households h where h.id = new_id;
end $$;

create or replace function join_household(code text)
returns table (id text, name text, invite_code text, members integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  target households%rowtype;
  all_members uuid[];
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  if exists (select 1 from household_members where user_id = auth.uid()) then
    raise exception 'already in a household';
  end if;
  select * into target from households h where h.invite_code = upper(trim(code));
  if not found then
    raise exception 'no household with that code';
  end if;
  insert into household_members (household_id, user_id, joined_at)
    values (target.id, auth.uid(), (extract(epoch from clock_timestamp()) * 1000)::bigint);
  select array_agg(m.user_id) into all_members from household_members m where m.household_id = target.id;
  perform touch_household_rows(all_members);
  return query
    select h.id, h.name, h.invite_code,
           (select count(*) from household_members m where m.household_id = h.id)::integer
    from households h where h.id = target.id;
end $$;

create or replace function leave_household()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  mine text;
begin
  select household_id into mine from household_members where user_id = auth.uid();
  if mine is null then
    return;
  end if;
  delete from household_members where household_id = mine and user_id = auth.uid();
  -- An empty household is gone; a household of one keeps its code.
  delete from households where id = mine
    and not exists (select 1 from household_members where household_id = mine);
end $$;

create or replace function my_household()
returns table (id text, name text, invite_code text, members integer)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
    select h.id, h.name, h.invite_code,
           (select count(*) from household_members m where m.household_id = h.id)::integer
    from households h
    join household_members me on me.household_id = h.id
    where me.user_id = auth.uid();
end $$;

-- The client calls these through PostgREST; anon may not.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function create_household(text) to authenticated;
    grant execute on function join_household(text) to authenticated;
    grant execute on function leave_household() to authenticated;
    grant execute on function my_household() to authenticated;
    grant execute on function household_user_ids() to authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke execute on function create_household(text) from anon;
    revoke execute on function join_household(text) from anon;
    revoke execute on function leave_household() from anon;
    revoke execute on function my_household() from anon;
  end if;
end $$;

-- Row-level security for these two tables is in shared/schema/rls/policies.sql
-- with everything else's: a policy is checked as it is created, and auth.uid()
-- is not there yet when CI applies this file to a bare Postgres.
