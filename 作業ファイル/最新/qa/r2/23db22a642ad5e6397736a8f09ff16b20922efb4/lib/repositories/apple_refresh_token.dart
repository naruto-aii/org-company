import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Edge Function that exchanges a Sign in with Apple authorization code.
const storeAppleRefreshTokenFunction = 'store-apple-refresh-token';

typedef EdgeFunctionInvoke =
    Future<FunctionResponse> Function(String functionName, {Object? body});

/// Sends [authorizationCode] to the Edge Function. The function exchanges it
/// and stores the refresh token. A failure here must not undo a sign-in that
/// already succeeded, and the raw response is not shown.
Future<void> storeAppleAuthorizationCode({
  required EdgeFunctionInvoke invoke,
  required String authorizationCode,
}) async {
  final code = authorizationCode.trim();
  if (code.isEmpty) {
    return;
  }
  try {
    await invoke(
      storeAppleRefreshTokenFunction,
      body: {'authorization_code': code},
    );
  } catch (_) {
    debugPrint('Sign in with Apple refresh token was not stored.');
  }
}

/// Completes native Apple sign-in, then stores the authorization code.
/// [signIn] runs first so the function call has a user session. Storage
/// errors are swallowed.
Future<void> finishNativeAppleSignIn({
  required Future<void> Function() signIn,
  required String authorizationCode,
  required Future<void> Function(String authorizationCode) storeCode,
}) async {
  await signIn();
  try {
    await storeCode(authorizationCode);
  } catch (_) {
    debugPrint('Sign in with Apple refresh token was not stored.');
  }
}
