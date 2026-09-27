-- Reject banned public food text at publish time and when a public row's
-- name, normalized_name, brand, or serving_unit_label changes.
-- Does not scan or rewrite existing rows.
--
-- pg_catalog.normalize(text, NFKC) needs PostgreSQL 13 or newer.
-- supabase/config.toml sets major_version = 17.
-- Halfwidth dakuten (U+FF9E) and handakuten (U+FF9F) are composed before
-- NFKC so Dart and Postgres agree even when one NFKC implementation does not.

create or replace function public.compose_halfwidth_voiced(p_text text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v text := coalesce(p_text, '');
  v_out text := '';
  i integer := 1;
  n integer := char_length(v);
  ch text;
  nxt text;
  base_at integer;
  dakuten_base constant text := 'ｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾊﾋﾌﾍﾎ';
  dakuten_to constant text := 'ガギグゲゴザジズゼゾダヂヅデドバビブベボ';
  handakuten_base constant text := 'ﾊﾋﾌﾍﾎ';
  handakuten_to constant text := 'パピプペポ';
begin
  while i <= n loop
    ch := substr(v, i, 1);
    if i < n then
      nxt := substr(v, i + 1, 1);
      if nxt = chr(65438) then
        base_at := strpos(dakuten_base, ch);
        if base_at > 0 then
          v_out := v_out || substr(dakuten_to, base_at, 1);
          i := i + 2;
          continue;
        end if;
      elsif nxt = chr(65439) then
        base_at := strpos(handakuten_base, ch);
        if base_at > 0 then
          v_out := v_out || substr(handakuten_to, base_at, 1);
          i := i + 2;
          continue;
        end if;
      end if;
    end if;
    v_out := v_out || ch;
    i := i + 1;
  end loop;
  return v_out;
end;
$$;

create or replace function public.normalize_public_food_name(p_name text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v text := pg_catalog.normalize(
    public.compose_halfwidth_voiced(coalesce(p_name, '')),
    NFKC
  );
  v_out text := '';
  i integer;
  ch text;
  cp integer;
  hw_from constant text := 'ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ';
  hw_to constant text := 'をぁぃぅぇぉゃゅょっーあいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん';
  hw_at integer;
  -- Same pair as publicFoodConfusableFrom / publicFoodConfusableTo.
  fold_from constant text := 'àáâãäåÀÁÂÃÄÅèéêëÈÉÊËìíîïÌÍÎÏòóôõöÒÓÔÕÖùúûüÙÚÛÜýÿÝŸñÑçÇаАеЕоОрРсСуУхХіІјЈѕЅԁԀ013457@$!';
  fold_to constant text := 'aaaaaaaaaaaaeeeeeeeeiiiiiiiioooooooooouuuuuuuuyyyynnccaaeeooppccyyxxiijjssddoieastasi';
begin
  -- Multi-character folds, then the 1:1 confusable map. Separator folding
  -- is the loop below. Combining marks U+0300–U+036F are dropped there
  -- and are not turned into spaces. Kana voicing U+3099/U+309A is kept.
  v := replace(v, 'ß', 'ss');
  v := replace(v, 'æ', 'ae');
  v := replace(v, 'Æ', 'ae');
  v := replace(v, 'œ', 'oe');
  v := replace(v, 'Œ', 'oe');
  v := translate(v, fold_from, fold_to);

  for i in 1..char_length(v) loop
    ch := substr(v, i, 1);
    cp := ascii(ch);

    if cp between 768 and 879 then
      continue;
    end if;

    if cp = 12288 or cp = 32 or cp = 9 or cp = 10 or cp = 13 then
      if v_out <> '' and right(v_out, 1) <> ' ' then
        v_out := v_out || ' ';
      end if;
      continue;
    end if;

    if cp between 65296 and 65305 then
      cp := 48 + (cp - 65296);
    elsif cp between 65313 and 65338 then
      cp := 97 + (cp - 65313);
    elsif cp between 65345 and 65370 then
      cp := 97 + (cp - 65345);
    else
      hw_at := strpos(hw_from, ch);
      if hw_at > 0 then
        ch := substr(hw_to, hw_at, 1);
        cp := ascii(ch);
      end if;
    end if;

    if cp between 12449 and 12531 then
      cp := cp - 96;
    end if;

    if cp between 65 and 90 then
      cp := 97 + (cp - 65);
    end if;

    if cp between 97 and 122
       or cp between 48 and 57
       or cp between 12353 and 12438
       or cp between 12449 and 12538
       or cp between 19968 and 40959
       or cp = 12540 then
      v_out := v_out || chr(cp);
    elsif v_out <> '' and right(v_out, 1) <> ' ' then
      v_out := v_out || ' ';
    end if;
  end loop;

  return btrim(v_out);
end;
$$;

create or replace function public.public_food_name_char_is_word(p_char text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_char is not null
     and (
       ascii(p_char) between 48 and 57
       or ascii(p_char) between 97 and 122
       or ascii(p_char) between 12353 and 12438
       or ascii(p_char) between 12449 and 12538
       or ascii(p_char) between 19968 and 40959
       or ascii(p_char) = 12540
     );
$$;

create or replace function public.public_food_name_contains_term(
  p_name text,
  p_term text
)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_from integer := 1;
  v_at integer;
  v_before text;
  v_after text;
begin
  if p_term is null or p_term = '' or p_name is null or p_name = '' then
    return false;
  end if;

  loop
    v_at := strpos(substr(p_name, v_from), p_term);
    exit when v_at = 0;
    v_at := v_from + v_at - 1;

    if v_at = 1 then
      v_before := null;
    else
      v_before := substr(p_name, v_at - 1, 1);
    end if;

    if v_at + char_length(p_term) > char_length(p_name) then
      v_after := null;
    else
      v_after := substr(p_name, v_at + char_length(p_term), 1);
    end if;

    if (v_before is null or not public.public_food_name_char_is_word(v_before))
       and (v_after is null or not public.public_food_name_char_is_word(v_after)) then
      return true;
    end if;

    v_from := v_at + 1;
  end loop;

  return false;
end;
$$;

create or replace function public.public_food_name_strip_phrase(
  p_name text,
  p_phrase text
)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v text := coalesce(p_name, '');
  v_from integer := 1;
  v_at integer;
  v_before text;
  v_after text;
begin
  if p_phrase is null or p_phrase = '' then
    return v;
  end if;

  loop
    v_at := strpos(substr(v, v_from), p_phrase);
    exit when v_at = 0;
    v_at := v_from + v_at - 1;

    if v_at = 1 then
      v_before := null;
    else
      v_before := substr(v, v_at - 1, 1);
    end if;

    if v_at + char_length(p_phrase) > char_length(v) then
      v_after := null;
    else
      v_after := substr(v, v_at + char_length(p_phrase), 1);
    end if;

    if (v_before is null or not public.public_food_name_char_is_word(v_before))
       and (v_after is null or not public.public_food_name_char_is_word(v_after)) then
      v := substr(v, 1, greatest(v_at - 1, 0))
        || ' '
        || substr(v, v_at + char_length(p_phrase));
      v_from := greatest(v_at, 1);
    else
      v_from := v_at + 1;
    end if;
  end loop;

  return v;
end;
$$;

create or replace function public.public_food_name_term_uses_substring(p_term text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_term !~ '[a-z0-9]'
     and char_length(p_term) >= 2
     and p_term not in (
       -- PUBLIC_FOOD_BOUNDARY_ONLY
       'えろ',
       'くそ',
       'ふぇら',
       'まんこ'
       -- /PUBLIC_FOOD_BOUNDARY_ONLY
     );
$$;

create or replace function public.public_food_name_is_banned(p_name text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_spaced text := public.normalize_public_food_name(p_name);
  v_compact text;
  v_term text;
  v_norm text;
  v_phrase text;
  v_words text[] := array[
    -- PUBLIC_FOOD_BANNED_WORDS
    'fuck',
    'fucking',
    'motherfucker',
    'shit',
    'bullshit',
    'asshole',
    'bitch',
    'bastard',
    'cunt',
    'dick',
    'cock',
    'pussy',
    'whore',
    'slut',
    'nigger',
    'nigga',
    'faggot',
    'retard',
    'rape',
    'くそ',
    'くそったれ',
    'ちくしょう',
    'ちんこ',
    'ちんぽ',
    'まんこ',
    'うんこ',
    'きんたま',
    'ファック',
    'セックス',
    'フェラ',
    '中出し',
    '死ね',
    '殺す',
    'きちがい',
    '池沼',
    'エロ'
    -- /PUBLIC_FOOD_BANNED_WORDS
  ];
  v_phrases text[] := array[
    -- PUBLIC_FOOD_ALLOWED_PHRASES
    'cock tail',
    'rape seed'
    -- /PUBLIC_FOOD_ALLOWED_PHRASES
  ];
begin
  if v_spaced = '' then
    return false;
  end if;

  foreach v_phrase in array v_phrases loop
    v_spaced := public.public_food_name_strip_phrase(v_spaced, v_phrase);
  end loop;
  v_spaced := btrim(regexp_replace(v_spaced, ' +', ' ', 'g'));
  if v_spaced = '' then
    return false;
  end if;
  v_compact := replace(v_spaced, ' ', '');

  foreach v_term in array v_words loop
    v_norm := replace(public.normalize_public_food_name(v_term), ' ', '');
    if v_norm = '' then
      continue;
    end if;

    if public.public_food_name_term_uses_substring(v_norm) then
      if strpos(v_compact, v_norm) > 0 then
        return true;
      end if;
    elsif public.public_food_name_contains_term(v_spaced, v_norm)
       or public.public_food_name_contains_term(v_compact, v_norm) then
      return true;
    end if;
  end loop;

  return false;
end;
$$;

revoke all on function public.compose_halfwidth_voiced(text) from public, anon;
revoke all on function public.normalize_public_food_name(text) from public, anon;
revoke all on function public.public_food_name_char_is_word(text) from public, anon;
revoke all on function public.public_food_name_contains_term(text, text) from public, anon;
revoke all on function public.public_food_name_strip_phrase(text, text) from public, anon;
revoke all on function public.public_food_name_term_uses_substring(text) from public, anon;
revoke all on function public.public_food_name_is_banned(text) from public, anon;

grant execute on function public.compose_halfwidth_voiced(text) to authenticated;
grant execute on function public.normalize_public_food_name(text) to authenticated;
grant execute on function public.public_food_name_char_is_word(text) to authenticated;
grant execute on function public.public_food_name_contains_term(text, text) to authenticated;
grant execute on function public.public_food_name_strip_phrase(text, text) to authenticated;
grant execute on function public.public_food_name_term_uses_substring(text) to authenticated;
grant execute on function public.public_food_name_is_banned(text) to authenticated;

-- Name changes on an already public row. Other columns stay editable.
create or replace function public.validate_saved_foods_public_row()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.visibility <> 'public' or new.visibility <> 'public' then
    return new;
  end if;

  if new.base_amount <= 0 then
    raise exception 'base_amount must be positive';
  end if;

  if btrim(new.name) = '' or btrim(new.normalized_name) = '' then
    raise exception 'name and normalized_name are required';
  end if;

  if new.name is distinct from old.name
     and public.public_food_name_is_banned(new.name) then
    raise exception 'public food name is not allowed';
  end if;

  if new.normalized_name is distinct from old.normalized_name
     and public.public_food_name_is_banned(new.normalized_name) then
    raise exception 'public food name is not allowed';
  end if;

  if new.brand is distinct from old.brand
     and public.public_food_name_is_banned(coalesce(new.brand, '')) then
    raise exception 'public food name is not allowed';
  end if;

  if new.serving_unit_label is distinct from old.serving_unit_label
     and public.public_food_name_is_banned(coalesce(new.serving_unit_label, '')) then
    raise exception 'public food name is not allowed';
  end if;

  if coalesce(new.kcal_per_base, 0) < 0
     or coalesce(new.protein_per_base, 0) < 0
     or coalesce(new.fat_per_base, 0) < 0
     or coalesce(new.carb_per_base, 0) < 0 then
    raise exception 'nutrition values must be non-negative';
  end if;

  if (old.normalized_name, old.base_amount, old.unit_type)
     is distinct from (new.normalized_name, new.base_amount, new.unit_type)
     and exists (
       select 1
       from public.saved_foods sf
       where sf.visibility = 'public'
         and sf.status = 'active'
         and sf.deleted_at is null
         and sf.normalized_name = new.normalized_name
         and sf.unit_type = new.unit_type
         and sf.base_amount = new.base_amount
         and not (sf.user_id = new.user_id and sf.food_id = new.food_id)
     ) then
    raise exception 'duplicate public food exists';
  end if;

  return new;
end;
$$;

create or replace function public.publish_saved_food(p_food_id text)
returns public.saved_foods
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid := auth.uid();
  v_row public.saved_foods%rowtype;
begin
  if v_owner is null then
    raise exception 'not authenticated';
  end if;

  select * into v_row
  from public.saved_foods
  where user_id = v_owner and food_id = p_food_id
  for update;

  if not found then
    raise exception 'food not found';
  end if;

  if v_row.visibility = 'public' then
    raise exception 'food is already public';
  end if;

  if v_row.status <> 'active' or v_row.deleted_at is not null then
    raise exception 'food is not publishable';
  end if;

  if v_row.moderation_status not in ('none', 'reported', 'under_review') then
    raise exception 'moderation_status blocks publish';
  end if;

  if v_row.base_amount <= 0 then
    raise exception 'base_amount must be positive';
  end if;

  if v_row.unit_type not in ('g', 'ml', 'piece', 'serving') then
    raise exception 'invalid unit_type';
  end if;

  if btrim(v_row.name) = '' or btrim(v_row.normalized_name) = '' then
    raise exception 'name and normalized_name are required';
  end if;

  if public.public_food_name_is_banned(v_row.name)
     or public.public_food_name_is_banned(v_row.normalized_name)
     or public.public_food_name_is_banned(coalesce(v_row.brand, ''))
     or public.public_food_name_is_banned(coalesce(v_row.serving_unit_label, '')) then
    raise exception 'public food name is not allowed';
  end if;

  if coalesce(v_row.kcal_per_base, 0) < 0
     or coalesce(v_row.protein_per_base, 0) < 0
     or coalesce(v_row.fat_per_base, 0) < 0
     or coalesce(v_row.carb_per_base, 0) < 0 then
    raise exception 'nutrition values must be non-negative';
  end if;

  if exists (
    select 1
    from public.saved_foods sf
    where sf.visibility = 'public'
      and sf.status = 'active'
      and sf.deleted_at is null
      and sf.normalized_name = v_row.normalized_name
      and sf.unit_type = v_row.unit_type
      and sf.base_amount = v_row.base_amount
      and not (sf.user_id = v_row.user_id and sf.food_id = v_row.food_id)
  ) then
    raise exception 'duplicate public food exists';
  end if;

  -- Step 4: lock buckets and verify headroom (no increment yet).
  perform public.ensure_publish_rate_limit_headroom(v_owner);

  -- Step 5: publicize (any failure rolls back the whole transaction).
  perform set_config('ayg.allow_saved_food_publish', 'on', true);

  update public.saved_foods
  set visibility = 'public'
  where user_id = v_owner and food_id = p_food_id
  returning * into v_row;

  if not found then
    raise exception 'visibility update failed';
  end if;

  -- Step 4 (count update): only after successful publicization.
  perform public.increment_publish_rate_limit(v_owner);

  return v_row;
end;
$$;
