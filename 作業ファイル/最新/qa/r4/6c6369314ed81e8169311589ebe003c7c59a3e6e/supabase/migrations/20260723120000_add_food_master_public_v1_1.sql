-- AYG v1.1 — Food Master (App Store UGC minimum)
--   saved_foods, food_reports, blocked_food_creators
--   food_ratings, food_rating_stats
--   meal_templates, meal_template_items, food_entries extension
--
-- Public visibility: RLS Policy (Option A) excludes blocked creators for search + detail.
-- Rating rate limit: direct RLS in V1.1; see Decision Log for V1.2 advanced limits.
-- Local/staging only. Do NOT run on production without Owner approval.

begin;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.is_saved_food_publicly_visible(
  p_visibility text,
  p_status text,
  p_deleted_at timestamptz,
  p_moderation_status text
)
returns boolean
language sql
immutable
as $$
  select
    p_visibility = 'public'
    and p_status = 'active'
    and p_deleted_at is null
    and p_moderation_status in ('none', 'reported', 'under_review');
$$;

create or replace function public.is_saved_food_reportable(
  p_visibility text,
  p_status text,
  p_deleted_at timestamptz
)
returns boolean
language sql
immutable
as $$
  select
    p_visibility = 'public'
    and p_status = 'active'
    and p_deleted_at is null;
$$;

-- ---------------------------------------------------------------------------
-- saved_foods
-- ---------------------------------------------------------------------------

create table public.saved_foods (
  user_id uuid not null references public.users (id) on delete cascade,
  food_id text not null,
  visibility text not null default 'private'
    check (visibility in ('private', 'public', 'unlisted')),
  status text not null default 'active'
    check (status in ('active', 'deleted', 'suspended')),
  moderation_status text not null default 'none'
    check (moderation_status in ('none', 'reported', 'under_review', 'hidden', 'suspended')),
  name text not null,
  normalized_name text not null,
  base_amount numeric(12, 4) not null check (base_amount > 0),
  unit_type text not null
    check (unit_type in ('g', 'ml', 'piece', 'serving')),
  kcal_per_base double precision,
  protein_per_base double precision,
  fat_per_base double precision,
  carb_per_base double precision,
  source_type text not null default 'manual'
    check (source_type in ('manual', 'open_food_facts', 'open_food_facts_derived', 'copied')),
  barcode text,
  brand text,
  supplementary_weight text,
  copied_from_food_id text,
  copied_from_owner_user_id uuid references public.users (id) on delete set null,
  use_count integer not null default 0 check (use_count >= 0),
  last_used_at timestamptz,
  report_count integer not null default 0 check (report_count >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  primary key (user_id, food_id)
);

create index saved_foods_user_id_idx on public.saved_foods (user_id);
create index saved_foods_normalized_name_idx on public.saved_foods (normalized_name);
create index saved_foods_visibility_status_idx
  on public.saved_foods (visibility, status)
  where deleted_at is null;

create unique index saved_foods_public_dedup_idx
  on public.saved_foods (normalized_name, unit_type, base_amount)
  where visibility = 'public'
    and status = 'active'
    and deleted_at is null;

-- ---------------------------------------------------------------------------
-- meal_templates (V1.1 private only)
-- ---------------------------------------------------------------------------

create table public.meal_templates (
  user_id uuid not null references public.users (id) on delete cascade,
  template_id text not null,
  name text not null,
  normalized_name text not null,
  visibility text not null default 'private'
    check (visibility in ('private', 'public', 'unlisted')),
  status text not null default 'active'
    check (status in ('active', 'deleted')),
  total_kcal double precision not null default 0,
  total_protein_g double precision not null default 0,
  total_fat_g double precision not null default 0,
  total_carb_g double precision not null default 0,
  dependency_status text not null default 'ok'
    check (dependency_status in ('ok', 'has_unavailable_items', 'needs_review')),
  last_validated_at timestamptz,
  use_count integer not null default 0 check (use_count >= 0),
  last_used_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  primary key (user_id, template_id),
  check (visibility = 'private')
);

create index meal_templates_user_id_idx on public.meal_templates (user_id);
create index meal_templates_normalized_name_idx on public.meal_templates (normalized_name);

-- ---------------------------------------------------------------------------
-- meal_template_items
-- ---------------------------------------------------------------------------

create table public.meal_template_items (
  user_id uuid not null references public.users (id) on delete cascade,
  item_id text not null,
  template_id text not null,
  saved_food_id text,
  source_owner_user_id uuid,
  name text not null,
  base_amount numeric(12, 4) not null check (base_amount > 0),
  unit_type text not null
    check (unit_type in ('g', 'ml', 'piece', 'serving')),
  kcal_per_base double precision,
  protein_per_base double precision,
  fat_per_base double precision,
  carb_per_base double precision,
  consumed_amount numeric(12, 4) not null check (consumed_amount > 0),
  sort_order integer not null default 0,
  item_dependency_status text not null default 'available'
    check (item_dependency_status in (
      'available', 'source_deleted', 'source_hidden', 'source_changed'
    )),
  snapshot_saved_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, item_id),
  foreign key (user_id, template_id)
    references public.meal_templates (user_id, template_id)
    on delete cascade,
  foreign key (source_owner_user_id, saved_food_id)
    references public.saved_foods (user_id, food_id)
    on delete set null
);

