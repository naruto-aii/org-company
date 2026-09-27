#!/bin/bash
# usage: run_head.sh N  -> fresh DB r4xN, apply hN migrations, exercise
set -u
export PATH=/usr/lib/postgresql/17/bin:$PATH
N=$1; DB=r4x$N; H=/workspace/qa/r4/h$N; P="psql -h /tmp -p 55432 -U postgres -X"
$P -qc "drop database if exists $DB" -c "create database $DB" 2>/dev/null
$P -d $DB -v ON_ERROR_STOP=1 -qf /workspace/qa/r4/h26/supabase/tests/pg_bootstrap.sql || exit 1
for f in $(ls $H/supabase/migrations/*.sql | sort); do echo "apply $(basename $f)"; $P -d $DB -v ON_ERROR_STOP=1 -qf $f >/dev/null || { echo "APPLY FAILED $f"; exit 1; }; done
$P -d $DB -v ON_ERROR_STOP=1 -qf $H/supabase/tests/food_master_v1_1_test_helpers.sql >/dev/null || exit 1
$P -d $DB -f /workspace/qa/r4/exercise.sql 2>&1 | grep -E "RESULT|INFO|after T8b|ERROR"
