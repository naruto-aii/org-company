-- Publish rate-limit atomicity tests (local Supabase only)
-- Run:
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/food_master_v1_1_test_helpers.sql
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/food_master_v1_1_rate_limit_test.sql

create or replace function ayg_test.publish_as(p_user_id uuid, p_food_id text)
returns void language plpgsql as $$
begin
  perform ayg_test.set_auth(p_user_id);
  perform public.publish_saved_food(p_food_id);
end;
$$;

create or replace function ayg_test.concurrent_publish_as(p_user_id uuid, p_food_id text)
returns boolean language plpgsql security definer
set search_path = public, ayg_test
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user_id::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user_id, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.publish_saved_food(p_food_id);
  return true;
exception when others then
  return false;
end;
$$;

grant execute on all functions in schema ayg_test to authenticated, postgres;

do $$
declare
  v_user_a uuid := '11111111-1111-1111-1111-111111111111';
  v_user_b uuid := '22222222-2222-2222-2222-222222222222';
  v_user_r uuid := '55555555-5555-5555-5555-555555555555';
  v_before integer;
  v_after integer;
begin
  perform ayg_test.cleanup_fixtures();

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) values
    (v_user_a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'usera@test.local', crypt('testpass', gen_salt('bf')), now(), now(), now()),
    (v_user_b, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'userb@test.local', crypt('testpass', gen_salt('bf')), now(), now(), now()),
    (v_user_r, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'userr@test.local', crypt('testpass', gen_salt('bf')), now(), now(), now())
  on conflict (id) do nothing;

  insert into public.users (id, email) values
    (v_user_a, 'usera@test.local'),
    (v_user_b, 'userb@test.local'),
    (v_user_r, 'userr@test.local')
  on conflict (id) do nothing;

  delete from public.rate_limit_buckets where user_id = v_user_r;

  -- publish success → hour count +1
  perform ayg_test.set_auth(v_user_r);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_r, 'ok-1', 'Ok One', 'ok one', 100, 'g', 'private');

  v_before := public.get_publish_rate_limit_hour_count(v_user_r);
  perform public.publish_saved_food('ok-1');
  v_after := public.get_publish_rate_limit_hour_count(v_user_r);
  perform ayg_test.assert_true(v_after = v_before + 1, 'publish success increments hour count by 1');

  -- duplicate publish fail → count unchanged
  perform ayg_test.set_auth(v_user_a);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_a, 'pub-dup-src', 'Dup Source', 'dup source', 100, 'g', 'private');
  perform public.publish_saved_food('pub-dup-src');

  perform ayg_test.set_auth(v_user_r);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_r, 'dup-fail', 'Dup Source', 'dup source', 100, 'g', 'private');

  v_before := public.get_publish_rate_limit_hour_count(v_user_r);
  perform ayg_test.assert_raises(
    $sql$select public.publish_saved_food('dup-fail')$sql$,
    '%duplicate%'
  );
  v_after := public.get_publish_rate_limit_hour_count(v_user_r);
  perform ayg_test.assert_true(v_after = v_before, 'duplicate publish failure does not increment count');

  -- hidden publish fail → count unchanged
  perform ayg_test.set_auth(v_user_r);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_r, 'hidden-try', 'Hidden Try', 'hidden try', 100, 'g', 'private');

  perform ayg_test.set_service_role();
  update public.saved_foods set moderation_status = 'hidden'
  where user_id = v_user_r and food_id = 'hidden-try';

  perform ayg_test.set_auth(v_user_r);
  v_before := public.get_publish_rate_limit_hour_count(v_user_r);
  perform ayg_test.assert_raises(
    $sql$select public.publish_saved_food('hidden-try')$sql$,
    '%moderation%'
  );
  v_after := public.get_publish_rate_limit_hour_count(v_user_r);
  perform ayg_test.assert_true(v_after = v_before, 'hidden publish failure does not increment count');

  -- deleted publish fail → count unchanged
  perform ayg_test.set_auth(v_user_r);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_r, 'deleted-fail', 'Deleted Fail', 'deleted fail', 100, 'g', 'private');
  update public.saved_foods
  set status = 'deleted', deleted_at = timezone('utc', now())
  where user_id = v_user_r and food_id = 'deleted-fail';

  v_before := public.get_publish_rate_limit_hour_count(v_user_r);
  perform ayg_test.assert_raises(
    $sql$select public.publish_saved_food('deleted-fail')$sql$,
    '%not publishable%'
  );
  v_after := public.get_publish_rate_limit_hour_count(v_user_r);
  perform ayg_test.assert_true(v_after = v_before, 'deleted publish failure does not increment count');

  -- other user's food publish fail → count unchanged
  perform ayg_test.set_auth(v_user_a);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_a, 'other-food', 'Other Food', 'other food', 100, 'g', 'private');

  perform ayg_test.set_auth(v_user_r);
  v_before := public.get_publish_rate_limit_hour_count(v_user_r);
  perform ayg_test.assert_raises(
    $sql$select public.publish_saved_food('other-food')$sql$,
    '%not found%'
  );
  v_after := public.get_publish_rate_limit_hour_count(v_user_r);
  perform ayg_test.assert_true(v_after = v_before, 'other user publish failure does not increment count');

  -- at hourly limit: reject without exceeding 10
  perform ayg_test.reset_role();
  delete from public.rate_limit_buckets where user_id = v_user_r;

  perform ayg_test.set_auth(v_user_r);
  for i in 1..10 loop
    insert into public.saved_foods (
      user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
    ) values (
      v_user_r, 'cap-' || i, 'Cap ' || i, 'cap ' || i, 200 + i, 'g', 'private'
    );
    perform public.publish_saved_food('cap-' || i);
  end loop;

  v_after := public.get_publish_rate_limit_hour_count(v_user_r);
  perform ayg_test.assert_true(v_after = 10, 'hour count stops at limit after successful publishes');

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_r, 'cap-over', 'Cap Over', 'cap over', 999, 'g', 'private');

  v_before := public.get_publish_rate_limit_hour_count(v_user_r);
  perform ayg_test.assert_raises(
    $sql$select public.publish_saved_food('cap-over')$sql$,
    '%hourly publish rate limit%'
  );
  v_after := public.get_publish_rate_limit_hour_count(v_user_r);
  perform ayg_test.assert_true(v_after = v_before and v_after = 10, 'rejected publish does not exceed hourly limit');

  raise notice 'ALL RATE LIMIT ATOMICITY TESTS PASSED';
end;
$$;
