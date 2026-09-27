#!/bin/bash
# usage: rollback_test.sh DB "list of timestamps in order"
export PATH=/usr/lib/postgresql/17/bin:$PATH
DB=$1; shift; H=/workspace/qa/r4/h29; P="psql -h /tmp -p 55432 -U postgres -X -d $DB"
psql -h /tmp -p 55432 -U postgres -qc "drop database if exists $DB" -c "create database $DB" 2>/dev/null
$P -v ON_ERROR_STOP=1 -qf $H/supabase/tests/pg_bootstrap.sql >/dev/null
for f in $(ls $H/supabase/migrations/*.sql | sort); do $P -v ON_ERROR_STOP=1 -qf $f >/dev/null 2>&1 || echo "APPLY FAIL $f"; done
$P -v ON_ERROR_STOP=1 -qf $H/supabase/tests/food_master_v1_1_test_helpers.sql >/dev/null
i=0
deltest() {
  i=$((i+1)); u=$(printf 'cccccccc-0000-4000-8000-%012d' $i)
  $P -qAt -v ON_ERROR_STOP=1 <<SQL 2>&1 | grep -vE "^$|NOTICE" | sed "s/^/  [$1] /"
begin;
insert into auth.users(id,aud,role,email,raw_user_meta_data) values ('$u','authenticated','authenticated','c$i@t.local','{}');
insert into auth.sessions(user_id) values ('$u'); insert into public.users(id,email) values ('$u','c$i@t.local');
select ayg_test.set_auth('$u');
insert into public.saved_foods(user_id,food_id,name,normalized_name,base_amount,unit_type,visibility,kcal_per_base,protein_per_base,fat_per_base,carb_per_base) values ('$u','p$i','黄粉もち$i号','黄粉もち$i号',100,'g','private',$((i*7)),$i,1,1);
select 1 from (select public.publish_saved_food('p$i')) x;
insert into public.saved_foods(user_id,food_id,name,normalized_name,base_amount,unit_type,visibility) values ('$u','q$i','ごはん','ごはん',100,'g','private');
reset role;
do \$\$ begin
 if to_regprocedure('public.delete_own_account(uuid)') is not null then
   perform ayg_test.set_auth('$u','service_role'); perform public.delete_own_account('$u');
 else perform ayg_test.set_auth('$u'); perform public.delete_own_account(); end if;
end \$\$;
reset role;
select 'delete OK: private='||(select count(*) from public.saved_foods where user_id='$u' and visibility<>'public')||' public='||(select count(*) from public.saved_foods where user_id='$u' and visibility='public')||' sessions='||(select count(*) from auth.sessions where user_id='$u')||' fns='||(select string_agg(p.oid::regprocedure::text,',') from pg_proc p where proname='delete_own_account')||' owner_deleted_col='||(select count(*) from information_schema.columns where table_name='saved_foods' and column_name='owner_deleted');
commit;
SQL
}
deltest "before rollback"
for t in "$@"; do
  f=$(ls $H/supabase/rollback/${t}_*_down.sql)
  out=$($P -v ON_ERROR_STOP=1 -qf $f 2>&1 | grep -E "ERROR" ); echo "down $t: ${out:-ok}"
  deltest "after $t down"
done
