import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationName =
      'supabase/migrations/20260927170000_store_apple_refresh_tokens.sql';
  const downName =
      'supabase/rollback/20260927170000_store_apple_refresh_tokens_down.sql';

  late String sql;
  late String downSql;

  setUpAll(() {
    sql = File(migrationName).readAsStringSync();
    downSql = File(downName).readAsStringSync();
  });

  test('refresh tokens are stored in vault behind service_role functions', () {
    expect(sql, contains('supabase_vault'));
    expect(sql, contains('vault.create_secret'));
    expect(sql, contains('vault.update_secret'));
    expect(sql, contains('vault.decrypted_secrets'));
    expect(sql, contains("apple_refresh_token:"));
    expect('security definer'.allMatches(sql.toLowerCase()).length, 3);
    expect("set search_path = ''".allMatches(sql).length, 3);

    final grantLines = sql
        .split('\n')
        .where((line) => line.trimLeft().toLowerCase().startsWith('grant '))
        .toList();
    expect(grantLines, hasLength(3));
    for (final line in grantLines) {
      expect(line.toLowerCase().contains('authenticated'), isFalse);
      expect(line.toLowerCase().contains(' anon'), isFalse);
      expect(line, contains('service_role'));
    }
    expect(sql, contains('from public'));
    expect(sql, contains('from anon'));
    expect(sql, contains('from authenticated'));
    expect(sql.contains('create policy'), isFalse);
    expect(sql.contains('BEGIN PRIVATE KEY'), isFalse);
    expect(sql.contains('delete_own_account'), isFalse);
  });

  test('down sql drops only the apple token functions', () {
    expect(
      File(
        'supabase/migrations/20260927170000_store_apple_refresh_tokens_down.sql',
      ).existsSync(),
      isFalse,
    );
    expect(
      downSql,
      contains(
        'drop function if exists public.store_apple_refresh_token(uuid, text)',
      ),
    );
    expect(
      downSql,
      contains('drop function if exists public.read_apple_refresh_token(uuid)'),
    );
    expect(
      downSql,
      contains(
        'drop function if exists public.delete_apple_refresh_token(uuid)',
      ),
    );
    expect(
      downSql,
      contains("pg_catalog.starts_with(name, 'apple_refresh_token:')"),
    );
    expect(downSql.toLowerCase().contains('drop extension'), isFalse);
    expect(
      downSql.contains('create or replace function public.delete_own_account'),
      isFalse,
    );
    expect(
      downSql.contains('drop function if exists public.delete_own_account'),
      isFalse,
    );
    expect(downSql.toLowerCase().contains('drop trigger'), isFalse);
  });
}
