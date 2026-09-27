-- Add free-text serving unit label for saved_foods.
-- Quantity continues to use existing base_amount (NOT NULL).
-- Legacy rows keep serving_unit_label NULL and display as "基準量未設定".

begin;

alter table public.saved_foods
  add column if not exists serving_unit_label text;

comment on column public.saved_foods.serving_unit_label is
  'User-facing base unit label (e.g. g, 食, 缶). NULL means legacy/unset.';

commit;
