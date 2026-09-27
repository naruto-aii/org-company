-- Tighten public schema grants: revoke excessive anon/authenticated privileges.
-- Does NOT drop tables/columns, truncate, or delete data.
-- Safe to re-run (REVOKE ALL then GRANT minimal set).
--
-- Grant policy for ALL future migrations (see supabase/migrations/README.md):
--   1. REVOKE ALL on new tables/functions from anon, authenticated, PUBLIC.
--   2. GRANT only the minimal privileges the app needs.
--   3. Do not rely on supabase_admin default ACLs (migration runner may skip them).

begin;

-- Avoid anon table SELECT on blocked_food_creators: short-circuit before subquery.
create or replace function public.is_saved_food_visible_to_viewer(p_owner_user_id uuid)
returns boolean
language plpgsql
stable
set search_path = public
as $$
begin
  if auth.uid() is null then
    return true;
  end if;

  if p_owner_user_id = auth.uid() then
    return true;
  end if;

  return not exists (
    select 1
    from public.blocked_food_creators b
    where b.blocker_user_id = auth.uid()
      and b.blocked_user_id = p_owner_user_id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Helper: personal tables — anon none, authenticated CRUD only (no TRUNCATE etc.)
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
  privs text;
begin
  foreach t in array array[
    'users',
    'profiles',
    'goals',
    'nutrition_settings',
    'health_snapshots',
    'app_settings',
    'food_entries',
    'exercise_entries',
    'weight_entries',
    'alcohol_entries',
    'meal_templates',
    'meal_template_items',
    'workout_templates',
    'workout_template_items',
    'blocked_food_creators',
    'food_ratings',
    'food_reports'
  ] loop
    execute format('revoke all on table public.%I from anon', t);
    execute format('revoke all on table public.%I from authenticated', t);
  end loop;
end $$;

-- users: select + insert on first login only
grant select, insert on table public.users to authenticated;

grant select, insert, update on table public.profiles to authenticated;
grant select, insert, update on table public.goals to authenticated;
grant select, insert, update on table public.nutrition_settings to authenticated;
grant select, insert, update on table public.health_snapshots to authenticated;
grant select, insert, update on table public.app_settings to authenticated;

grant select, insert, update, delete on table public.food_entries to authenticated;
grant select, insert, update, delete on table public.alcohol_entries to authenticated;

-- exercise/weight: app sync uses upsert; delete policy exists for future parity
grant select, insert, update, delete on table public.exercise_entries to authenticated;
grant select, insert, update, delete on table public.weight_entries to authenticated;

-- meal/workout templates: soft-delete via update on parent; items allow hard delete for orphan cleanup
grant select, insert, update on table public.meal_templates to authenticated;
grant select, insert, update, delete on table public.meal_template_items to authenticated;
grant select, insert, update on table public.workout_templates to authenticated;
grant select, insert, update, delete on table public.workout_template_items to authenticated;

grant select, insert, update, delete on table public.blocked_food_creators to authenticated;
grant select, insert, update, delete on table public.food_ratings to authenticated;
grant select, insert on table public.food_reports to authenticated;

-- ---------------------------------------------------------------------------
-- Public-read exceptions (anon SELECT only)
-- ---------------------------------------------------------------------------
revoke all on table public.saved_foods from anon;
revoke all on table public.saved_foods from authenticated;
grant select on table public.saved_foods to anon;
grant select, insert, update on table public.saved_foods to authenticated;

revoke all on table public.food_rating_stats from anon;
revoke all on table public.food_rating_stats from authenticated;
grant select on table public.food_rating_stats to anon;
grant select on table public.food_rating_stats to authenticated;

-- Internal rate-limit ledger — no direct client access
revoke all on table public.rate_limit_buckets from anon;
revoke all on table public.rate_limit_buckets from authenticated;

-- ---------------------------------------------------------------------------
-- Functions: revoke client EXECUTE from anon; grant only required RPCs
-- ---------------------------------------------------------------------------
do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
  loop
    execute format('revoke all on function %s from public', fn.sig);
    execute format('revoke all on function %s from anon', fn.sig);
    execute format('revoke all on function %s from authenticated', fn.sig);
  end loop;
end $$;

grant execute on function public.publish_saved_food(text) to authenticated;

-- RLS policy helpers (immutable/stable; no direct data access beyond policy checks)
grant execute on function public.is_saved_food_publicly_visible(text, text, timestamptz, text)
  to anon, authenticated;
grant execute on function public.is_saved_food_visible_to_viewer(uuid)
  to anon, authenticated;
grant execute on function public.is_saved_food_reportable(text, text, timestamptz)
  to authenticated;

-- Trigger / internal helpers remain executable by postgres (owner); not granted to anon/authenticated.

-- ---------------------------------------------------------------------------
-- Default privileges for future objects in public schema
-- ---------------------------------------------------------------------------
alter default privileges for role postgres in schema public
  revoke all on tables from anon;
alter default privileges for role postgres in schema public
  revoke all on tables from authenticated;
alter default privileges for role postgres in schema public
  grant select, insert, update, delete on tables to authenticated;

alter default privileges for role postgres in schema public
  revoke all on sequences from anon;
alter default privileges for role postgres in schema public
  revoke all on sequences from authenticated;
alter default privileges for role postgres in schema public
  grant usage, select on sequences to authenticated;

alter default privileges for role postgres in schema public
  revoke all on functions from anon;
alter default privileges for role postgres in schema public
  revoke all on functions from authenticated;

-- supabase_admin default ACLs require SET ROLE supabase_admin; skip gracefully when unavailable.
do $hardening$
begin
  alter default privileges for role supabase_admin in schema public
    revoke all on tables from anon;
  alter default privileges for role supabase_admin in schema public
    revoke all on tables from authenticated;
  alter default privileges for role supabase_admin in schema public
    grant select, insert, update, delete on tables to authenticated;

  alter default privileges for role supabase_admin in schema public
    revoke all on sequences from anon;
  alter default privileges for role supabase_admin in schema public
    revoke all on sequences from authenticated;
  alter default privileges for role supabase_admin in schema public
    grant usage, select on sequences to authenticated;

  alter default privileges for role supabase_admin in schema public
    revoke all on functions from anon;
  alter default privileges for role supabase_admin in schema public
    revoke all on functions from authenticated;
exception
  when insufficient_privilege then
    raise notice
      'hardening: skipped supabase_admin default privileges (insufficient privilege for current role %) ',
      current_user;
end;
$hardening$;

commit;
