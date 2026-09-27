-- Executes the banned-name functions and the public-food update paths that
-- account deletion and reports use. Local Postgres only.

do $$
declare
  v_owner uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  v_reporter uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2';
  v_email text;
begin
  perform ayg_test.assert_true(
    public.compose_halfwidth_voiced('ｱ') is not null,
    'compose_halfwidth_voiced runs'
  );
  perform ayg_test.assert_true(
    public.normalize_public_food_name('カフェラテ') is not null,
    'normalize_public_food_name runs'
  );
  perform public.public_food_name_char_is_word('a');
  perform public.public_food_name_contains_term(
    public.normalize_public_food_name('おまんこカレー'),
    public.normalize_public_food_name('おまんこ')
  );
  perform ayg_test.assert_true(
    public.public_food_name_strip_phrase('cock tail', 'cock tail') <> 'cock tail',
    'strip phrase runs'
  );
  perform ayg_test.assert_true(
    public.public_food_name_term_uses_substring('おまんこ'),
    'explicit compound uses a substring match'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('カフェラテ'),
    'cafe latte is allowed'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('ポークソテー'),
    'pork saute is allowed'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('スモークソルト'),
    'smoked salt is allowed'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('Cock tail'),
    'cock tail is allowed'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('rape seed oil'),
    'rape seed oil is allowed'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned('おまんこ'),
    'explicit compound is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned('フェラチオ'),
    'katakana compound is rejected'
  );

  delete from public.food_reports where reporter_user_id = v_reporter;
  delete from public.saved_foods where user_id in (v_owner, v_reporter);
  delete from public.users where id in (v_owner, v_reporter);
  delete from auth.identities where user_id in (v_owner, v_reporter);
  delete from auth.sessions where user_id in (v_owner, v_reporter);
  delete from auth.refresh_tokens where user_id::text in (v_owner::text, v_reporter::text);
  delete from auth.users where id in (v_owner, v_reporter);

  insert into auth.users (id, aud, role, email, raw_user_meta_data)
  values
    (v_owner, 'authenticated', 'authenticated', 'owner@test.local', '{"provider":"apple"}'::jsonb),
    (v_reporter, 'authenticated', 'authenticated', 'reporter@test.local', '{}'::jsonb);
  insert into auth.identities (user_id, provider)
  values (v_owner, 'apple');
  insert into public.users (id, email) values
    (v_owner, 'owner@test.local'),
    (v_reporter, 'reporter@test.local');

  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility,
    kcal_per_base, protein_per_base, fat_per_base, carb_per_base
  ) values (
    v_owner, 'public-cabbage', 'だいこん', 'だいこん', 100, 'g', 'private',
    25, 1, 0, 5
  );
  perform ayg_test.set_auth(v_owner);
  perform public.publish_saved_food('public-cabbage');

  perform ayg_test.set_auth(v_reporter);
  insert into public.food_reports (
    report_id, reporter_user_id, target_food_owner_user_id, target_food_id, reason_code
  ) values (
    'smoke-report-1', v_reporter, v_owner, 'public-cabbage', 'inappropriate_name'
  );
  perform ayg_test.reset_role();

  perform ayg_test.set_auth(v_owner);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (
    v_owner, 'to-publish', 'にんじん', 'にんじん', 100, 'g', 'private'
  );
  perform public.publish_saved_food('to-publish');
  perform ayg_test.reset_role();

  if to_regprocedure('public.delete_own_account(uuid)') is not null then
    perform ayg_test.set_service_role();
    perform public.delete_own_account(v_owner);
    perform ayg_test.reset_role();
  else
    perform ayg_test.set_auth(v_owner);
    perform public.delete_own_account();
    perform ayg_test.reset_role();
  end if;

  select email into v_email from auth.users where id = v_owner;
  perform ayg_test.assert_true(
    v_email is not null and v_email <> 'owner@test.local',
    'auth.users email was rewritten'
  );
  perform ayg_test.assert_true(
    exists (
      select 1 from public.saved_foods
      where user_id = v_owner
        and food_id = 'public-cabbage'
        and visibility = 'public'
        and owner_deleted
    ),
    'public food remains and is marked owner_deleted'
  );
end
$$;
