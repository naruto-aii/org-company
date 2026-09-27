/// サインインがユーザー操作でキャンセルされた。
abstract class SignInCancelledException implements Exception {}

/// サインインに失敗した。
abstract class SignInFailedException implements Exception {
  String get message;
}

/// Google Sign-In がユーザー操作でキャンセルされた。
class GoogleSignInCancelledException implements SignInCancelledException {
  @override
  String toString() => 'Google sign-in was cancelled.';
}

/// Google Sign-In / Supabase Auth が失敗した。
class GoogleSignInFailedException implements SignInFailedException {
  GoogleSignInFailedException(this.message);

  @override
  final String message;

  @override
  String toString() => message;
}

/// Sign in with Apple がユーザー操作でキャンセルされた。
class AppleSignInCancelledException implements SignInCancelledException {
  @override
  String toString() => 'Apple sign-in was cancelled.';
}

/// Sign in with Apple / Supabase Auth が失敗した。
class AppleSignInFailedException implements SignInFailedException {
  AppleSignInFailedException(this.message);

  @override
  final String message;

  @override
  String toString() => message;
}

/// 未使用の Web 専用リポジトリが、別の Apple 実装を持たないための印。
/// 実際のログインは SupabaseAuthenticationRepository だけが行う。
class AppleSignInUnavailableException implements Exception {
  @override
  String toString() => 'Apple sign-in is not available.';
}

/// 本番に delete_own_account がまだ無い。
class AccountDeletionUnavailableException implements Exception {
  @override
  String toString() => 'Account deletion is not available.';
}

/// アカウント削除に失敗した。
class AccountDeletionFailedException implements Exception {
  const AccountDeletionFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}
