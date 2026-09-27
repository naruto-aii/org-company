-- Down for 20260927180000_delete_own_account_service_role_only.sql.
-- Not under supabase/migrations, so `db push` does not apply it.
-- Drops the service_role-only function and restores the zero-argument
-- delete_own_account from 20260927160000, including EXECUTE for authenticated.
-- Run this before the 20260927160000 down file if both are being rolled back.

begin;

drop function if exists public.delete_own_account(pg_catalog.uuid);


create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid pg_catalog.uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

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


revoke all on function public.delete_own_account() from public;
revoke all on function public.delete_own_account() from anon;
revoke all on function public.delete_own_account() from authenticated;
grant execute on function public.delete_own_account() to authenticated;

commit;