create index meal_template_items_template_idx
  on public.meal_template_items (user_id, template_id);

create index meal_template_items_sort_idx
  on public.meal_template_items (user_id, template_id, sort_order);

-- ---------------------------------------------------------------------------
-- food_ratings
-- ---------------------------------------------------------------------------

create table public.food_ratings (
  rating_id text primary key,
  food_owner_user_id uuid not null,
  food_id text not null,
  rater_user_id uuid not null references public.users (id) on delete cascade,
  rating_type text not null check (rating_type in ('good', 'bad')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (rater_user_id, food_owner_user_id, food_id),
  check (rater_user_id <> food_owner_user_id),
  foreign key (food_owner_user_id, food_id)
    references public.saved_foods (user_id, food_id)
    on delete cascade
);

create index food_ratings_food_idx
  on public.food_ratings (food_owner_user_id, food_id);

create index food_ratings_rater_idx
  on public.food_ratings (rater_user_id);

-- ---------------------------------------------------------------------------
-- food_rating_stats
-- ---------------------------------------------------------------------------

create table public.food_rating_stats (
  food_owner_user_id uuid not null,
  food_id text not null,
  good_count integer not null default 0 check (good_count >= 0),
  bad_count integer not null default 0 check (bad_count >= 0),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (food_owner_user_id, food_id),
  foreign key (food_owner_user_id, food_id)
    references public.saved_foods (user_id, food_id)
    on delete cascade
);

-- ---------------------------------------------------------------------------
-- food_reports
-- ---------------------------------------------------------------------------

create table public.food_reports (
  report_id text primary key,
  reporter_user_id uuid not null references public.users (id) on delete cascade,
  target_food_owner_user_id uuid not null,
  target_food_id text not null,
  reason_code text not null
    check (reason_code in (
      'incorrect_nutrition',
      'inappropriate_name',
      'duplicate',
      'spam',
      'intellectual_property',
      'other'
    )),
  detail_text text check (detail_text is null or char_length(detail_text) <= 2000),
  status text not null default 'pending'
    check (status in ('pending', 'under_review', 'resolved', 'dismissed')),
  created_at timestamptz not null default timezone('utc', now()),
  reviewed_at timestamptz,
  reviewed_by uuid references public.users (id) on delete set null,
  resolution_note text check (resolution_note is null or char_length(resolution_note) <= 2000),
  unique (reporter_user_id, target_food_owner_user_id, target_food_id),
  check (reporter_user_id <> target_food_owner_user_id),
  foreign key (target_food_owner_user_id, target_food_id)
    references public.saved_foods (user_id, food_id)
    on delete cascade
);

create index food_reports_target_idx
  on public.food_reports (target_food_owner_user_id, target_food_id);

create index food_reports_reporter_idx
  on public.food_reports (reporter_user_id);

-- ---------------------------------------------------------------------------
-- blocked_food_creators
-- ---------------------------------------------------------------------------

create table public.blocked_food_creators (
  blocker_user_id uuid not null references public.users (id) on delete cascade,
  blocked_user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (blocker_user_id, blocked_user_id),
  check (blocker_user_id <> blocked_user_id)
);

create index blocked_food_creators_blocker_idx
  on public.blocked_food_creators (blocker_user_id);

-- Publish rate-limit buckets (RPC-only writes; not used for private saves).
create table public.rate_limit_buckets (
  user_id uuid not null references public.users (id) on delete cascade,
  bucket_key text not null,
  operation_count integer not null default 0 check (operation_count >= 0),
  window_expires_at timestamptz not null,
  primary key (user_id, bucket_key)
);

create index rate_limit_buckets_expires_idx
  on public.rate_limit_buckets (window_expires_at);

-- Owner Decision (2026-07-23): 10 publishes/hour/user, 30 publishes/day/user.
-- Applies to publish_saved_food() only — private saves are not rate-limited.
create or replace function public.get_publish_rate_limits()
returns table (hourly_limit integer, daily_limit integer)
language sql
immutable
as $$
  select 10, 30;
$$;

-- Option A: block exclusion in RLS (search + ID detail share one policy).
create or replace function public.is_saved_food_visible_to_viewer(p_owner_user_id uuid)
returns boolean
language sql
stable
as $$
  select
    (select auth.uid()) is null
    or p_owner_user_id = (select auth.uid())
    or not exists (
      select 1
      from public.blocked_food_creators b
      where b.blocker_user_id = (select auth.uid())
        and b.blocked_user_id = p_owner_user_id
    );
$$;

-- ---------------------------------------------------------------------------
-- food_entries extension
-- ---------------------------------------------------------------------------

alter table public.food_entries
  add column base_amount numeric(12, 4)
    check (base_amount is null or base_amount > 0);

alter table public.food_entries
  add column unit_type text
    check (unit_type is null or unit_type in ('g', 'ml', 'piece', 'serving'));

alter table public.food_entries
  add column consumed_amount numeric(12, 4)
    check (consumed_amount is null or consumed_amount > 0);

alter table public.food_entries
  add column source_type text
    check (source_type is null or source_type in (
      'manual', 'saved_food', 'template', 'open_food_facts'
    ));

alter table public.food_entries add column saved_food_id text;
alter table public.food_entries add column source_food_owner_user_id uuid;
alter table public.food_entries add column meal_group_id text;
alter table public.food_entries add column meal_group_name text;
alter table public.food_entries add column sort_order integer;

-- ---------------------------------------------------------------------------
-- saved_foods admin-column protection
-- ---------------------------------------------------------------------------

create or replace function public.enforce_saved_foods_owner_mutation()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role' then
    return new;
  end if;

  if coalesce(current_setting('ayg.allow_report_count_sync', true), '') = 'on' then
    if tg_op = 'UPDATE'
       and new.report_count is distinct from old.report_count
       and new.moderation_status is not distinct from old.moderation_status
       and new.status is not distinct from old.status then
      return new;
    end if;
  end if;

  if tg_op = 'INSERT' then
    new.moderation_status := 'none';
    new.report_count := 0;
    if new.status not in ('active', 'deleted') then
      new.status := 'active';
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.moderation_status is distinct from old.moderation_status then
      raise exception 'moderation_status is admin-only';
    end if;
    if new.report_count is distinct from old.report_count then
      raise exception 'report_count is admin-only';
    end if;
    if new.status = 'suspended' and old.status is distinct from 'suspended' then
      raise exception 'status suspended is admin-only';
    end if;
    return new;
  end if;

  return new;
end;
$$;

create trigger enforce_saved_foods_owner_mutation
  before insert or update on public.saved_foods
  for each row execute function public.enforce_saved_foods_owner_mutation();

-- Block direct publicization and INSERT-as-public (must use publish_saved_food RPC).
create or replace function public.enforce_saved_foods_visibility_path()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role' then
    return new;
  end if;

  if coalesce(current_setting('ayg.allow_saved_food_publish', true), '') = 'on' then
    return new;
  end if;

  if tg_op = 'INSERT' and new.visibility = 'public' then
    raise exception 'public visibility requires publish_saved_food rpc';
  end if;

  if tg_op = 'UPDATE'
     and new.visibility = 'public'
     and old.visibility is distinct from 'public' then
    raise exception 'public visibility requires publish_saved_food rpc';
  end if;

  return new;
end;
$$;

create trigger enforce_saved_foods_visibility_path
  before insert or update on public.saved_foods
  for each row execute function public.enforce_saved_foods_visibility_path();

-- Option A for published-food edits: allow owner UPDATE with DB revalidation.
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

create trigger validate_saved_foods_public_row
  before update on public.saved_foods
  for each row execute function public.validate_saved_foods_public_row();

create or replace function public.publish_rate_limit_bucket_keys()
returns table (hour_key text, day_key text)
language sql
stable
as $$
  select
    'publish:hour:' || to_char(timezone('utc', clock_timestamp()), 'YYYY-MM-DD HH24'),
    'publish:day:' || to_char(timezone('utc', clock_timestamp()), 'YYYY-MM-DD');
$$;

create or replace function public.ensure_publish_rate_limit_headroom(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hour_key text;
  v_day_key text;
  v_hour_limit integer;
  v_day_limit integer;
  v_hour_count integer;
  v_day_count integer;
begin
  select hourly_limit, daily_limit
  into v_hour_limit, v_day_limit
  from public.get_publish_rate_limits();

  select hour_key, day_key
  into v_hour_key, v_day_key
  from public.publish_rate_limit_bucket_keys();

  insert into public.rate_limit_buckets (user_id, bucket_key, operation_count, window_expires_at)
  values
    (
      p_user_id,
      v_hour_key,
      0,
      date_trunc('hour', timezone('utc', clock_timestamp())) + interval '1 hour'
    ),
    (
      p_user_id,
      v_day_key,
      0,
      date_trunc('day', timezone('utc', clock_timestamp())) + interval '1 day'
    )
  on conflict (user_id, bucket_key) do nothing;

  select operation_count into v_hour_count
  from public.rate_limit_buckets
  where user_id = p_user_id and bucket_key = v_hour_key
  for update;

  select operation_count into v_day_count
  from public.rate_limit_buckets
  where user_id = p_user_id and bucket_key = v_day_key
  for update;

  if v_hour_count >= v_hour_limit then
    raise exception 'hourly publish rate limit exceeded';
  end if;

  if v_day_count >= v_day_limit then
    raise exception 'daily publish rate limit exceeded';
  end if;
end;
$$;

create or replace function public.increment_publish_rate_limit(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hour_key text;
  v_day_key text;
begin
  select hour_key, day_key
  into v_hour_key, v_day_key
  from public.publish_rate_limit_bucket_keys();

  update public.rate_limit_buckets
  set operation_count = operation_count + 1
  where user_id = p_user_id and bucket_key = v_hour_key;

  update public.rate_limit_buckets
  set operation_count = operation_count + 1
  where user_id = p_user_id and bucket_key = v_day_key;
end;
$$;

create or replace function public.get_publish_rate_limit_hour_count(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_hour_key text;
  v_count integer;
begin
  select hour_key into v_hour_key from public.publish_rate_limit_bucket_keys();

  select coalesce(operation_count, 0) into v_count
  from public.rate_limit_buckets
  where user_id = p_user_id and bucket_key = v_hour_key;

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
-- food_reports protection + report_count sync
-- ---------------------------------------------------------------------------

create or replace function public.enforce_food_reports_mutation()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.status := 'pending';
    new.reviewed_at := null;
    new.reviewed_by := null;
    new.resolution_note := null;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if old.reporter_user_id is distinct from new.reporter_user_id
       or old.target_food_owner_user_id is distinct from new.target_food_owner_user_id
       or old.target_food_id is distinct from new.target_food_id then
      raise exception 'food_reports identity fields are immutable';
    end if;
    raise exception 'food_reports update is admin-only';
  end if;

  return new;
end;
$$;

create trigger enforce_food_reports_mutation
  before insert or update on public.food_reports
  for each row execute function public.enforce_food_reports_mutation();

create or replace function public.sync_saved_foods_report_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delta integer;
  v_owner uuid;
  v_food text;
begin
  if tg_op = 'INSERT' then
    v_delta := 1;
    v_owner := new.target_food_owner_user_id;
    v_food := new.target_food_id;
  elsif tg_op = 'DELETE' then
    v_delta := -1;
    v_owner := old.target_food_owner_user_id;
    v_food := old.target_food_id;
  else
    return coalesce(new, old);
  end if;

  perform set_config('ayg.allow_report_count_sync', 'on', true);

  update public.saved_foods
  set report_count = greatest(0, report_count + v_delta)
  where user_id = v_owner
    and food_id = v_food;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists sync_saved_foods_report_count on public.food_reports;
create trigger sync_saved_foods_report_count
  after insert or delete on public.food_reports
  for each row execute function public.sync_saved_foods_report_count();

-- Rebuild report_count from food_reports:
--   update saved_foods sf set report_count = coalesce(src.cnt, 0)
--   from (
--     select target_food_owner_user_id, target_food_id, count(*) cnt
--     from food_reports group by 1, 2
--   ) src
--   where sf.user_id = src.target_food_owner_user_id and sf.food_id = src.target_food_id;

-- ---------------------------------------------------------------------------
-- Rating validation + stats
-- ---------------------------------------------------------------------------

create or replace function public.validate_food_rating_target()
returns trigger
language plpgsql
as $$
begin
  if new.rater_user_id = new.food_owner_user_id then
    raise exception 'self rating is not allowed';
  end if;

  if tg_op = 'UPDATE' then
    if old.food_owner_user_id is distinct from new.food_owner_user_id
       or old.food_id is distinct from new.food_id
       or old.rater_user_id is distinct from new.rater_user_id then
      raise exception 'rating identity fields are immutable';
    end if;
  end if;

  if not exists (
    select 1
    from public.saved_foods sf
    where sf.user_id = new.food_owner_user_id
      and sf.food_id = new.food_id
      and public.is_saved_food_publicly_visible(
        sf.visibility, sf.status, sf.deleted_at, sf.moderation_status
      )
  ) then
    raise exception 'target food is not publicly rateable';
  end if;

  return new;
end;
$$;

create trigger validate_food_rating_target
  before insert or update on public.food_ratings
  for each row execute function public.validate_food_rating_target();

create or replace function public.sync_food_rating_stats()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_food text;
  v_delta_good integer := 0;
  v_delta_bad integer := 0;
begin
  if tg_op = 'DELETE' then
    v_owner := old.food_owner_user_id;
    v_food := old.food_id;
    if old.rating_type = 'good' then
      v_delta_good := -1;
    else
      v_delta_bad := -1;
    end if;

    update public.food_rating_stats
    set
      good_count = greatest(0, good_count + v_delta_good),
      bad_count = greatest(0, bad_count + v_delta_bad),
      updated_at = timezone('utc', now())
    where food_owner_user_id = v_owner and food_id = v_food;

    return old;
  end if;

  if tg_op = 'INSERT' then
    v_owner := new.food_owner_user_id;
    v_food := new.food_id;
    if new.rating_type = 'good' then v_delta_good := 1; else v_delta_bad := 1; end if;
  elsif tg_op = 'UPDATE' then
    if old.rating_type = new.rating_type then return new; end if;
    v_owner := new.food_owner_user_id;
    v_food := new.food_id;
    if old.rating_type = 'good' and new.rating_type = 'bad' then
      v_delta_good := -1; v_delta_bad := 1;
    elsif old.rating_type = 'bad' and new.rating_type = 'good' then
      v_delta_bad := -1; v_delta_good := 1;
    else
      raise exception 'invalid rating_type transition';
    end if;
  end if;

  insert into public.food_rating_stats (
    food_owner_user_id, food_id, good_count, bad_count, updated_at
  )
  values (
    v_owner, v_food, greatest(v_delta_good, 0), greatest(v_delta_bad, 0),
    timezone('utc', now())
  )
  on conflict (food_owner_user_id, food_id) do update
  set
    good_count = greatest(0, food_rating_stats.good_count + v_delta_good),
    bad_count = greatest(0, food_rating_stats.bad_count + v_delta_bad),
    updated_at = timezone('utc', now());

  return new;
end;
$$;

create trigger sync_food_rating_stats
  after insert or update or delete on public.food_ratings
  for each row execute function public.sync_food_rating_stats();

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------

create trigger set_saved_foods_updated_at
  before update on public.saved_foods
  for each row execute function public.set_updated_at();

create trigger set_meal_templates_updated_at
  before update on public.meal_templates
  for each row execute function public.set_updated_at();

create trigger set_meal_template_items_updated_at
  before update on public.meal_template_items
  for each row execute function public.set_updated_at();

create trigger set_food_ratings_updated_at
  before update on public.food_ratings
  for each row execute function public.set_updated_at();

create trigger set_food_rating_stats_updated_at
  before update on public.food_rating_stats
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.saved_foods enable row level security;
alter table public.meal_templates enable row level security;
alter table public.meal_template_items enable row level security;
alter table public.food_ratings enable row level security;
alter table public.food_rating_stats enable row level security;
alter table public.food_reports enable row level security;
alter table public.blocked_food_creators enable row level security;
alter table public.rate_limit_buckets enable row level security;

revoke all on public.rate_limit_buckets from authenticated, anon;

create policy saved_foods_select_own
  on public.saved_foods for select
  using ((select auth.uid()) = user_id);

-- Option A: block exclusion in public SELECT (search + detail by ID).
create policy saved_foods_select_public
  on public.saved_foods for select
  using (
    public.is_saved_food_publicly_visible(
      visibility, status, deleted_at, moderation_status
    )
    and public.is_saved_food_visible_to_viewer(user_id)
  );

create policy saved_foods_insert_own
  on public.saved_foods for insert
  with check ((select auth.uid()) = user_id);

create policy saved_foods_update_own
  on public.saved_foods for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy meal_templates_select_own
  on public.meal_templates for select
  using ((select auth.uid()) = user_id);

create policy meal_templates_insert_own
  on public.meal_templates for insert
  with check ((select auth.uid()) = user_id);

create policy meal_templates_update_own
  on public.meal_templates for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy meal_template_items_select_own
  on public.meal_template_items for select
  using ((select auth.uid()) = user_id);

create policy meal_template_items_insert_own
  on public.meal_template_items for insert
  with check ((select auth.uid()) = user_id);

create policy meal_template_items_update_own
  on public.meal_template_items for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy meal_template_items_delete_own
  on public.meal_template_items for delete
  using ((select auth.uid()) = user_id);

create policy food_ratings_select_own
  on public.food_ratings for select
  using ((select auth.uid()) = rater_user_id);

create policy food_ratings_insert_own
  on public.food_ratings for insert
  with check ((select auth.uid()) = rater_user_id);

create policy food_ratings_update_own
  on public.food_ratings for update
  using ((select auth.uid()) = rater_user_id)
  with check ((select auth.uid()) = rater_user_id);

create policy food_ratings_delete_own
  on public.food_ratings for delete
  using ((select auth.uid()) = rater_user_id);

create policy food_rating_stats_select_public
  on public.food_rating_stats for select
  using (
    exists (
      select 1
      from public.saved_foods sf
      where sf.user_id = food_rating_stats.food_owner_user_id
        and sf.food_id = food_rating_stats.food_id
        and public.is_saved_food_publicly_visible(
          sf.visibility, sf.status, sf.deleted_at, sf.moderation_status
        )
        and public.is_saved_food_visible_to_viewer(sf.user_id)
    )
  );

create policy food_reports_select_own
  on public.food_reports for select
  using ((select auth.uid()) = reporter_user_id);

create policy food_reports_insert_own
  on public.food_reports for insert
  with check (
    (select auth.uid()) = reporter_user_id
    and reporter_user_id <> target_food_owner_user_id
    and exists (
      select 1
      from public.saved_foods sf
      where sf.user_id = target_food_owner_user_id
        and sf.food_id = target_food_id
        and public.is_saved_food_reportable(
          sf.visibility, sf.status, sf.deleted_at
        )
    )
  );

create policy blocked_food_creators_select_own
  on public.blocked_food_creators for select
  using ((select auth.uid()) = blocker_user_id);

create policy blocked_food_creators_insert_own
  on public.blocked_food_creators for insert
  with check ((select auth.uid()) = blocker_user_id);

create policy blocked_food_creators_delete_own
  on public.blocked_food_creators for delete
  using ((select auth.uid()) = blocker_user_id);

revoke insert, update, delete on public.food_rating_stats from authenticated, anon;

grant select, insert, update on public.saved_foods to authenticated;
grant select, insert, update on public.meal_templates to authenticated;
grant select, insert, update, delete on public.meal_template_items to authenticated;
grant select, insert, update, delete on public.food_ratings to authenticated;
grant select on public.food_rating_stats to authenticated;
grant select, insert on public.food_reports to authenticated;
grant select, insert, delete on public.blocked_food_creators to authenticated;

commit;

-- Template + blocked creator (V1.1 app-layer):
--   Snapshot rows are never deleted. On template apply, if source owner is blocked,
--   treat like source_hidden and show the same dependency warning as soft-deleted foods.

-- Rating rate limit (V1.1): direct RLS + UI debounce. DB/RPC limits deferred to V1.2 Decision Log.

-- Publish rate limit (V1.1): RPC + rate_limit_buckets (10/hour/user, 30/day/user; private saves excluded).
