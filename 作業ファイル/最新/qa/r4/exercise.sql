-- QA round4 extended exercise (local PG17 only)
\set ON_ERROR_STOP off
\pset tuples_only on
create or replace function pg_temp.r(t text, ok boolean, msg text) returns void language plpgsql as $$
begin raise notice 'RESULT % % %', t, case when ok then 'OK' else 'NG' end, msg; end $$;
-- fixtures
do $$
declare a uuid:='aaaaaaaa-0000-4000-8000-00000000000a'; b uuid:='bbbbbbbb-0000-4000-8000-00000000000b';
begin
  insert into auth.users(id,aud,role,email,raw_user_meta_data) values
   (a,'authenticated','authenticated','a@test.local','{"full_name":"A Name"}'),(b,'authenticated','authenticated','b@test.local','{}');
  insert into auth.identities(user_id,provider) values (a,'apple'),(a,'google');
  insert into auth.sessions(user_id) values (a),(a),(b);
  insert into auth.refresh_tokens(token,user_id) values ('t1',a::text),('t2',a::text),('t3',b::text);
  insert into public.users(id,email) values (a,'a@test.local'),(b,'b@test.local');
end $$;
-- T1 save private
do $$ begin perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a');
  insert into public.saved_foods(user_id,food_id,name,normalized_name,base_amount,unit_type,visibility,kcal_per_base,protein_per_base,fat_per_base,carb_per_base)
  values ('aaaaaaaa-0000-4000-8000-00000000000a','f-priv','ごはん','ごはん',100,'g','private',160,2,0,37),
         ('aaaaaaaa-0000-4000-8000-00000000000a','f-pub','ぶっかけうどん','ぶっかけうどん',100,'g','private',100,3,1,20),
         ('aaaaaaaa-0000-4000-8000-00000000000a','f-pub2','エリンギソテー','エリンギソテー',100,'g','private',50,3,1,5);
  perform pg_temp.r('T1_save',true,'insert 3 private rows');
exception when others then perform pg_temp.r('T1_save',false,sqlerrm); end $$;
-- T2 update private
do $$ begin perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a');
  update public.saved_foods set kcal_per_base=165 where food_id='f-priv';
  perform pg_temp.r('T2_update',(select kcal_per_base=165 from public.saved_foods where food_id='f-priv'),'update private');
exception when others then perform pg_temp.r('T2_update',false,sqlerrm); end $$;
-- T3 publish
do $$ begin perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a');
  perform public.publish_saved_food('f-pub'); perform public.publish_saved_food('f-pub2');
  perform ayg_test.reset_role();
  perform pg_temp.r('T3_publish',(select count(*)=2 from public.saved_foods where visibility='public'),'publish 2 (ぶっかけうどん, エリンギソテー)');
exception when others then perform pg_temp.r('T3_publish',false,sqlerrm); end $$;
-- T3b publish banned name must fail
do $$ begin perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a');
  insert into public.saved_foods(user_id,food_id,name,normalized_name,base_amount,unit_type,visibility,kcal_per_base,protein_per_base,fat_per_base,carb_per_base)
  values ('aaaaaaaa-0000-4000-8000-00000000000a','f-bad','クソまずいカレー','クソまずいカレー',100,'g','private',1,1,1,1);
  perform public.publish_saved_food('f-bad');
  perform pg_temp.r('T3b_publish_banned',false,'publish of banned name succeeded');
exception when others then perform pg_temp.r('T3b_publish_banned',true,'rejected: '||sqlerrm); end $$;
-- T4 edit public row (ordinary)
do $$ begin perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a');
  update public.saved_foods set name='ぶっかけうどん(冷)', normalized_name='ぶっかけうどん(冷)' where food_id='f-pub';
  perform pg_temp.r('T4_edit_public',true,'ordinary rename ok');
exception when others then perform pg_temp.r('T4_edit_public',false,sqlerrm); end $$;
-- T4b edit public row to banned
do $$ begin perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a');
  update public.saved_foods set name='エロいうどん', normalized_name='エロいうどん' where food_id='f-pub';
  perform pg_temp.r('T4b_edit_public_banned',false,'banned rename accepted');
exception when others then perform pg_temp.r('T4b_edit_public_banned',true,'rejected: '||sqlerrm); end $$;
-- T5 client sets owner_deleted
do $$ begin perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a');
  update public.saved_foods set owner_deleted=true where food_id='f-pub';
  perform pg_temp.r('T5_owner_deleted_client',false,'client changed owner_deleted');
