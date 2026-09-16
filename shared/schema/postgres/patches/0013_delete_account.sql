-- Patch 0013, 16 September 2026: delete my account.
-- Re-runnable. Apply after 0012.
--
-- App Store guideline 5.1.1(v): an app that lets people create an account
-- must let them delete it, in the app. The client calls this once, signed
-- in; the auth row goes and every data row cascades with it (every table
-- references auth.users on delete cascade). A household left with no
-- members goes too. Nothing is kept server-side afterwards.

create or replace function delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = me;
  delete from households h
    where not exists (select 1 from household_members m where m.household_id = h.id);
end $$;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function delete_my_account() to authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke execute on function delete_my_account() from anon;
  end if;
end $$;
