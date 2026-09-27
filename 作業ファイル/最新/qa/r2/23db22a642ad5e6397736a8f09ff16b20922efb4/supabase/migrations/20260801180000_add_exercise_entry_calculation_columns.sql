-- Exercise entry calculation columns (local validation only — do not apply to production)
-- Rollback: alter table drop column (each nullable column independently)

alter table public.exercise_entries
  add column if not exists category_key text,
  add column if not exists activity_id text,
  add column if not exists intensity text,
  add column if not exists sets integer check (sets is null or sets >= 0),
  add column if not exists reps integer check (reps is null or reps >= 0),
  add column if not exists lift_weight_kg double precision
    check (lift_weight_kg is null or lift_weight_kg >= 0),
  add column if not exists met_value double precision
    check (met_value is null or met_value > 0),
  add column if not exists gross_kcal double precision
    check (gross_kcal is null or gross_kcal >= 0),
  add column if not exists net_kcal double precision
    check (net_kcal is null or net_kcal >= 0),
  add column if not exists weight_kg_snapshot double precision
    check (weight_kg_snapshot is null or weight_kg_snapshot > 0),
  add column if not exists calculation_source text
    check (calculation_source is null or calculation_source in (
      'met_estimate', 'manual_override', 'template'
    )),
  add column if not exists calculation_version text,
  add column if not exists source_key text,
  add column if not exists notes text;

create index if not exists exercise_entries_logged_at_user_idx
  on public.exercise_entries (user_id, logged_at desc);

create index if not exists exercise_entries_activity_id_idx
  on public.exercise_entries (user_id, activity_id)
  where activity_id is not null;
