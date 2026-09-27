#!/usr/bin/env bash
# The four statements from the PostgreSQL 17 repro. Each one must fail.
# coalesce, greatest, and current_user are SQL syntax, and normalization_form
# is not a type. Schema-qualifying them errors only when the statement runs.
# Point DATABASE_URL at the CI Postgres 17 service. Do not use this on production.
set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required" >&2
  exit 1
fi

expect_error() {
  local sql="$1"
  if psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "$sql" >/dev/null 2>"/tmp/repro_pg17.err"; then
    echo "expected an error: $sql" >&2
    exit 1
  fi
  if [[ ! -s /tmp/repro_pg17.err ]]; then
    echo "expected an error message: $sql" >&2
    exit 1
  fi
}

expect_error "select pg_catalog.coalesce(null::text,'x')"
expect_error "select pg_catalog.greatest(1,2)"
expect_error "select 'a'::text where pg_catalog.current_user = 'x'"
expect_error "select 'NFKC'::pg_catalog.normalization_form"
echo "pg17 syntax repro passed"
