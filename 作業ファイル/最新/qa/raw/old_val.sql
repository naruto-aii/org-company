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
