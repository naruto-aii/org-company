import 'package:supabase_flutter/supabase_flutter.dart';

import 'apple_refresh_token.dart';
import 'auth_exceptions.dart';

/// Edge Function that revokes the Apple refresh token, then deletes the account.
const deleteAccountFunction = 'delete-account';

/// Shown if anything stringifies this exception. The screen uses its own copy.
const accountDeletionGenericFailure = 'account deletion failed';

/// `delete-account` revokes the Sign in with Apple token, then deletes the
/// account. The client does not call the database function itself. A missing
/// function throws [AccountDeletionUnavailableException] and leaves the account
/// and the session unchanged. Other failures use a fixed message and drop the
/// response body. [AccountDeletionOutcome.appleRevokeFailed] is set only when
/// a stored Apple token could not be revoked; the account is already deleted.
Future<AccountDeletionOutcome> deleteOwnAccountWithClient(
  SupabaseClient client,
) {
  return deleteOwnAccountWithInvoker(
    (functionName, {body}) => client.functions.invoke(functionName, body: body),
  );
}

Future<AccountDeletionOutcome> deleteOwnAccountWithInvoker(
  EdgeFunctionInvoke invoke,
) async {
  try {
    final response = await invoke(deleteAccountFunction);
    return _outcomeOrThrow(response.status, response.data);
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

AccountDeletionOutcome _outcomeOrThrow(int status, Object? data) {
  if (status == 404) {
    throw AccountDeletionUnavailableException();
  }
  if (status < 200 || status >= 300) {
    throw const AccountDeletionFailedException(accountDeletionGenericFailure);
  }
  if (data is Map && data['ok'] == false) {
    throw const AccountDeletionFailedException(accountDeletionGenericFailure);
  }
  final revokeFailed = data is Map && data['apple_revoke_failed'] == true;
  return AccountDeletionOutcome(appleRevokeFailed: revokeFailed);
}
