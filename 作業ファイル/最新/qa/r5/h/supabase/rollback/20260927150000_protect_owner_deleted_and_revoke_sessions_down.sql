-- Down for 20260927150000_protect_owner_deleted_and_revoke_sessions.sql.
-- Not under supabase/migrations, so `db push` does not apply it.
-- Restores delete_own_account to the already-applied
-- 20260920120000 body (no owner_deleted, no session revoke),
-- drops the guard, drops the column, and restores table-level
-- INSERT/UPDATE for authenticated.
--
-- Reverting the pull request does not run this file and does not drop a
-- column that is already applied (public.users.deleted_at, or
-- saved_foods.owner_deleted after this migration). Dropping owner_deleted
-- is only this manual script, and it removes the 削除済みユーザー label.
--
-- Run this only after 20260927160000_delete_subscription_events_on_account_deletion_down.sql
-- when that migration was applied. This file drops saved_foods.owner_deleted.
-- The 160000 down reinstalls delete_own_account that writes owner_deleted.
-- Running this file first makes the next account deletion fail.
-- This file restores the already-applied 20260920120000 body, which still
-- ignores a failed auth.users email rewrite. That is the production
-- function this migration replaced. Full order: supabase/rollback/README.md.

begin;

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  delete from public.meal_template_items where user_id = uid;
  delete from public.meal_templates where user_id = uid;

  if to_regclass('public.workout_template_items') is not null then
    execute 'delete from public.workout_template_items where user_id = $1' using uid;
  end if;
  if to_regclass('public.workout_templates') is not null then
    execute 'delete from public.workout_templates where user_id = $1' using uid;
  end if;

  delete from public.food_ratings where rater_user_id = uid;
  delete from public.food_reports where reporter_user_id = uid;
  delete from public.blocked_food_creators
    where blocker_user_id = uid or blocked_user_id = uid;

  delete from public.saved_foods
    where user_id = uid
      and visibility is distinct from 'public';

  delete from public.food_entries where user_id = uid;
  delete from public.exercise_entries where user_id = uid;
  delete from public.weight_entries where user_id = uid;
  if to_regclass('public.alcohol_entries') is not null then
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
      deleted_at = timezone('utc', now())
  where id = uid;

  begin
    delete from auth.identities where user_id = uid;
    update auth.users
    set email = 'deleted+' || uid::text || '@invalid.local',
        raw_user_meta_data = '{}'::jsonb
    where id = uid;
  exception
    when others then
      raise notice 'delete_own_account: skipped auth.users update: %', sqlerrm;
  end;
end;
$$;

revoke all on function public.delete_own_account() from public;
revoke all on function public.delete_own_account() from anon;
revoke all on function public.delete_own_account() from authenticated;
grant execute on function public.delete_own_account() to authenticated;

drop trigger if exists saved_foods_reject_owner_deleted_change
  on public.saved_foods;

drop function if exists public.saved_foods_reject_owner_deleted_change();

alter table public.saved_foods
  drop column if exists owner_deleted;

-- Column privileges disappear with the column. Restore the table-level
-- grant from 20260801200000_tighten_public_grants_v1.sql.
grant select, insert, update on table public.saved_foods to authenticated;

commit;
