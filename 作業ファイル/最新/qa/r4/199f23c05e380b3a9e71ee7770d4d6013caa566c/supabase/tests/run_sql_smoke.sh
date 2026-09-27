#!/usr/bin/env bash
# Apply every migration, then execute the SQL functions that Dart tests only
# read as text. Requires a local Postgres superuser URL in DATABASE_URL.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required" >&2
  exit 1
fi

install_vault_extension() {
  local available
  available="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -Atc \
    "select count(*) from pg_available_extensions where name = 'supabase_vault';")"
  if [[ "$available" != "0" ]]; then
    return 0
  fi
  local sharedir
  sharedir="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -Atc "show data_directory;")"
  # data_directory is not the extension dir. Ask the server version instead.
  local version
  version="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -Atc "show server_version_num;")"
  local major="${version:0:2}"
  local dest="/usr/share/postgresql/${major}/extension"
  if [[ ! -d "$dest" ]]; then
    echo "Postgres extension directory not found: $dest" >&2
    exit 1
  fi
  sudo cp "$root/supabase/tests/pg_ext/supabase_vault.control" "$dest/"
  sudo cp "$root/supabase/tests/pg_ext/supabase_vault--1.0.sql" "$dest/"
}

install_vault_extension

bash supabase/tests/repro_pg17.sh

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/pg_bootstrap.sql

shopt -s nullglob
migrations=(supabase/migrations/*.sql)
IFS=$'\n' migrations=($(printf '%s\n' "${migrations[@]}" | sort))
unset IFS
for file in "${migrations[@]}"; do
  echo "apply $file"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$file"
done

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/food_master_v1_1_test_helpers.sql

# Supabase owns SECURITY DEFINER functions as postgres. The owner_deleted
# trigger allows that owner through. A local superuser apply would otherwise
# own them as the connecting role.
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
  loop
    execute format('alter function %s owner to postgres', fn.signature);
  end loop;
end
$$;
SQL

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/public_food_banned_name_test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/sql_runtime_smoke.sql
echo "sql smoke passed"
