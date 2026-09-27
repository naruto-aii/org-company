import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ayg/repositories/account_deletion_rpc.dart';
import 'package:ayg/repositories/apple_refresh_token.dart';
import 'package:ayg/repositories/auth_exceptions.dart';

void main() {
  test('native Apple sign-in sends only the authorization code', () async {
    final calls = <Map<String, Object?>>[];
    var signedIn = false;

    await finishNativeAppleSignIn(
      signIn: () async {
        signedIn = true;
      },
      authorizationCode: ' auth-code ',
      storeCode: (code) => storeAppleAuthorizationCode(
        invoke: (functionName, {body}) async {
          calls.add({'function': functionName, 'body': body});
          return const FunctionResponse(status: 200, data: {'stored': true});
        },
        authorizationCode: code,
      ),
    );

    expect(signedIn, isTrue);
    expect(calls, [
      {
        'function': storeAppleRefreshTokenFunction,
        'body': {'authorization_code': 'auth-code'},
      },
    ]);
  });

  test('a failed token store does not fail Apple sign-in', () async {
    var signedIn = false;

    await finishNativeAppleSignIn(
      signIn: () async {
        signedIn = true;
      },
      authorizationCode: 'auth-code',
      storeCode: (code) => storeAppleAuthorizationCode(
        invoke: (functionName, {body}) async {
          throw const FunctionException(
            status: 500,
            details: 'invalid_client raw apple error',
          );
        },
        authorizationCode: code,
      ),
    );

    expect(signedIn, isTrue);
  });

  test('sign-in is unchanged when the authorization code is empty', () async {
    var invoked = false;

    await finishNativeAppleSignIn(
      signIn: () async {},
      authorizationCode: '   ',
      storeCode: (code) => storeAppleAuthorizationCode(
        invoke: (functionName, {body}) async {
          invoked = true;
          return const FunctionResponse(status: 200);
        },
        authorizationCode: code,
      ),
    );

    expect(invoked, isFalse);
  });

  test('a store error after sign-in is swallowed by the handoff', () async {
    var signedIn = false;

    await finishNativeAppleSignIn(
      signIn: () async {
        signedIn = true;
      },
      authorizationCode: 'auth-code',
      storeCode: (_) async {
        throw StateError('raw store failure');
      },
    );

    expect(signedIn, isTrue);
  });

  test('sign-in failure does not store an authorization code', () async {
    var invoked = false;

    expect(
      () => finishNativeAppleSignIn(
        signIn: () async {
          throw StateError('apple sign-in failed');
        },
        authorizationCode: 'auth-code',
        storeCode: (_) async {
          invoked = true;
        },
      ),
      throwsStateError,
    );
    expect(invoked, isFalse);
  });

  test('delete account invokes the edge function', () async {
    final calls = <String>[];

    await deleteOwnAccountWithInvoker((functionName, {body}) async {
      calls.add(functionName);
      expect(body, isNull);
      return const FunctionResponse(status: 200, data: {'ok': true});
    });

    expect(calls, [deleteAccountFunction]);
  });

  test('a missing delete function is unavailable', () {
    expect(
      () => deleteOwnAccountWithInvoker((functionName, {body}) async {
        throw const FunctionException(status: 404, details: 'not found raw');
      }),
      throwsA(isA<AccountDeletionUnavailableException>()),
    );
  });

  test('delete failures hide the function body', () {
    const raw = 'invalid_grant refresh-token-value';

    expect(
      () => deleteOwnAccountWithInvoker((functionName, {body}) async {
        throw FunctionException(status: 500, details: raw);
      }),
      throwsA(
        isA<AccountDeletionFailedException>().having(
          (error) => error.message,
          'message',
          accountDeletionGenericFailure,
        ),
      ),
    );
    expect(
      () => deleteOwnAccountWithInvoker((functionName, {body}) async {
        return const FunctionResponse(status: 200, data: {'ok': false});
      }),
      throwsA(
        isA<AccountDeletionFailedException>().having(
          (error) => error.toString(),
          'toString',
          isNot(contains(raw)),
        ),
      ),
    );
  });

  test('the native sign-in path passes the authorization code', () {
    final source = File(
      'lib/repositories/supabase_authentication_repository.dart',
    ).readAsStringSync();
    expect(source, contains('finishNativeAppleSignIn'));
    expect(source, contains('authorizationCode: credential.authorizationCode'));
    expect(source.contains('identityToken: credential'), isFalse);
  });

  test(
    'production functions read the four secret names and no key material',
    () {
      const names = [
        'APPLE_TEAM_ID',
        'APPLE_KEY_ID',
        'APPLE_PRIVATE_KEY',
        'APPLE_CLIENT_ID',
      ];
      final production = [
        'supabase/functions/_shared/apple_account.ts',
        'supabase/functions/store-apple-refresh-token/index.ts',
        'supabase/functions/delete-account/index.ts',
      ].map((path) => File(path).readAsStringSync()).join('\n');
      final readme = File('supabase/functions/README.md').readAsStringSync();
      final config = File('supabase/config.toml').readAsStringSync();

      for (final name in names) {
        expect(production, contains(name));
        expect(readme, contains(name));
        expect(readme, contains('supabase secrets set'));
      }
      expect(readme, contains('com.narutoaii.ayg'));
      expect(production.contains('com.narutoaii.ayg'), isFalse);
      expect(production.contains('BEGIN EC PRIVATE KEY'), isFalse);
      expect(
        RegExp(
          'BEGIN PRIVATE KEY-----[\\r\\n]+[A-Za-z0-9+/=]',
        ).hasMatch(production),
        isFalse,
      );
      expect(production, contains('https://appleid.apple.com/auth/revoke'));
      expect(production, contains('https://appleid.apple.com/auth/token'));
      expect(production, contains('token_type_hint'));
      expect(production, contains('revokeThenDeleteAccount'));
      expect(production, contains('fn: "delete_own_account"'));
      expect(
        RegExp(
          r'\[functions\.store-apple-refresh-token\]\s+verify_jwt = true',
        ).hasMatch(config),
        isTrue,
      );
      expect(
        RegExp(
          r'\[functions\.delete-account\]\s+verify_jwt = true',
        ).hasMatch(config),
        isTrue,
      );
      final schemas = RegExp(
        r'^schemas = .*$',
        multiLine: true,
      ).firstMatch(config)!.group(0)!;
      expect(schemas.contains('vault'), isFalse);
      expect(RegExp(r'APPLE_PRIVATE_KEY\s*=\s*"').hasMatch(config), isFalse);
    },
  );
}
