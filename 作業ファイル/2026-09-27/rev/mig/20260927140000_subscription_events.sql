-- First-time subscription metrics. Rows store only user_id, event_type, and
-- a server timestamp. No food names, measurements, purchase proof, or free text.
--
-- Authenticated clients may insert their own row. They cannot select, update,
-- or delete. Counts are available to the service role through
-- public.subscription_event_counts().

begin;

create table if not exists public.subscription_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.users (id) on delete cascade,
  event_type text not null check (
    event_type in ('free_limit_hit', 'converted_to_paid')
  ),
  created_at timestamptz not null default timezone('utc', now()),
  unique (user_id, event_type)
);

create index if not exists subscription_events_event_type_idx
  on public.subscription_events (event_type);

create or replace function public.subscription_events_force_row()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.event_type not in ('free_limit_hit', 'converted_to_paid') then
    raise exception 'invalid subscription event';
  end if;

  if auth.uid() is not null and new.user_id is distinct from auth.uid() then
    raise exception 'subscription event user mismatch';
  end if;

  new.created_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists subscription_events_force_row on public.subscription_events;
create trigger subscription_events_force_row
  before insert on public.subscription_events
  for each row execute function public.subscription_events_force_row();

alter table public.subscription_events enable row level security;

drop policy if exists "subscription_events_insert_own" on public.subscription_events;
create policy "subscription_events_insert_own"
  on public.subscription_events
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

revoke all on table public.subscription_events from public, anon, authenticated;
grant insert on table public.subscription_events to authenticated;
grant select on table public.subscription_events to service_role;

create or replace function public.subscription_event_counts()
returns table (event_type text, user_count bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  jwt_role text := coalesce(current_setting('request.jwt.claim.role', true), '');
begin
  if jwt_role is distinct from 'service_role'
     and session_user not in ('postgres', 'supabase_admin') then
    raise exception 'subscription_event_counts is restricted to admins';
  end if;

  return query
    select e.event_type, count(distinct e.user_id)::bigint
    from public.subscription_events e
    group by e.event_type;
end;
$$;

revoke all on function public.subscription_events_force_row()
  from public, anon, authenticated;
revoke all on function public.subscription_event_counts()
  from public, anon, authenticated;
grant execute on function public.subscription_event_counts() to service_role;

commit;
