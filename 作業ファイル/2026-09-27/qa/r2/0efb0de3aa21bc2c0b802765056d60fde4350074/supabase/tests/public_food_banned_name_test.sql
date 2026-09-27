-- Public food name filter. Local Supabase only. Does not touch production.
-- Run after the banned-name migration and the shared helpers:
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/food_master_v1_1_test_helpers.sql
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/public_food_banned_name_test.sql

do $$
declare
  v_user uuid := '66666666-6666-6666-6666-666666666666';
  v_kcal double precision;
begin
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('キャベツ'),
    'ordinary name is allowed'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned('ＦＵＣＫ'),
    'full-width latin name is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned('f u c k'),
    'spaced latin name is rejected'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('shiitake'),
    'shiitake is not a banned token'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('イエロー'),
    'yellow is not rejected by a short kana term'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned(U&'f\00FAck'),
    'precomposed accent is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned(U&'fu\0301ck'),
    'combining accent is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned(U&'fu\0441k'),
    'cyrillic lookalike is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned('5h1t'),
    'digit substitution is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned('c0ck'),
    'zero substitution is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned('$hit'),
    'dollar substitution is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned('sh!t'),
    'exclamation substitution is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned(U&'\FF77\FF81\FF76\FF9E\FF72'),
    'halfwidth voiced kana is rejected'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('sea bass'),
    'sea bass stays allowed'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('cocktail'),
    'cocktail stays allowed'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('カフェラテ'),
    'cafe latte stays allowed'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('ポークソテー'),
    'pork saute stays allowed'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('ポークソーセージ'),
    'pork sausage stays allowed'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('ミルクソフト'),
    'milk soft stays allowed'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('スモークソルト'),
    'smoked salt stays allowed'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('サンマンコ'),
    'sanmanko stays allowed'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('Cock tail'),
    'spaced cocktail phrase stays allowed'
  );
  perform ayg_test.assert_true(
    not public.public_food_name_is_banned('rape seed oil'),
    'rape seed oil stays allowed'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned('くそ'),
    'bare short kana term is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned('フェラ'),
    'bare kana term is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned('まんこ'),
    'bare short term is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned('cock'),
    'bare latin term is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned('rape'),
    'bare rape is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned('fuck rape seed oil'),
    'banned word beside an allowed phrase is rejected'
  );
  perform ayg_test.assert_true(
    public.public_food_name_is_banned(U&'\FF81\FF9D\FF8E\FF9F'),
    'halfwidth handakuten is rejected'
  );

  delete from public.saved_foods where user_id = v_user;
  delete from public.users where id = v_user;
  delete from auth.users where id = v_user;

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) values (
    v_user, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    'banned-name@test.local', crypt('testpass', gen_salt('bf')), now(), now(), now()
  );
  insert into public.users (id, email) values (v_user, 'banned-name@test.local');

  perform ayg_test.set_auth(v_user);
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values
    (v_user, 'banned-publish', 'fuck', 'fuck', 100, 'g', 'private'),
    (v_user, 'ok-publish', 'キャベツ', 'キャベツ', 100, 'g', 'private'),
    (v_user, 'brand-banned', 'キャベツ', 'キャベツ', 100, 'g', 'private');

  update public.saved_foods
  set brand = 'shit'
  where user_id = v_user and food_id = 'brand-banned';

  perform ayg_test.assert_raises(
    $sql$select public.publish_saved_food('banned-publish')$sql$,
    '%public food name is not allowed%'
  );
  perform ayg_test.assert_raises(
    $sql$select public.publish_saved_food('brand-banned')$sql$,
    '%public food name is not allowed%'
  );

  perform public.publish_saved_food('ok-publish');

  perform ayg_test.assert_raises(
    format(
      $sql$update public.saved_foods
        set name = 'うんこ', normalized_name = 'うんこ'
        where user_id = '%s' and food_id = 'ok-publish'$sql$,
      v_user
    ),
    '%public food name is not allowed%'
  );

  perform ayg_test.assert_raises(
    format(
      $sql$update public.saved_foods
        set brand = 'c0ck'
        where user_id = '%s' and food_id = 'ok-publish'$sql$,
      v_user
    ),
    '%public food name is not allowed%'
  );
  perform ayg_test.assert_raises(
    format(
      $sql$update public.saved_foods
        set serving_unit_label = 'sh!t'
        where user_id = '%s' and food_id = 'ok-publish'$sql$,
      v_user
    ),
    '%public food name is not allowed%'
  );

  update public.saved_foods
  set kcal_per_base = 40
  where user_id = v_user and food_id = 'ok-publish';

  select kcal_per_base into v_kcal
  from public.saved_foods
  where user_id = v_user and food_id = 'ok-publish';
  perform ayg_test.assert_true(v_kcal = 40, 'non-name update of a public row still works');

  perform ayg_test.set_service_role();
  insert into public.saved_foods (
    user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
  ) values (
    v_user, 'legacy-banned', 'fuck', 'fuck', 50, 'g', 'public'
  );

  update public.saved_foods
  set kcal_per_base = 12
  where user_id = v_user and food_id = 'legacy-banned';

  select kcal_per_base into v_kcal
  from public.saved_foods
  where user_id = v_user and food_id = 'legacy-banned';
  perform ayg_test.assert_true(
    v_kcal = 12,
    'existing banned name can still change other fields'
  );
end;
$$;
