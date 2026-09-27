import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260927140000_subscription_events.sql',
  ).readAsStringSync();
  final down = File(
    'supabase/rollback/20260927140000_subscription_events_down.sql',
  ).readAsStringSync();

  test('subscription events store only user, type, and timestamp', () {
    expect(migration, contains('enable row level security'));
    expect(migration, contains("'free_limit_hit'"));
    expect(migration, contains("'converted_to_paid'"));
    expect(migration, contains('unique (user_id, event_type)'));
    expect(migration, contains('user_id uuid not null'));
    expect(migration, contains('created_at timestamptz'));
    expect(migration, isNot(contains('food_name')));
    expect(migration, isNot(contains('receipt_data')));
    expect(migration, isNot(contains('health_snapshot')));
    expect(migration, contains('new.created_at := pg_catalog.timezone'));
    expect(migration, contains('pg_catalog.now()'));
  });

  test('clients can insert their own row and cannot read it back', () {
    expect(
      migration,
      contains(
        'grant insert on table public.subscription_events to authenticated',
      ),
    );
    expect(migration, contains('for insert'));
    expect(migration, contains('auth.uid()) = user_id'));
    expect(migration, isNot(contains('for select')));
    expect(migration, isNot(contains('for update')));
    expect(migration, isNot(contains('for delete')));
    expect(
      migration,
      isNot(
        contains(
          'grant select on table public.subscription_events to authenticated',
        ),
      ),
    );
    expect(
      migration,
      isNot(
        contains('grant select on table public.subscription_events to anon'),
      ),
    );
  });

  test('counts rely on the service_role grant', () {
    final countsAt = migration.indexOf(
      'function public.subscription_event_counts()',
    );
    final countsHeader = migration.substring(
      countsAt,
      migration.indexOf('as \$\$', countsAt),
    );
    expect(countsHeader, contains('security definer'));
    expect(countsHeader, contains("set search_path = ''"));

    final triggerAt = migration.indexOf(
      'function public.subscription_events_force_row()',
    );
    final triggerHeader = migration
        .substring(triggerAt, migration.indexOf('as \$\$', triggerAt))
        .toLowerCase();
    expect(triggerHeader.contains('security definer'), isFalse);
    expect(triggerHeader, contains("set search_path = ''"));

    expect(migration.contains('request.jwt.claim.role'), isFalse);
    expect(migration.contains('jwt_role'), isFalse);
    expect(migration.contains('session_user'), isFalse);
    expect(migration, contains('function public.subscription_event_counts()'));
    expect(migration, contains('pg_catalog.count(distinct e.user_id)'));
    expect(
      migration,
      contains('revoke all on function public.subscription_event_counts()'),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.subscription_event_counts() to service_role',
      ),
    );
    expect(
      migration,
      isNot(
        contains(
          'grant execute on function public.subscription_event_counts() to authenticated',
        ),
      ),
    );
  });

  test('down migration removes the table and functions', () {
    expect(down, contains('drop table if exists public.subscription_events'));
    expect(
      down,
      contains('drop function if exists public.subscription_event_counts()'),
    );
    expect(
      down,
      contains(
        'drop function if exists public.subscription_events_force_row()',
      ),
    );
    expect(down, isNot(contains('create table')));
    expect(
      Directory('supabase/migrations').listSync().any(
        (entity) => entity.path.endsWith('subscription_events_down.sql'),
      ),
      isFalse,
    );
  });
}
