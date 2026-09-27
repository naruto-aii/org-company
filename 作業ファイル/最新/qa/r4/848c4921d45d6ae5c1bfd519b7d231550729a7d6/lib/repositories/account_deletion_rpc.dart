import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_exceptions.dart';

/// `public.delete_own_account()` を呼ぶ。関数が無いときは unavailable。
Future<void> deleteOwnAccountWithClient(SupabaseClient client) async {
  try {
    await client.rpc('delete_own_account');
  } on PostgrestException catch (error) {
    if (_isMissingFunction(error)) {
      throw AccountDeletionUnavailableException();
    }
    throw AccountDeletionFailedException(error.message);
  }
}

bool _isMissingFunction(PostgrestException error) {
  final code = error.code ?? '';
  final message = error.message.toLowerCase();
  if (code == 'PGRST202' || code == '42883') {
    return true;
  }
  return message.contains('delete_own_account') &&
      (message.contains('does not exist') ||
          message.contains('not find') ||
          message.contains('could not find'));
}
