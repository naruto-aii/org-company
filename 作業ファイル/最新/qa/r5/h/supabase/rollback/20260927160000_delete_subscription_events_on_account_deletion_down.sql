-- Down for 20260927160000_delete_subscription_events_on_account_deletion.sql.
-- Not under supabase/migrations, so `db push` does not apply it.
-- Restores the zero-argument delete_own_account that sets owner_deleted
-- and does not delete subscription_events. Does not drop the table.
-- The auth.users email rewrite stays outside an exception handler.
-- A failed anonymization aborts and rolls the deletion back.
-- Run this after 20260927180000_delete_own_account_service_role_only_down.sql
-- and before 20260927150000_protect_owner_deleted_and_revoke_sessions_down.sql.
-- The 150000 down drops saved_foods.owner_deleted. Running it first, then
-- this file, reinstalls a function that writes that column, and the next
-- account deletion fails. Full order: supabase/rollback/README.md.

begin;

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

  update public.users
  set email = null,
      deleted_at = pg_catalog.timezone('utc', pg_catalog.now())
  where id = uid;

  -- Prevent the same Google/Apple identity from signing back into this row.
  -- Public foods stay attached to this anonymized user id.
  -- Do not catch errors here. A failed email rewrite must abort the function
  -- so the address is not left in auth.users while deletion is reported as
  -- success. The statement runs in the caller's transaction, so the personal
  -- data deletes above roll back with it. Deleting the identities row
  -- removes identity_data. Replacing raw_user_meta_data removes the Google
  -- name and profile-image URL stored at sign-in.
  delete from auth.identities where user_id = uid;
  update auth.users
  set email = 'deleted+' || uid::text || '@invalid.local',
      raw_user_meta_data = '{}'::pg_catalog.jsonb
  where id = uid;

  -- End existing logins immediately. user_id is uuid on sessions and often
  -- varchar on refresh_tokens, so compare as text. A failure here also
  -- aborts the function and rolls the deletion back.
  delete from auth.refresh_tokens where user_id::text = uid::text;
  delete from auth.sessions where user_id::text = uid::text;
end;
$$;


revoke all on function public.delete_own_account() from public;
revoke all on function public.delete_own_account() from anon;
revoke all on function public.delete_own_account() from authenticated;
grant execute on function public.delete_own_account() to authenticated;

commit;
