-- AYG v1.1 schema
-- Matches lib/repositories/data_sync_repository.dart upsert/select columns.

-- ---------------------------------------------------------------------------
-- users (id = auth.users.id)
-- ---------------------------------------------------------------------------
create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists users_created_at_idx on public.users (created_at);

-- ---------------------------------------------------------------------------
-- profiles (conflict: user_id)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  user_id uuid primary key references public.users (id) on delete cascade,
  birth_date timestamptz not null,
  gender text not null check (gender in ('male', 'female', 'other')),
  height_cm double precision not null,
  weight_kg double precision not null,
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists profiles_user_id_idx on public.profiles (user_id);

-- ---------------------------------------------------------------------------
-- goals (conflict: user_id)
-- ---------------------------------------------------------------------------
create table if not exists public.goals (
  user_id uuid primary key references public.users (id) on delete cascade,
  goal_type text not null check (goal_type in ('lose', 'maintain', 'gain')),
  target_weight_kg double precision not null,
  target_date timestamptz not null,
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists goals_user_id_idx on public.goals (user_id);

-- ---------------------------------------------------------------------------
-- nutrition_settings (conflict: user_id)
-- ---------------------------------------------------------------------------
create table if not exists public.nutrition_settings (
  user_id uuid primary key references public.users (id) on delete cascade,
  use_health_integration boolean not null default false,
  activity_level text check (
    activity_level is null
    or activity_level in ('low', 'light', 'moderate', 'high', 'veryHigh')
  ),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists nutrition_settings_user_id_idx
  on public.nutrition_settings (user_id);

-- ---------------------------------------------------------------------------
-- health_snapshots (conflict: user_id)
-- ---------------------------------------------------------------------------
create table if not exists public.health_snapshots (
  user_id uuid primary key references public.users (id) on delete cascade,
  active_energy_burned_kcal double precision,
  weight_kg double precision,
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists health_snapshots_user_id_idx
  on public.health_snapshots (user_id);

-- ---------------------------------------------------------------------------
-- app_settings (conflict: user_id)
-- ---------------------------------------------------------------------------
create table if not exists public.app_settings (
  user_id uuid primary key references public.users (id) on delete cascade,
  onboarding_complete boolean not null default false,
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists app_settings_user_id_idx on public.app_settings (user_id);

-- ---------------------------------------------------------------------------
-- food_entries (conflict: user_id, entry_id)
-- ---------------------------------------------------------------------------
create table if not exists public.food_entries (
  user_id uuid not null references public.users (id) on delete cascade,
  entry_id text not null,
  name text not null,
  kcal_per_unit double precision,
  protein_per_unit double precision,
  fat_per_unit double precision,
  carb_per_unit double precision,
  quantity double precision not null,
  logged_at timestamptz not null,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, entry_id)
);

create index if not exists food_entries_user_id_idx on public.food_entries (user_id);
create index if not exists food_entries_logged_at_idx on public.food_entries (logged_at desc);

-- ---------------------------------------------------------------------------
-- exercise_entries (conflict: user_id, entry_id)
-- ---------------------------------------------------------------------------
create table if not exists public.exercise_entries (
  user_id uuid not null references public.users (id) on delete cascade,
  entry_id text not null,
  name text not null,
  duration_min integer not null,
  burned_kcal double precision not null,
  logged_at timestamptz not null,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, entry_id)
);

create index if not exists exercise_entries_user_id_idx
  on public.exercise_entries (user_id);
create index if not exists exercise_entries_logged_at_idx
  on public.exercise_entries (logged_at desc);

-- ---------------------------------------------------------------------------
-- weight_entries (conflict: user_id, entry_id)
-- ---------------------------------------------------------------------------
create table if not exists public.weight_entries (
  user_id uuid not null references public.users (id) on delete cascade,
  entry_id text not null,
  weight_kg double precision not null,
  recorded_at timestamptz not null,
  source text not null check (source in ('health', 'manual')),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, entry_id)
);

create index if not exists weight_entries_user_id_idx on public.weight_entries (user_id);
create index if not exists weight_entries_recorded_at_idx
  on public.weight_entries (recorded_at desc);

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles',
    'goals',
    'nutrition_settings',
    'health_snapshots',
    'app_settings',
    'food_entries',
    'exercise_entries',
    'weight_entries'
  ]
  loop
    execute format('drop trigger if exists set_%I_updated_at on public.%I', t, t);
    execute format(
      'create trigger set_%I_updated_at before update on public.%I
       for each row execute function public.set_updated_at()',
      t,
      t
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.users enable row level security;
alter table public.profiles enable row level security;
alter table public.goals enable row level security;
alter table public.nutrition_settings enable row level security;
alter table public.health_snapshots enable row level security;
alter table public.app_settings enable row level security;
alter table public.food_entries enable row level security;
alter table public.exercise_entries enable row level security;
alter table public.weight_entries enable row level security;

-- users: id = auth.uid()
drop policy if exists "users_select_own" on public.users;
create policy "users_select_own"
  on public.users for select
  using ((select auth.uid()) = id);

drop policy if exists "users_insert_own" on public.users;
create policy "users_insert_own"
  on public.users for insert
  with check ((select auth.uid()) = id);

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own"
  on public.users for update
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "users_delete_own" on public.users;
create policy "users_delete_own"
  on public.users for delete
  using ((select auth.uid()) = id);

-- shared policy helper pattern for user_id tables
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using ((select auth.uid()) = user_id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own"
  on public.profiles for delete
  using ((select auth.uid()) = user_id);

drop policy if exists "goals_select_own" on public.goals;
create policy "goals_select_own"
  on public.goals for select
  using ((select auth.uid()) = user_id);

drop policy if exists "goals_insert_own" on public.goals;
create policy "goals_insert_own"
  on public.goals for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "goals_update_own" on public.goals;
create policy "goals_update_own"
  on public.goals for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "goals_delete_own" on public.goals;
create policy "goals_delete_own"
  on public.goals for delete
  using ((select auth.uid()) = user_id);

drop policy if exists "nutrition_settings_select_own" on public.nutrition_settings;
create policy "nutrition_settings_select_own"
  on public.nutrition_settings for select
  using ((select auth.uid()) = user_id);

drop policy if exists "nutrition_settings_insert_own" on public.nutrition_settings;
create policy "nutrition_settings_insert_own"
  on public.nutrition_settings for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "nutrition_settings_update_own" on public.nutrition_settings;
create policy "nutrition_settings_update_own"
  on public.nutrition_settings for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "nutrition_settings_delete_own" on public.nutrition_settings;
create policy "nutrition_settings_delete_own"
  on public.nutrition_settings for delete
  using ((select auth.uid()) = user_id);

drop policy if exists "health_snapshots_select_own" on public.health_snapshots;
create policy "health_snapshots_select_own"
  on public.health_snapshots for select
  using ((select auth.uid()) = user_id);

drop policy if exists "health_snapshots_insert_own" on public.health_snapshots;
create policy "health_snapshots_insert_own"
  on public.health_snapshots for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "health_snapshots_update_own" on public.health_snapshots;
create policy "health_snapshots_update_own"
  on public.health_snapshots for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "health_snapshots_delete_own" on public.health_snapshots;
create policy "health_snapshots_delete_own"
  on public.health_snapshots for delete
  using ((select auth.uid()) = user_id);

drop policy if exists "app_settings_select_own" on public.app_settings;
create policy "app_settings_select_own"
  on public.app_settings for select
  using ((select auth.uid()) = user_id);

drop policy if exists "app_settings_insert_own" on public.app_settings;
create policy "app_settings_insert_own"
  on public.app_settings for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "app_settings_update_own" on public.app_settings;
create policy "app_settings_update_own"
  on public.app_settings for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "app_settings_delete_own" on public.app_settings;
create policy "app_settings_delete_own"
  on public.app_settings for delete
  using ((select auth.uid()) = user_id);

drop policy if exists "food_entries_select_own" on public.food_entries;
create policy "food_entries_select_own"
  on public.food_entries for select
  using ((select auth.uid()) = user_id);

drop policy if exists "food_entries_insert_own" on public.food_entries;
create policy "food_entries_insert_own"
  on public.food_entries for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "food_entries_update_own" on public.food_entries;
create policy "food_entries_update_own"
  on public.food_entries for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "food_entries_delete_own" on public.food_entries;
create policy "food_entries_delete_own"
  on public.food_entries for delete
  using ((select auth.uid()) = user_id);

drop policy if exists "exercise_entries_select_own" on public.exercise_entries;
create policy "exercise_entries_select_own"
  on public.exercise_entries for select
  using ((select auth.uid()) = user_id);

drop policy if exists "exercise_entries_insert_own" on public.exercise_entries;
create policy "exercise_entries_insert_own"
  on public.exercise_entries for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "exercise_entries_update_own" on public.exercise_entries;
create policy "exercise_entries_update_own"
  on public.exercise_entries for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "exercise_entries_delete_own" on public.exercise_entries;
create policy "exercise_entries_delete_own"
  on public.exercise_entries for delete
  using ((select auth.uid()) = user_id);

drop policy if exists "weight_entries_select_own" on public.weight_entries;
create policy "weight_entries_select_own"
  on public.weight_entries for select
  using ((select auth.uid()) = user_id);

drop policy if exists "weight_entries_insert_own" on public.weight_entries;
create policy "weight_entries_insert_own"
  on public.weight_entries for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "weight_entries_update_own" on public.weight_entries;
create policy "weight_entries_update_own"
  on public.weight_entries for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "weight_entries_delete_own" on public.weight_entries;
create policy "weight_entries_delete_own"
  on public.weight_entries for delete
  using ((select auth.uid()) = user_id);
