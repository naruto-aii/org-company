-- Workout templates (local validation only — do not apply to production without review)
-- Rollback: drop policies, revoke grants, drop tables in reverse order.

create table if not exists public.workout_templates (
  user_id uuid not null references public.users (id) on delete cascade,
  template_id text not null,
  name text not null,
  normalized_name text not null,
  status text not null default 'active'
    check (status in ('active', 'deleted')),
  use_count integer not null default 0 check (use_count >= 0),
  last_used_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  primary key (user_id, template_id)
);

create index if not exists workout_templates_user_id_idx
  on public.workout_templates (user_id);

create table if not exists public.workout_template_items (
  user_id uuid not null references public.users (id) on delete cascade,
  item_id text not null,
  template_id text not null,
  name text not null,
  activity_id text,
  category_key text,
  intensity text,
  duration_min integer not null check (duration_min > 0),
  sets integer check (sets is null or sets >= 0),
  reps integer check (reps is null or reps >= 0),
  lift_weight_kg double precision check (lift_weight_kg is null or lift_weight_kg >= 0),
  sort_order integer not null default 0,
  notes text,
  met_value double precision check (met_value is null or met_value > 0),
  source_key text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, item_id),
  foreign key (user_id, template_id)
    references public.workout_templates (user_id, template_id)
    on delete cascade
);

create index if not exists workout_template_items_template_idx
  on public.workout_template_items (user_id, template_id);

alter table public.workout_templates enable row level security;
alter table public.workout_template_items enable row level security;

drop policy if exists workout_templates_own on public.workout_templates;
create policy workout_templates_own on public.workout_templates
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists workout_template_items_own on public.workout_template_items;
create policy workout_template_items_own on public.workout_template_items
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke all on public.workout_templates from anon;
revoke all on public.workout_template_items from anon;

grant select, insert, update, delete on public.workout_templates to authenticated;
grant select, insert, update, delete on public.workout_template_items to authenticated;
