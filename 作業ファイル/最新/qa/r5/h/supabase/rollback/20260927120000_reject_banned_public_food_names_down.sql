-- Down for 20260927120000_reject_banned_public_food_names.sql.
-- Not under supabase/migrations, so `db push` does not apply it.
-- Full down-order: supabase/rollback/README.md. Run this last.
-- Restores validate_saved_foods_public_row and publish_saved_food to the
-- bodies from 20260723120000_add_food_master_public_v1_1.sql.
-- Does not drop the validate_saved_foods_public_row trigger.
-- Then drops the banned-name helper functions.

begin;

create or replace function public.validate_saved_foods_public_row()
returns trigger
language plpgsql
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

revoke all on function public.publish_saved_food(text) from public;
grant execute on function public.publish_saved_food(text) to authenticated;

drop function if exists public.public_food_name_is_banned(text);
drop function if exists public.public_food_name_term_uses_substring(text);
drop function if exists public.public_food_name_strip_phrase(text, text);
drop function if exists public.public_food_name_contains_term(text, text);
drop function if exists public.public_food_name_char_is_word(text);
drop function if exists public.normalize_public_food_name(text);
drop function if exists public.compose_halfwidth_voiced(text);

commit;
