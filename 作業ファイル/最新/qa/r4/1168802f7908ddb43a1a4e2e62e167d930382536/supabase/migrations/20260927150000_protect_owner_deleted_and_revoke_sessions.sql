-- Follow-up to 20260920120000_delete_own_account_keep_public_foods.sql.
-- That file is already applied in production and must stay unchanged.
-- This migration is NOT applied to production by this change.
--
-- Reverting the pull request does not drop an already-applied column.
-- users.deleted_at and, after this file is applied, saved_foods.owner_deleted
-- stay until someone runs the down SQL by hand.
--
-- Idempotent: add owner_deleted if missing, replace delete_own_account,
-- replace the guard trigger, and re-issue column grants.
--
-- authenticated keeps INSERT/UPDATE on every saved_foods column except
-- owner_deleted. A table-level UPDATE grant would cover owner_deleted
-- (including columns added later), so the table privilege is revoked
-- and replaced with an explicit column list.
-- The trigger is a second check: client roles cannot set the flag.
-- delete_own_account is SECURITY DEFINER, so inside it current_user is
-- the function owner (postgres / supabase_admin) and the trigger allows
-- the update. service_role is allowed the same way.

begin;

alter table public.saved_foods
  add column if not exists owner_deleted boolean not null default false;

comment on column public.saved_foods.owner_deleted is
  'True after delete_own_account anonymizes the owner. Clients cannot set this.';

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

-- Table-level INSERT/UPDATE covers every column, including owner_deleted.
-- Replace them with column privileges that omit owner_deleted.
revoke insert, update on table public.saved_foods from authenticated;
revoke insert (owner_deleted), update (owner_deleted)
  on table public.saved_foods from authenticated;
revoke insert (owner_deleted), update (owner_deleted)
  on table public.saved_foods from anon;
revoke insert (owner_deleted), update (owner_deleted)
  on table public.saved_foods from public;

grant insert (
  user_id,
  food_id,
  visibility,
  status,
  moderation_status,
  name,
  normalized_name,
  base_amount,
  unit_type,
  kcal_per_base,
  protein_per_base,
  fat_per_base,
  carb_per_base,
  source_type,
  barcode,
  brand,
  supplementary_weight,
  copied_from_food_id,
  copied_from_owner_user_id,
  use_count,
  last_used_at,
  report_count,
  created_at,
  updated_at,
  deleted_at,
  version,
  serving_unit_label
), update (
  user_id,
  food_id,
  visibility,
  status,
  moderation_status,
  name,
  normalized_name,
  base_amount,
  unit_type,
  kcal_per_base,
  protein_per_base,
  fat_per_base,
  carb_per_base,
  source_type,
  barcode,
  brand,
  supplementary_weight,
  copied_from_food_id,
  copied_from_owner_user_id,
  use_count,
  last_used_at,
  report_count,
  created_at,
  updated_at,
  deleted_at,
  version,
  serving_unit_label
) on table public.saved_foods to authenticated;

grant insert (owner_deleted), update (owner_deleted)
  on table public.saved_foods to service_role;

-- Not SECURITY DEFINER. delete_own_account is SECURITY DEFINER, so while it
-- runs, current_user is the function owner and this trigger allows the write.
-- service_role requests run as service_role. Client updates run as authenticated.
-- current_user is a SQL keyword. A schema prefix is parsed as a column
-- reference and fails when the trigger runs.
create or replace function public.saved_foods_reject_owner_deleted_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('postgres', 'supabase_admin', 'service_role') then
    return new;
  end if;

  if tg_op = 'INSERT' and new.owner_deleted is true then
    raise exception 'owner_deleted cannot be set by the client';
  end if;

  if tg_op = 'UPDATE' and new.owner_deleted is distinct from old.owner_deleted then
    raise exception 'owner_deleted cannot be changed by the client';
  end if;

  return new;
end;
$$;

drop trigger if exists saved_foods_reject_owner_deleted_change
  on public.saved_foods;

create trigger saved_foods_reject_owner_deleted_change
  before insert or update on public.saved_foods
  for each row
  execute function public.saved_foods_reject_owner_deleted_change();

commit;
