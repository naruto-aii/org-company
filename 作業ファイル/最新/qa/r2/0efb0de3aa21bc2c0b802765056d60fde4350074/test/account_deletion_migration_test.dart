import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const appliedName =
      'supabase/migrations/20260920120000_delete_own_account_keep_public_foods.sql';
  const followUpName =
      'supabase/migrations/20260927150000_protect_owner_deleted_and_revoke_sessions.sql';
  const downName =
      'supabase/rollback/20260927150000_protect_owner_deleted_and_revoke_sessions_down.sql';
  const eventsName =
      'supabase/migrations/20260927160000_delete_subscription_events_on_account_deletion.sql';
  const eventsDownName =
      'supabase/rollback/20260927160000_delete_subscription_events_on_account_deletion_down.sql';

  late String appliedSql;
  late String followUpSql;
  late String downSql;
  late String eventsSql;
  late String eventsDownSql;

  setUpAll(() {
    appliedSql = File(appliedName).readAsStringSync();
    followUpSql = File(followUpName).readAsStringSync();
    downSql = File(downName).readAsStringSync();
    eventsSql = File(eventsName).readAsStringSync();
    eventsDownSql = File(eventsDownName).readAsStringSync();
  });

  test('already-applied delete_own_account migration is unchanged', () {
    expect(appliedSql.contains('owner_deleted'), isFalse);
    expect(appliedSql.contains('auth.sessions'), isFalse);
    expect(appliedSql.contains('auth.refresh_tokens'), isFalse);
    expect(
      appliedSql,
      contains('create or replace function public.delete_own_account()'),
    );
    expect(
      appliedSql,
      contains(
        'grant execute on function public.delete_own_account() to authenticated',
      ),
    );
  });

  test('follow-up migration adds owner_deleted idempotently', () {
    expect(
      followUpSql,
      contains(
        'add column if not exists owner_deleted boolean not null default false',
      ),
    );
    expect(followUpSql, contains('set owner_deleted = true'));
  });

  test('session revoke sits outside the auth.users exception handler', () {
    final notice = followUpSql.indexOf(
      'delete_own_account: skipped auth.users update',
    );
    final refresh = followUpSql.indexOf(
      'delete from auth.refresh_tokens where user_id::text = uid::text',
    );
    final sessions = followUpSql.indexOf(
      'delete from auth.sessions where user_id::text = uid::text',
    );
    expect(notice, greaterThan(0));
    expect(refresh, greaterThan(notice));
    expect(sessions, greaterThan(refresh));
  });

  test('authenticated cannot update owner_deleted', () {
    expect(
      followUpSql,
      contains(
        'revoke insert, update on table public.saved_foods from authenticated',
      ),
    );
    expect(
      followUpSql,
      contains(
        'grant insert (owner_deleted), update (owner_deleted)\n'
        '  on table public.saved_foods to service_role',
      ),
    );

    final authenticatedGrant = followUpSql.indexOf(
      ') on table public.saved_foods to authenticated',
    );
    expect(authenticatedGrant, greaterThan(0));
    final grantBody = followUpSql.substring(0, authenticatedGrant);
    final updateListStart = grantBody.lastIndexOf('update (');
    final updateList = grantBody.substring(updateListStart, authenticatedGrant);
    expect(updateList.contains('owner_deleted'), isFalse);
    expect(updateList, contains('serving_unit_label'));
    expect(updateList, contains('version'));
    expect(updateList, contains('normalized_name'));
  });

  test('owner_deleted trigger is not security definer', () {
    final start = followUpSql.indexOf(
      'function public.saved_foods_reject_owner_deleted_change()',
    );
    final end = followUpSql.indexOf('\$\$;', start);
    final body = followUpSql.substring(start, end).toLowerCase();
    expect(body.contains('security definer'), isFalse);
    expect(body, contains("set search_path = ''"));
    expect(body, contains('postgres'));
    expect(body, contains('supabase_admin'));
    expect(body, contains('service_role'));
    expect(
      followUpSql,
      contains(
        'execute function public.saved_foods_reject_owner_deleted_change()',
      ),
    );
  });

  test('delete_own_account uses an empty search_path', () {
    final start = followUpSql.indexOf('function public.delete_own_account()');
    final end = followUpSql.indexOf('as \$\$', start);
    final header = followUpSql.substring(start, end);
    expect(header, contains("set search_path = ''"));
    expect(header, contains('security definer'));
    expect(followUpSql, contains('pg_catalog.timezone'));
    expect(followUpSql, contains('pg_catalog.now()'));
  });

  test('down sql is outside supabase/migrations', () {
    expect(File(downName).existsSync(), isTrue);
    expect(
      File(
        'supabase/migrations/20260927150000_protect_owner_deleted_and_revoke_sessions_down.sql',
      ).existsSync(),
      isFalse,
    );
    expect(downSql, contains('drop column if exists owner_deleted'));
    expect(
      downSql,
      contains(
        'drop function if exists public.saved_foods_reject_owner_deleted_change()',
      ),
    );
    expect(
      downSql,
      contains(
        'grant select, insert, update on table public.saved_foods to authenticated',
      ),
    );
    expect(downSql.contains('auth.sessions'), isFalse);
    expect(downSql.contains('auth.refresh_tokens'), isFalse);
    expect(downSql.contains('owner_deleted = true'), isFalse);
  });

  test('account deletion deletes subscription_events in a later migration', () {
    expect(followUpSql.contains('subscription_events'), isFalse);
    expect(eventsSql, contains("set search_path = ''"));
    expect(
      eventsSql,
      contains("pg_catalog.to_regclass('public.subscription_events')"),
    );
    expect(
      eventsSql,
      contains('delete from public.subscription_events where user_id = uid'),
    );
    expect(
      eventsDownSql.contains('delete from public.subscription_events'),
      isFalse,
    );
    expect(
      eventsDownSql,
      contains('create or replace function public.delete_own_account()'),
    );
    expect(
      File(
        'supabase/migrations/20260927160000_delete_subscription_events_on_account_deletion_down.sql',
      ).existsSync(),
      isFalse,
    );
  });
}
