-- alcohol_entries: dedicated table for alcohol records (separate from food_entries).

create table if not exists public.alcohol_entries (
  user_id uuid not null references public.users (id) on delete cascade,
  entry_id text not null,
  beverage_name text not null check (char_length(trim(beverage_name)) > 0),
  amount double precision not null check (amount > 0),
  unit text not null check (char_length(trim(unit)) > 0),
  alcohol_percentage double precision not null
    check (alcohol_percentage >= 0 and alcohol_percentage <= 100),
  total_calories double precision not null check (total_calories >= 0),
  pure_alcohol_grams double precision not null check (pure_alcohol_grams >= 0),
  alcohol_calories double precision not null check (alcohol_calories >= 0),
  consumed_at timestamptz not null,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, entry_id)
);

create index if not exists alcohol_entries_user_id_idx
  on public.alcohol_entries (user_id);
create index if not exists alcohol_entries_consumed_at_idx
  on public.alcohol_entries (consumed_at desc);

drop trigger if exists set_alcohol_entries_updated_at on public.alcohol_entries;
create trigger set_alcohol_entries_updated_at
  before update on public.alcohol_entries
  for each row execute function public.set_updated_at();

alter table public.alcohol_entries enable row level security;

drop policy if exists "alcohol_entries_select_own" on public.alcohol_entries;
create policy "alcohol_entries_select_own"
  on public.alcohol_entries for select
  using ((select auth.uid()) = user_id);

drop policy if exists "alcohol_entries_insert_own" on public.alcohol_entries;
create policy "alcohol_entries_insert_own"
  on public.alcohol_entries for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "alcohol_entries_update_own" on public.alcohol_entries;
create policy "alcohol_entries_update_own"
  on public.alcohol_entries for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "alcohol_entries_delete_own" on public.alcohol_entries;
create policy "alcohol_entries_delete_own"
  on public.alcohol_entries for delete
  using ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.alcohol_entries to authenticated;
