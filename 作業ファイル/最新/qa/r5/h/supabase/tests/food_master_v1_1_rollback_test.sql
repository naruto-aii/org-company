-- Rollback verification (local only). Confirms legacy food_entries columns survive teardown.
-- Run AFTER applying rollback steps from migration footer comments manually, or use this subset test.

do $$
declare
  v_legacy_quantity double precision;
begin
  select quantity into v_legacy_quantity
  from public.food_entries
  where entry_id = 'legacy-entry-1';

  if v_legacy_quantity is null then
    raise exception 'legacy food_entries row missing — rollback must not delete existing rows';
  end if;

  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'saved_foods'
  ) then
    raise notice 'saved_foods still exists (rollback not applied in this check)';
  else
    raise notice 'saved_foods removed — rollback step confirmed';
  end if;

  raise notice 'ROLLBACK CHECK PASSED (legacy food_entries preserved)';
end;
$$;
