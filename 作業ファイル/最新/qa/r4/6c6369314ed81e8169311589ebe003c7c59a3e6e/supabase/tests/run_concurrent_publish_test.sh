#!/usr/bin/env bash
# Concurrent publish rate-limit test (local Supabase only).
# Requires: supabase db reset already applied, DB_URL set.

set -euo pipefail

DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
PSQL="${PSQL:-/opt/homebrew/opt/libpq/bin/psql}"

USER_ID="66666666-6666-6666-6666-666666666666"

"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -q <<'SQL'
create schema if not exists ayg_test;

create or replace function ayg_test.set_auth(p_user_id uuid, p_role text default 'authenticated')
returns void language plpgsql as $$
begin
  perform set_config('role', p_role, true);
  perform set_config('request.jwt.claim.sub', p_user_id::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user_id, 'role', p_role)::text,
    true
  );
  perform set_config(
    'request.jwt.claim.role',
    case when p_role = 'service_role' then 'service_role' else 'authenticated' end,
    true
  );
end;
$$;

create or replace function ayg_test.concurrent_publish_as(p_user_id uuid, p_food_id text)
returns boolean language plpgsql security definer
set search_path = public, ayg_test
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user_id::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user_id, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.publish_saved_food(p_food_id);
  return true;
exception when others then
  return false;
end;
$$;
SQL

"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at
) values (
  '$USER_ID', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'userc@test.local', crypt('testpass', gen_salt('bf')), now(), now(), now()
) on conflict (id) do nothing;

insert into public.users (id, email)
values ('$USER_ID', 'userc@test.local')
on conflict (id) do nothing;

delete from public.rate_limit_buckets where user_id = '$USER_ID';
delete from public.saved_foods where user_id = '$USER_ID' and food_id like 'conc-%';

do \$\$
declare
  i integer;
begin
  perform ayg_test.set_auth('$USER_ID');
  for i in 1..12 loop
    insert into public.saved_foods (
      user_id, food_id, name, normalized_name, base_amount, unit_type, visibility
    ) values (
      '$USER_ID', 'conc-' || i, 'Conc ' || i, 'conc ' || i, 300 + i, 'g', 'private'
    );
  end loop;
end;
\$\$;
SQL

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

for i in $(seq 1 12); do
  (
    "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -tA -q \
      -c "select ayg_test.concurrent_publish_as('$USER_ID', 'conc-$i');" \
      >"$TMPDIR/out_$i.txt"
  ) &
done
wait

SUCCESS_COUNT=$(awk '$1=="t"{c++} END{print c+0}' "$TMPDIR"/out_*.txt)
LIMIT_COUNT=$("$PSQL" "$DB_URL" -tA -c "select public.get_publish_rate_limit_hour_count('$USER_ID');")

if [[ "$SUCCESS_COUNT" -ne 10 ]]; then
  echo "CONCURRENT TEST FAILED: expected 10 successful publishes, got $SUCCESS_COUNT" >&2
  cat "$TMPDIR"/out_*.txt >&2 || true
  exit 1
fi

if [[ "$LIMIT_COUNT" -ne 10 ]]; then
  echo "CONCURRENT TEST FAILED: expected hour count 10, got $LIMIT_COUNT" >&2
  exit 1
fi

echo "CONCURRENT PUBLISH TEST PASSED (success=$SUCCESS_COUNT, hour_count=$LIMIT_COUNT)"