exception when others then perform pg_temp.r('T5_owner_deleted_client',true,'rejected: '||sqlerrm); end $$;
-- B public food
do $$ begin perform ayg_test.set_auth('bbbbbbbb-0000-4000-8000-00000000000b');
  insert into public.saved_foods(user_id,food_id,name,normalized_name,base_amount,unit_type,visibility,kcal_per_base,protein_per_base,fat_per_base,carb_per_base)
  values ('bbbbbbbb-0000-4000-8000-00000000000b','f-b','黄粉もち','黄粉もち',100,'g','private',200,4,2,40);
  perform public.publish_saved_food('f-b');
exception when others then perform pg_temp.r('Tfixture_B',false,sqlerrm); end $$;
-- T6 report
do $$ begin perform ayg_test.set_auth('bbbbbbbb-0000-4000-8000-00000000000b');
  insert into public.food_reports(report_id,reporter_user_id,target_food_owner_user_id,target_food_id,reason_code)
  values ('r1','bbbbbbbb-0000-4000-8000-00000000000b','aaaaaaaa-0000-4000-8000-00000000000a','f-pub','inappropriate_name');
  perform pg_temp.r('T6_report',true,'report inserted');
exception when others then perform pg_temp.r('T6_report',false,sqlerrm); end $$;
do $$ begin perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a');
  insert into public.food_reports(report_id,reporter_user_id,target_food_owner_user_id,target_food_id,reason_code)
  values ('r2','aaaaaaaa-0000-4000-8000-00000000000a','bbbbbbbb-0000-4000-8000-00000000000b','f-b','inappropriate_name');
  perform pg_temp.r('T6b_report_by_A',true,'A report inserted');
exception when others then perform pg_temp.r('T6b_report_by_A',false,sqlerrm); end $$;
-- T7 subscription events
do $$ begin
  if to_regclass('public.subscription_events') is null then perform pg_temp.r('T7_subevents',true,'N/A (table absent)'); return; end if;
  perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a');
  execute $q$insert into public.subscription_events(user_id,event_type) values ('aaaaaaaa-0000-4000-8000-00000000000a','free_limit_hit'),('aaaaaaaa-0000-4000-8000-00000000000a','converted_to_paid')$q$;
  perform pg_temp.r('T7_subevents',true,'2 events');
exception when others then perform pg_temp.r('T7_subevents',false,sqlerrm); end $$;
-- T7b apple token in vault
do $$ begin
  if to_regprocedure('public.store_apple_refresh_token(uuid,text)') is null then perform pg_temp.r('T7b_vault',true,'N/A'); return; end if;
  perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a','service_role');
  perform public.store_apple_refresh_token('aaaaaaaa-0000-4000-8000-00000000000a','rt-secret');
  perform pg_temp.r('T7b_vault',public.read_apple_refresh_token('aaaaaaaa-0000-4000-8000-00000000000a')='rt-secret','store/read as service_role');
exception when others then perform pg_temp.r('T7b_vault',false,sqlerrm); end $$;
do $$ begin
  if to_regprocedure('public.read_apple_refresh_token(uuid)') is null then return; end if;
  perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a');
  perform public.read_apple_refresh_token('aaaaaaaa-0000-4000-8000-00000000000a');
  perform pg_temp.r('T7c_vault_auth_denied',false,'authenticated could read token');
exception when others then perform pg_temp.r('T7c_vault_auth_denied',true,sqlerrm); end $$;
-- T8 authenticated delete must be denied if 180000
do $$ begin
  if to_regprocedure('public.delete_own_account(uuid)') is null then perform pg_temp.r('T8_auth_delete_denied',true,'N/A (zero-arg era; client RPC by design)'); return; end if;
  perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a');
  perform public.delete_own_account('aaaaaaaa-0000-4000-8000-00000000000a');
  perform pg_temp.r('T8_auth_delete_denied',false,'authenticated deleted!');
