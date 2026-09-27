  return coalesce(v_count, 0);
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

-- ---------------------------------------------------------------------------
