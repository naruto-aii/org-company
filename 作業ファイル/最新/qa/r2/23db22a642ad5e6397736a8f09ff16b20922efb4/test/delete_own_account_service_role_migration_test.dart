import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationName =
      'supabase/migrations/20260927180000_delete_own_account_service_role_only.sql';
  const downName =
      'supabase/rollback/20260927180000_delete_own_account_service_role_only_down.sql';

  late String sql;
  late String downSql;

  setUpAll(() {
    sql = File(migrationName).readAsStringSync();
    downSql = File(downName).readAsStringSync();
  });

  test('only service_role can execute delete_own_account', () {
    expect(
      sql,
      contains('drop function if exists public.delete_own_account()'),
    );
    expect(
      sql,
      contains(
        'function public.delete_own_account(p_user_id pg_catalog.uuid)',
      ),
    );
    expect(sql, contains("auth.role() is distinct from 'service_role'"));
    expect(sql, contains('uid := p_user_id'));
    expect(sql.contains('auth.uid()'), isFalse);
    expect(sql, contains("set search_path = ''"));
    expect(sql, contains('delete from public.subscription_events'));
    expect(sql, contains('delete from auth.sessions'));
    expect(sql, contains('from public'));
    expect(sql, contains('from anon'));
    expect(sql, contains('from authenticated'));
    expect(
      sql,
      contains(
        'grant execute on function public.delete_own_account(pg_catalog.uuid) to service_role',
      ),
    );
    final grantLines = sql
        .split('\n')
        .where((line) => line.trimLeft().toLowerCase().startsWith('grant '))
        .toList();
    expect(grantLines, hasLength(1));
    expect(grantLines.single.contains('authenticated'), isFalse);
    expect(
      File(
        'supabase/migrations/20260927180000_delete_own_account_service_role_only_down.sql',
      ).existsSync(),
      isFalse,
    );
  });

  test('down sql restores the authenticated zero-argument function', () {
    expect(
      downSql,
      contains(
        'drop function if exists public.delete_own_account(pg_catalog.uuid)',
      ),
    );
    expect(
      downSql,
      contains('create or replace function public.delete_own_account()'),
    );
    expect(downSql, contains('uid pg_catalog.uuid := auth.uid()'));
    expect(
      downSql,
      contains(
        'grant execute on function public.delete_own_account() to authenticated',
      ),
    );
    expect(downSql.contains('delete from public.subscription_events'), isTrue);
    expect(downSql.toLowerCase().contains('drop extension'), isFalse);
  });
}
