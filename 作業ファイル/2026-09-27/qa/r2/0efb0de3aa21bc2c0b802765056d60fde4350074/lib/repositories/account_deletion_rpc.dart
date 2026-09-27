import 'package:supabase_flutter/supabase_flutter.dart';

import 'apple_refresh_token.dart';
import 'auth_exceptions.dart';

/// Edge Function that revokes the Apple refresh token, then deletes the account.
const deleteAccountFunction = 'delete-account';

/// Shown if anything stringifies this exception. The screen uses its own copy.
const accountDeletionGenericFailure = 'account deletion failed';

/// `delete-account` revokes the Sign in with Apple token, then calls
/// `delete_own_account` as the signed-in user. A missing function is
/// unavailable. Other failures use a fixed message and drop the response body.
Future<void> deleteOwnAccountWithClient(SupabaseClient client) {
  return deleteOwnAccountWithInvoker(
    (functionName, {body}) => client.functions.invoke(functionName, body: body),
  );
}

Future<void> deleteOwnAccountWithInvoker(EdgeFunctionInvoke invoke) async {
  try {
    final response = await invoke(deleteAccountFunction);
    _throwIfDeleteFailed(response.status, response.data);
  } on FunctionException catch (error) {
    if (error.status == 404) {
      throw AccountDeletionUnavailableException();
    }
    throw const AccountDeletionFailedException(accountDeletionGenericFailure);
  } on AccountDeletionUnavailableException {
    rethrow;
  } on AccountDeletionFailedException {
    rethrow;
  } catch (_) {
    throw const AccountDeletionFailedException(accountDeletionGenericFailure);
  }
}

void _throwIfDeleteFailed(int status, Object? data) {
  if (status == 404) {
    throw AccountDeletionUnavailableException();
  }
  if (status < 200 || status >= 300) {
    throw const AccountDeletionFailedException(accountDeletionGenericFailure);
  }
  if (data is Map && data['ok'] == false) {
    throw const AccountDeletionFailedException(accountDeletionGenericFailure);
  }
}
