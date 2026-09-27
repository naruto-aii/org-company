-- Food Master V1.1 — SQL integration tests (local Supabase only)
-- Run:
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/food_master_v1_1_test_helpers.sql
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/food_master_v1_1_test.sql

do $$
declare
  v_user_a uuid := '11111111-1111-1111-1111-111111111111';
  v_user_b uuid := '22222222-2222-2222-2222-222222222222';
  v_user_c uuid := '33333333-3333-3333-3333-333333333333';
  v_user_d uuid := '44444444-4444-4444-4444-444444444444';
  v_food_a1 text := 'food-a-cabbage-200g';
  v_food_a2 text := 'food-a-cabbage-100g';
  v_food_a3 text := 'food-a-private-cabbage';
  v_template_a text := 'tmpl-a-1';
  v_item_a1 text := 'item-a-1';
  v_entry_legacy text := 'legacy-entry-1';
  v_cnt integer;
  v_row record;
  i integer;
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
    (v_user_c, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'userc@test.local', crypt('testpass', gen_salt('bf')), now(), now(), now()),
    (v_user_d, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'userd@test.local', crypt('testpass', gen_salt('bf')), now(), now(), now())
  on conflict (id) do nothing;

  insert into public.users (id, email) values
    (v_user_a, 'usera@test.local'),
    (v_user_b, 'userb@test.local'),
    (v_user_c, 'userc@test.local'),
    (v_user_d, 'userd@test.local')
  on conflict (id) do nothing;

  insert into public.food_entries (user_id, entry_id, name, kcal_per_unit, quantity, logged_at)
  values (v_user_a, v_entry_legacy, 'legacy rice', 200, 2, timezone('utc', now()))
  on conflict (user_id, entry_id) do nothing;

  -- saved_foods RLS + publish path
  perform ayg_test.set_auth(v_user_a);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (
    v_user_a, v_food_a3, 'Private Cabbage', 'private cabbage', 200, 'g', 'private'
  );

  perform ayg_test.set_auth(v_user_b);
  select count(*) into v_cnt from public.saved_foods
  where user_id = v_user_a and food_id = v_food_a3;
  perform ayg_test.assert_true(v_cnt = 0, 'B cannot SELECT A private food');

  perform ayg_test.set_auth(v_user_a);
  perform ayg_test.assert_raises(
    format($sql$update public.saved_foods set visibility = 'public'
      where user_id = '%s' and food_id = '%s'$sql$, v_user_a, v_food_a3),
    '%publish_saved_food%'
  );
  perform public.publish_saved_food(v_food_a3);

  perform ayg_test.set_auth(v_user_b);
  select count(*) into v_cnt from public.saved_foods
  where user_id = v_user_a and food_id = v_food_a3;
  perform ayg_test.assert_true(v_cnt = 1, 'B can SELECT A public food');

  perform ayg_test.assert_raises(
    format($sql$update public.saved_foods set name = 'hacked'
      where user_id = '%s' and food_id = '%s'$sql$, v_user_a, v_food_a3),
    '%permission%'
  );

  perform ayg_test.set_auth(v_user_a);
  update public.saved_foods
  set status = 'deleted', deleted_at = timezone('utc', now())
  where user_id = v_user_a and food_id = v_food_a3;

  perform ayg_test.set_auth(v_user_b);
  select count(*) into v_cnt from public.saved_foods
  where user_id = v_user_a and food_id = v_food_a3;
  perform ayg_test.assert_true(v_cnt = 0, 'Soft-deleted food hidden from public SELECT');

  -- duplicate prevention (publish RPC)
  perform ayg_test.set_auth(v_user_a);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_a, v_food_a1, 'Cabbage', 'cabbage', 200, 'g', 'private');
  perform public.publish_saved_food(v_food_a1);

  perform ayg_test.set_auth(v_user_b);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_b, 'dup-b', 'Cabbage', 'cabbage', 200, 'g', 'private');
  perform ayg_test.assert_raises(
    $sql$select public.publish_saved_food('dup-b')$sql$,
    '%duplicate%'
  );

  perform ayg_test.assert_raises(
    format($sql$insert into public.saved_foods
      (user_id, food_id, name, normalized_name, base_amount, unit_type, visibility)
      values ('%s', 'direct-public', 'Direct Public', 'direct public', 200, 'g', 'public')$sql$, v_user_b),
    '%publish_saved_food%'
  );

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_b, v_food_a2, 'Cabbage small', 'cabbage', 100, 'g', 'private');
  perform public.publish_saved_food(v_food_a2);

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_b, 'priv-dup', 'Cabbage private', 'cabbage', 200, 'g', 'private');

  perform ayg_test.set_service_role();
  update public.saved_foods set moderation_status = 'hidden'
  where user_id = v_user_a and food_id = v_food_a1;

  perform ayg_test.set_auth(v_user_b);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_b, 'dup-hidden', 'Cabbage', 'cabbage', 200, 'g', 'private');
  perform ayg_test.assert_raises(
    $sql$select public.publish_saved_food('dup-hidden')$sql$,
    '%duplicate%'
  );

  perform ayg_test.set_auth(v_user_a);
  update public.saved_foods
  set status = 'deleted', deleted_at = timezone('utc', now())
  where user_id = v_user_a and food_id = v_food_a1;

  perform ayg_test.set_auth(v_user_b);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_b, 're-register', 'Cabbage', 'cabbage', 200, 'g', 'private');
  perform public.publish_saved_food('re-register');

  -- ratings (direct RLS)
  perform ayg_test.set_auth(v_user_b);
  perform ayg_test.assert_raises(
    format($sql$insert into public.food_ratings
      (rating_id, food_owner_user_id, food_id, rater_user_id, rating_type)
      values ('self', '%s', 're-register', '%s', 'good')$sql$, v_user_b, v_user_b),
    '%self rating%'
  );

  perform ayg_test.set_auth(v_user_a);
  insert into public.food_ratings (
    rating_id, food_owner_user_id, food_id, rater_user_id, rating_type
  ) values ('r1', v_user_b, 're-register', v_user_a, 'good');

  select good_count, bad_count into v_row
  from public.food_rating_stats
  where food_owner_user_id = v_user_b and food_id = 're-register';
  perform ayg_test.assert_true(v_row.good_count = 1 and v_row.bad_count = 0, 'Good insert stats');

  update public.food_ratings set rating_type = 'bad'
  where rating_id = 'r1' and rater_user_id = v_user_a;
  select good_count, bad_count into v_row
  from public.food_rating_stats
  where food_owner_user_id = v_user_b and food_id = 're-register';
  perform ayg_test.assert_true(v_row.good_count = 0 and v_row.bad_count = 1, 'Good→Bad stats');

  update public.food_ratings set rating_type = 'good' where rating_id = 'r1';
  delete from public.food_ratings where rating_id = 'r1';
  select good_count, bad_count into v_row
  from public.food_rating_stats
  where food_owner_user_id = v_user_b and food_id = 're-register';
  perform ayg_test.assert_true(v_row.good_count = 0 and v_row.bad_count = 0, 'Rating delete stats');

  insert into public.food_ratings (
    rating_id, food_owner_user_id, food_id, rater_user_id, rating_type
  ) values ('r2', v_user_b, 're-register', v_user_a, 'good');

  perform ayg_test.set_auth(v_user_b);
  perform ayg_test.assert_raises(
    $sql$update public.food_ratings set rating_type = 'bad' where rating_id = 'r2'$sql$,
    '%permission%'
  );

  -- admin columns
  perform ayg_test.set_auth(v_user_b);
  perform ayg_test.assert_raises(
    format($sql$update public.saved_foods set moderation_status = 'hidden'
      where user_id = '%s' and food_id = 're-register'$sql$, v_user_b),
    '%admin-only%'
  );

  -- templates
  perform ayg_test.set_auth(v_user_a);
  insert into public.meal_templates (user_id, template_id, name, normalized_name)
  values (v_user_a, v_template_a, 'My Template', 'my template');

  insert into public.meal_template_items (
    user_id, item_id, template_id, saved_food_id, source_owner_user_id,
    name, base_amount, unit_type, consumed_amount, sort_order
  ) values (
    v_user_a, v_item_a1, v_template_a, v_food_a2, v_user_b,
    'Cabbage snapshot', 100, 'g', 150, 1
  );

  perform ayg_test.set_auth(v_user_b);
  select count(*) into v_cnt from public.meal_templates where user_id = v_user_a;
  perform ayg_test.assert_true(v_cnt = 0, 'B cannot read A template');

  perform ayg_test.reset_role();
  update public.saved_foods
  set status = 'deleted', deleted_at = timezone('utc', now())
  where user_id = v_user_b and food_id = v_food_a2;

  perform ayg_test.set_auth(v_user_a);
  select name, saved_food_id into v_row
  from public.meal_template_items
  where user_id = v_user_a and item_id = v_item_a1;
  perform ayg_test.assert_true(v_row.name = 'Cabbage snapshot', 'Snapshot preserved');

  -- publish RPC security
  perform ayg_test.set_auth(v_user_a);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_a, 'other-priv', 'Other Private', 'other private', 100, 'g', 'private');

  perform ayg_test.set_auth(v_user_b);
  perform ayg_test.assert_raises(
    $sql$select public.publish_saved_food('other-priv')$sql$,
    '%not found%'
  );

  perform ayg_test.set_auth(v_user_b);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_b, 'to-hide', 'Hidden Test', 'hidden test', 100, 'g', 'private');
  perform public.publish_saved_food('to-hide');

  perform ayg_test.set_service_role();
  update public.saved_foods set moderation_status = 'hidden'
  where user_id = v_user_b and food_id = 'to-hide';

  perform ayg_test.set_auth(v_user_b);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_b, 'hidden-pub', 'Hidden Pub', 'hidden pub', 100, 'g', 'private');

  perform ayg_test.set_service_role();
  update public.saved_foods set moderation_status = 'hidden'
  where user_id = v_user_b and food_id = 'hidden-pub';

  perform ayg_test.set_auth(v_user_b);
  perform ayg_test.assert_raises(
    $sql$select public.publish_saved_food('hidden-pub')$sql$,
    '%moderation%'
  );

  perform ayg_test.set_auth(v_user_b);
  update public.saved_foods
  set status = 'deleted', deleted_at = timezone('utc', now())
  where user_id = v_user_b and food_id = 'hidden-pub';
  perform ayg_test.assert_raises(
    $sql$select public.publish_saved_food('hidden-pub')$sql$,
    '%not publishable%'
  );

  -- blocked creator exclusion (RLS Option A)
  perform ayg_test.set_auth(v_user_a);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (
    v_user_a, 'block-target', 'Blocked Creator Cabbage', 'blocked creator cabbage',
    300, 'g', 'private'
  );
  perform public.publish_saved_food('block-target');

  perform ayg_test.set_auth(v_user_b);
  select count(*) into v_cnt from public.saved_foods
  where user_id = v_user_a and food_id = 'block-target';
  perform ayg_test.assert_true(v_cnt = 1, 'Public food visible before block');

  insert into public.blocked_food_creators (blocker_user_id, blocked_user_id)
  values (v_user_b, v_user_a);

  select count(*) into v_cnt from public.saved_foods
  where user_id = v_user_a and food_id = 'block-target';
  perform ayg_test.assert_true(v_cnt = 0, 'Blocked creator hidden from viewer');

  perform ayg_test.set_auth(v_user_a);
  select count(*) into v_cnt from public.blocked_food_creators
  where blocked_user_id = v_user_b;
  perform ayg_test.assert_true(v_cnt = 0, 'Blocked user cannot see block list');

  perform ayg_test.set_auth(v_user_b);
  delete from public.blocked_food_creators
  where blocker_user_id = v_user_b and blocked_user_id = v_user_a;

  select count(*) into v_cnt from public.saved_foods
  where user_id = v_user_a and food_id = 'block-target';
  perform ayg_test.assert_true(v_cnt = 1, 'Public food visible after unblock');

  -- report_count sync
  perform ayg_test.set_auth(v_user_b);
  insert into public.food_reports (
    report_id, reporter_user_id, target_food_owner_user_id, target_food_id, reason_code
  ) values ('rep-1', v_user_b, v_user_a, 'block-target', 'spam');

  perform ayg_test.set_auth(v_user_c);
  insert into public.food_reports (
    report_id, reporter_user_id, target_food_owner_user_id, target_food_id, reason_code
  ) values ('rep-2', v_user_c, v_user_a, 'block-target', 'other');

  perform ayg_test.reset_role();
  select report_count into v_cnt from public.saved_foods
  where user_id = v_user_a and food_id = 'block-target';
  perform ayg_test.assert_true(v_cnt = 2, 'report_count +2 on insert');

  perform ayg_test.set_auth(v_user_b);
  perform ayg_test.assert_raises(
    format($sql$insert into public.food_reports
      (report_id, reporter_user_id, target_food_owner_user_id, target_food_id, reason_code)
      values ('rep-dup', '%s', '%s', 'block-target', 'other')$sql$, v_user_b, v_user_a),
    '%duplicate%'
  );

  perform ayg_test.reset_role();
  delete from auth.users where id = v_user_c;
  select report_count into v_cnt from public.saved_foods
  where user_id = v_user_a and food_id = 'block-target';
  perform ayg_test.assert_true(v_cnt = 1, 'report_count -1 on reporter cascade delete');

  perform ayg_test.reset_role();
  select count(*) into v_cnt from public.food_reports
  where target_food_owner_user_id = v_user_a and target_food_id = 'block-target';
  perform ayg_test.assert_true(v_cnt = 1, 'food_reports count matches after cascade');

  update public.saved_foods sf
  set report_count = coalesce(sub.cnt, 0)
  from (
    select target_food_owner_user_id, target_food_id, count(*) cnt
    from public.food_reports
    group by 1, 2
  ) sub
  where sf.user_id = sub.target_food_owner_user_id and sf.food_id = sub.target_food_id;

  select report_count into v_cnt from public.saved_foods
  where user_id = v_user_a and food_id = 'block-target';
  perform ayg_test.assert_true(v_cnt = 1, 'report_count reconciles from food_reports');

  -- publish rate limit (V1.1: 10/hour/user — dedicated user)
  perform ayg_test.set_auth(v_user_d);
  for i in 1..10 loop
    insert into public.saved_foods (
      user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
    ) values (
      v_user_d, 'pub-' || i, 'Food ' || i, 'food ' || i, 100 + i, 'g', 'private'
    );
    perform public.publish_saved_food('pub-' || i);
  end loop;

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (v_user_d, 'pub-limit', 'Limit Food', 'limit food', 999, 'g', 'private');
  perform ayg_test.assert_raises(
    $sql$select public.publish_saved_food('pub-limit')$sql$,
    '%hourly publish rate limit%'
  );

  for i in 1..15 loop
    insert into public.saved_foods (
      user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
    ) values (
      v_user_d, 'priv-' || i, 'Private ' || i, 'private ' || i, 50 + i, 'g', 'private'
    );
  end loop;

  -- legacy food_entries
  perform ayg_test.reset_role();
  select base_amount, consumed_amount, quantity into v_row
  from public.food_entries
  where user_id = v_user_a and entry_id = v_entry_legacy;
  perform ayg_test.assert_true(v_row.base_amount is null, 'Legacy base_amount null');
  perform ayg_test.assert_true(v_row.consumed_amount is null, 'Legacy consumed_amount null');
  perform ayg_test.assert_true(v_row.quantity = 2, 'Legacy quantity preserved');

  raise notice 'ALL V1.1 TESTS PASSED';
end;
$$;
