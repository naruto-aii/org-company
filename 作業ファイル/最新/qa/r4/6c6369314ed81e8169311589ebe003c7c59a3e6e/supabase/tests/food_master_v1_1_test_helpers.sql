-- Shared helpers for Food Master V1.1 SQL tests (local Supabase only).
-- Run before test files:
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/food_master_v1_1_test_helpers.sql

create schema if not exists ayg_test;
grant usage on schema ayg_test to authenticated, postgres;

create or replace function ayg_test.set_auth(p_user_id uuid, p_role text default 'authenticated')
returns void language plpgsql as $$
begin
  perform set_config('role', p_role, true);
  perform set_config('request.jwt.claim.sub', p_user_id::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user_id, 'role', p_role)::text,
    true
  );
  perform set_config(
    'request.jwt.claim.role',
    case when p_role = 'service_role' then 'service_role' else 'authenticated' end,
    true
  );
end;
$$;

create or replace function ayg_test.reset_role()
returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  reset role;
end;
$$;

create or replace function ayg_test.set_service_role()
returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claim.role', 'service_role', true);
end;
$$;

create or replace function ayg_test.assert_true(p_condition boolean, p_message text)
returns void language plpgsql as $$
begin
  if not p_condition then
    raise exception 'ASSERT FAILED: %', p_message;
  end if;
end;
$$;

create or replace function ayg_test.assert_raises(p_sql text, p_like text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
    raise exception 'ASSERT FAILED: expected error matching %, but succeeded: %', p_like, p_sql;
  exception when others then
    if sqlerrm not like p_like then
      raise exception 'ASSERT FAILED: expected %, got % (sql=%)', p_like, sqlerrm, p_sql;
    end if;
  end;
end;
$$;

-- Removes fixture rows for fixed test user UUIDs so tests are re-runnable.
create or replace function ayg_test.cleanup_fixtures()
returns void
language plpgsql
set search_path = public, auth, extensions
as $$
declare
  v_users constant uuid[] := array[
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid,
    '44444444-4444-4444-4444-444444444444'::uuid,
    '55555555-5555-5555-5555-555555555555'::uuid
  ];
  u uuid;
begin
  foreach u in array v_users loop
    delete from public.meal_template_items where user_id = u;
    delete from public.meal_templates where user_id = u;
    delete from public.food_ratings where rater_user_id = u;
    delete from public.food_reports where reporter_user_id = u;
    delete from public.blocked_food_creators where blocker_user_id = u;
    delete from public.blocked_food_creators where blocked_user_id = u;
    delete from public.saved_foods where user_id = u;
    delete from public.food_entries
    where user_id = u and entry_id <> 'legacy-entry-1';
    delete from public.rate_limit_buckets where user_id = u;
  end loop;

  delete from public.food_reports
  where target_food_owner_user_id = any (v_users);

  delete from public.food_ratings
  where food_owner_user_id = any (v_users);

  delete from public.food_rating_stats
  where food_owner_user_id = any (v_users);

  -- Restore user C if removed by reporter cascade test in a prior run.
  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) values (
    '33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'userc@test.local',
    crypt('testpass', gen_salt('bf')), now(), now(), now()
  ) on conflict (id) do nothing;

  insert into public.users (id, email) values
    ('33333333-3333-3333-3333-333333333333', 'userc@test.local')
  on conflict (id) do nothing;
end;
$$;

grant execute on all functions in schema ayg_test to authenticated, postgres;
