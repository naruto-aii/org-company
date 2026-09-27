-- Version 1.1: saved_foods.version for public food content revisions.
-- Past FoodEntry snapshots are not updated; version is for future compatibility.

begin;

alter table public.saved_foods
  add column version integer not null default 1
    check (version >= 1);

comment on column public.saved_foods.version is
  'Incremented when public food user-facing fields change (name, base, unit, macros). V1.1 keeps current row only.';

commit;
