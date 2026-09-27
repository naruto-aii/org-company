#!/bin/bash
export PATH=/usr/lib/postgresql/17/bin:$PATH
H=/workspace/qa/r5/h; DB=r5rb; P="psql -h /tmp -p 55432 -U postgres -X -d $DB"
psql -h /tmp -p 55432 -U postgres -qc "drop database if exists $DB" -c "create database $DB" 2>/dev/null
$P -v ON_ERROR_STOP=1 -qf $H/supabase/tests/pg_bootstrap.sql >/dev/null
for f in $(ls $H/supabase/migrations/*.sql | sort); do $P -v ON_ERROR_STOP=1 -qf $f >/dev/null 2>&1 || echo "APPLY FAIL $f"; done
$P -v ON_ERROR_STOP=1 -qf $H/supabase/tests/food_master_v1_1_test_helpers.sql >/dev/null
echo "== forward applied (4c54fc4, $(ls $H/supabase/migrations | wc -l) files)"
i=1; ./step_test.sh $DB "all applied" $i
for t in 20260927180000 20260927170000 20260927160000 20260927150000 20260927140000 20260927120000; do
  f=$(ls $H/supabase/rollback/${t}_*_down.sql)
  e1=$($P -v ON_ERROR_STOP=1 -qf $f 2>&1 | grep ERROR); e2=$($P -v ON_ERROR_STOP=1 -qf $f 2>&1 | grep ERROR)
  echo "== down $t: 1st=${e1:-ok} 2nd(rerun)=${e2:-ok}"
  i=$((i+1)); ./step_test.sh $DB "after $t down" $i
done
echo "== re-apply forward 120000..180000 after full rollback"
for f in $(ls $H/supabase/migrations/202609271*.sql | sort); do e=$($P -v ON_ERROR_STOP=1 -qf $f 2>&1 | grep ERROR); echo "reapply $(basename $f): ${e:-ok}"; done
$P -qc "do \$\$ declare fn record; begin for fn in select p.oid::regprocedure s from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosecdef loop execute format('alter function %s owner to postgres', fn.s); end loop; end \$\$;"
i=$((i+1)); ./step_test.sh $DB "re-applied" $i
echo "== repo smoke on re-applied DB"
$P -v ON_ERROR_STOP=1 -qf $H/supabase/tests/public_food_banned_name_test.sql >/dev/null 2>&1 && echo "banned_name_test ok" || echo "banned_name_test FAIL"
$P -v ON_ERROR_STOP=1 -qf $H/supabase/tests/sql_runtime_smoke.sql 2>&1 | grep -E "ERROR|ASSERT" || echo "sql_runtime_smoke ok"