exception when others then perform pg_temp.r('T8_auth_delete_denied',true,sqlerrm); end $$;
-- T8b service_role deleting with email-rewrite failure (inject trigger)
create or replace function pg_temp.fail_email() returns trigger language plpgsql as $$ begin raise exception 'injected auth.users failure'; end $$;
create trigger qa_fail before update on auth.users for each row execute function pg_temp.fail_email();
do $$ begin
  if to_regprocedure('public.delete_own_account(uuid)') is not null then
    perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a','service_role');
    perform public.delete_own_account('aaaaaaaa-0000-4000-8000-00000000000a');
  else
    perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a');
    perform public.delete_own_account();
  end if;
  perform ayg_test.reset_role();
  perform pg_temp.r('T8b_email_fail',false,format('function returned success; private=%s identities=%s sessions=%s email=%s',
    (select count(*) from public.saved_foods where user_id='aaaaaaaa-0000-4000-8000-00000000000a' and visibility<>'public'),
    (select count(*) from auth.identities where user_id='aaaaaaaa-0000-4000-8000-00000000000a'),
    (select count(*) from auth.sessions where user_id='aaaaaaaa-0000-4000-8000-00000000000a'),
    (select email from auth.users where id='aaaaaaaa-0000-4000-8000-00000000000a')));
exception when others then perform pg_temp.r('T8b_email_fail',true,'aborted: '||sqlerrm); end $$;
drop trigger qa_fail on auth.users;
select 'after T8b: private='||(select count(*) from public.saved_foods where user_id='aaaaaaaa-0000-4000-8000-00000000000a' and visibility<>'public')
 ||' identities='||(select count(*) from auth.identities where user_id='aaaaaaaa-0000-4000-8000-00000000000a')
 ||' sessions='||(select count(*) from auth.sessions where user_id='aaaaaaaa-0000-4000-8000-00000000000a')
 ||' users.email='||coalesce((select email from public.users where id='aaaaaaaa-0000-4000-8000-00000000000a'),'NULL');
-- T9 real delete
do $$ begin
  if to_regprocedure('public.delete_own_account(uuid)') is not null then
    perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a','service_role');
    perform public.delete_own_account('aaaaaaaa-0000-4000-8000-00000000000a');
  else
    perform ayg_test.set_auth('aaaaaaaa-0000-4000-8000-00000000000a');
    perform public.delete_own_account();
  end if;
  perform pg_temp.r('T9_delete',true,'returned');
exception when others then perform pg_temp.r('T9_delete',false,sqlerrm); end $$;
-- T10 verify
do $$ declare a uuid:='aaaaaaaa-0000-4000-8000-00000000000a'; n_ev int:=-1; n_vault int:=-1;
begin
  if to_regclass('public.subscription_events') is not null then execute 'select count(*) from public.subscription_events where user_id=$1' into n_ev using a; end if;
  if to_regclass('vault.secrets') is not null then execute $q$select count(*) from vault.secrets where name='apple_refresh_token:'||$1::text$q$ into n_vault using a; end if;
  perform pg_temp.r('T10_private_deleted',(select count(*)=0 from public.saved_foods where user_id=a and visibility<>'public'),'');
  perform pg_temp.r('T10_public_owner_deleted',(select count(*)>=2 and bool_and(owner_deleted) from public.saved_foods where user_id=a and visibility='public'),'n_public='||(select count(*) from public.saved_foods where user_id=a and visibility='public'));
  perform pg_temp.r('T10_report_by_B_kept',(select count(*)=1 from public.food_reports where report_id='r1'),'');
  perform pg_temp.r('T10_report_by_A_deleted',(select count(*)=0 from public.food_reports where reporter_user_id=a),'');
  perform pg_temp.r('T10_subevents_0',n_ev in (0,-1),'n='||n_ev);
  perform pg_temp.r('T10_identities_0',(select count(*)=0 from auth.identities where user_id=a),'');
  perform pg_temp.r('T10_sessions_0',(select count(*)=0 from auth.sessions where user_id=a),'');
  perform pg_temp.r('T10_refresh_0',(select count(*)=0 from auth.refresh_tokens where user_id=a::text),'');
  perform pg_temp.r('T10_B_untouched',(select count(*)=1 from auth.sessions where user_id='bbbbbbbb-0000-4000-8000-00000000000b'),'');
  perform pg_temp.r('T10_auth_email',(select email like 'deleted+%@invalid.local' and raw_user_meta_data='{}'::jsonb from auth.users where id=a),'');
  perform pg_temp.r('T10_users_email_null',(select email is null and deleted_at is not null from public.users where id=a),'');
  raise notice 'INFO vault token rows after delete_own_account (Edge Function deletes separately) = %', n_vault;
end $$;
