-- Direct delete_own_account() calls skip Sign in with Apple revocation.
-- Not applied to production by this change.
--
-- 20260927160000 creates the zero-argument function and grants it to
-- authenticated. Editing that file would not run again if it were applied,
-- so this later migration replaces the function. anon and authenticated
-- lose EXECUTE. Only service_role, used by the delete-account Edge
-- Function, can call it.
--
-- The service role JWT has no user id. The function takes the user id that the
-- Edge Function already resolved from the caller's JWT via the Auth API.
-- auth.role() rejects every other role, so a client JWT cannot delete an
-- account even if EXECUTE is granted again by mistake.
-- Whether Apple revocation succeeded is not an argument here. The Edge
-- Function still calls this function when revocation fails.

begin;

drop function if exists public.delete_own_account();

create or replace function public.delete_own_account(p_user_id pg_catalog.uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid pg_catalog.uuid;
begin
  if auth.role() is distinct from 'service_role' or p_user_id is null then
    raise exception 'not authenticated';
  end if;
  uid := p_user_id;

  delete from public.meal_template_items where user_id = uid;
  delete from public.meal_templates where user_id = uid;

  if pg_catalog.to_regclass('public.workout_template_items') is not null then
    execute 'delete from public.workout_template_items where user_id = $1' using uid;
  end if;
  if pg_catalog.to_regclass('public.workout_templates') is not null then
    execute 'delete from public.workout_templates where user_id = $1' using uid;
  end if;

  delete from public.food_ratings where rater_user_id = uid;
  delete from public.food_reports where reporter_user_id = uid;
  delete from public.blocked_food_creators
    where blocker_user_id = uid or blocked_user_id = uid;

  delete from public.saved_foods
    where user_id = uid
      and visibility is distinct from 'public';

  update public.saved_foods
  set owner_deleted = true
  where user_id = uid
    and visibility = 'public';

  delete from public.food_entries where user_id = uid;
  delete from public.exercise_entries where user_id = uid;
  delete from public.weight_entries where user_id = uid;
  if pg_catalog.to_regclass('public.alcohol_entries') is not null then
    execute 'delete from public.alcohol_entries where user_id = $1' using uid;
  end if;

  delete from public.health_snapshots where user_id = uid;
  delete from public.app_settings where user_id = uid;
  delete from public.nutrition_settings where user_id = uid;
  delete from public.goals where user_id = uid;
  delete from public.profiles where user_id = uid;
  delete from public.rate_limit_buckets where user_id = uid;

  if pg_catalog.to_regclass('public.subscription_events') is not null then
    delete from public.subscription_events where user_id = uid;
  end if;

  update public.users
  set email = null,
      deleted_at = pg_catalog.timezone('utc', pg_catalog.now())
  where id = uid;

  -- Prevent the same Google/Apple identity from signing back into this row.
  -- Public foods stay attached to this anonymized user id.
  -- Failures here are swallowed so a locked auth.users row does not abort
  -- the personal-data delete. Session revocation below is NOT in this block.
  begin
    delete from auth.identities where user_id = uid;
    update auth.users
    set email = 'deleted+' || uid::text || '@invalid.local',
        raw_user_meta_data = '{}'::pg_catalog.jsonb
    where id = uid;
  exception
    when others then
      raise notice 'delete_own_account: skipped auth.users update: %', sqlerrm;
  end;

  -- End existing logins immediately. user_id is uuid on sessions and often
  -- varchar on refresh_tokens, so compare as text. These statements are
  -- outside the exception handler above: a failure must not be swallowed.
  delete from auth.refresh_tokens where user_id::text = uid::text;
  delete from auth.sessions where user_id::text = uid::text;
end;
$$;

revoke all on function public.delete_own_account(pg_catalog.uuid) from public;
revoke all on function public.delete_own_account(pg_catalog.uuid) from anon;
revoke all on function public.delete_own_account(pg_catalog.uuid) from authenticated;
grant execute on function public.delete_own_account(pg_catalog.uuid) to service_role;

commit;
