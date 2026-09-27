#!/bin/bash
# step_test.sh DB LABEL IDX : save/publish, email-fail injection, real delete, verification
export PATH=/usr/lib/postgresql/17/bin:$PATH
DB=$1; L=$2; i=$3; P="psql -h /tmp -p 55432 -U postgres -X -d $DB -qAt"
u=$(printf 'dddddddd-0000-4000-8000-%012d' $i)
$P >/dev/null 2>&1 <<SQL
insert into auth.users(id,aud,role,email,raw_user_meta_data) values ('$u','authenticated','authenticated','u$i@t.local','{"provider":"google","full_name":"Ada $i","name":"Ada","avatar_url":"https://e.invalid/a.png","picture":"https://e.invalid/a.png"}');
insert into auth.identities(user_id,provider,identity_data) values ('$u','google','{"full_name":"Ada $i","picture":"https://e.invalid/a.png"}');
insert into auth.sessions(user_id) values ('$u'); insert into auth.refresh_tokens(token,user_id) values ('rt$i','$u');
insert into public.users(id,email) values ('$u','u$i@t.local');
SQL
# save + publish (+ subscription events) as authenticated
out=$($P 2>&1 <<SQL
begin;
select ayg_test.set_auth('$u');
insert into public.saved_foods(user_id,food_id,name,normalized_name,base_amount,unit_type,visibility,kcal_per_base,protein_per_base,fat_per_base,carb_per_base) values ('$u','p$i','きなこ餅$i号','きなこ餅$i号',100,'g','private',$((i*11)),$i,1,1);
select 1 from (select public.publish_saved_food('p$i')) x;
insert into public.saved_foods(user_id,food_id,name,normalized_name,base_amount,unit_type,visibility) values ('$u','q$i','ごはん','ごはん',100,'g','private');
do \$\$ begin if to_regclass('public.subscription_events') is not null then execute \$q\$insert into public.subscription_events(user_id,event_type) values ('$u','free_limit_hit')\$q\$; end if; end \$\$;
reset role;
select 'SAVE_PUBLISH_OK';
commit;
SQL
); echo "[$L] save/publish: $(echo "$out" | grep -q SAVE_PUBLISH_OK && echo OK || echo "NG $(echo "$out" | grep ERROR | head -1)")"
CALL="do \$\$ begin if to_regprocedure('public.delete_own_account(uuid)') is not null then perform ayg_test.set_auth('$u','service_role'); perform public.delete_own_account('$u'); else perform ayg_test.set_auth('$u'); perform public.delete_own_account(); end if; end \$\$;"
# email-fail injection
out=$($P 2>&1 <<SQL
create function pg_temp.f() returns trigger language plpgsql as \$f\$ begin raise exception 'injected'; end \$f\$;
create trigger qa_fail before update on auth.users for each row execute function pg_temp.f();
begin; $CALL commit;
drop trigger qa_fail on auth.users;
select 'STATE private='||(select count(*) from public.saved_foods where user_id='$u' and visibility<>'public')||' ident='||(select count(*) from auth.identities where user_id='$u')||' sess='||(select count(*) from auth.sessions where user_id='$u')||' email='||(select email from auth.users where id='$u');
SQL
)
st=$(echo "$out" | grep STATE)
if echo "$out" | grep -q "ERROR:  injected"; then echo "[$L] email-fail: ABORTED (rolled back) $st"; else echo "[$L] email-fail: SWALLOWED (reported success) $st"; fi
# real delete (fresh user state may be partially deleted if swallowed; still run)
out=$($P 2>&1 <<SQL
create function pg_temp.od(x uuid) returns text language plpgsql as \$o\$ declare r text; begin if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='saved_foods' and column_name='owner_deleted') then return 'nocol'; end if; execute 'select bool_and(owner_deleted)::text from public.saved_foods where user_id=\$1 and visibility=''public''' into r using x; return coalesce(r,'null'); end \$o\$;
begin; $CALL commit;
select 'RES fn='||(select string_agg(p.oid::regprocedure::text,',') from pg_proc p where proname='delete_own_account')
 ||' private='||(select count(*) from public.saved_foods where user_id='$u' and visibility<>'public')
 ||' public='||(select count(*) from public.saved_foods where user_id='$u' and visibility='public')
 ||' owner_deleted='||pg_temp.od('$u')
 ||' subev='||coalesce((select case when to_regclass('public.subscription_events') is null then 'notable' end),'?')
 ||' ident='||(select count(*) from auth.identities where user_id='$u')
 ||' meta='||(select raw_user_meta_data::text from auth.users where id='$u')
 ||' email='||(select email from auth.users where id='$u')
 ||' sess='||(select count(*) from auth.sessions where user_id='$u')
 ||' rt='||(select count(*) from auth.refresh_tokens where user_id='$u');
do \$\$ declare n int; begin if to_regclass('public.subscription_events') is not null then execute 'select count(*) from public.subscription_events where user_id=\$1' into n using '$u'::uuid; raise notice 'SUBEV %', n; end if; end \$\$;
SQL
)
echo "[$L] delete: $(echo "$out" | grep -q '^ERROR' && echo "NG $(echo "$out" | grep ERROR | head -1)" || echo OK) $(echo "$out" | grep RES) $(echo "$out" | grep -o 'SUBEV [0-9]*')"
