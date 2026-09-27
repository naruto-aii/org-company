import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../config/supabase_config.dart';
import '../config/web_auth_config.dart';
import 'account_deletion_rpc.dart';
import 'apple_refresh_token.dart';
import 'auth_exceptions.dart';
import 'authentication_repository.dart';
import 'google_sign_in_factory.dart';

/// Supabase Auth + Google / Apple Sign-In 実装。
///
/// Apple はここが唯一の実装。iOS / macOS は OS 標準シート、
/// Web / Android は Supabase の OAuth リダイレクト。
class SupabaseAuthenticationRepository extends AuthenticationRepository {
  SupabaseAuthenticationRepository({
    SupabaseClient? client,
    GoogleSignIn? googleSignIn,
  }) : _client = client ?? Supabase.instance.client,
       _googleSignIn =
           googleSignIn ??
           createGoogleSignIn(
             iosClientId: SupabaseConfig.googleIosClientId,
             webClientId: SupabaseConfig.googleWebClientId,
           );

  final SupabaseClient _client;
  final GoogleSignIn? _googleSignIn;

  @override
  AuthUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges {
    return _client.auth.onAuthStateChange.map(
      (event) => _mapUser(event.session?.user),
    );
  }

  @override
  Future<void> restoreSession() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      return;
    }

    try {
      await _client.auth.refreshSession();
    } catch (_) {
      try {
        await _client.auth.signOut();
      } catch (_) {}
    }
  }

  @override
  Future<void> loginWithGoogle() async {
    if (!SupabaseConfig.isGoogleConfigured) {
      throw GoogleSignInFailedException(
        'Googleログインの設定がありません。tool/dart_defines.local.json の GOOGLE_WEB_CLIENT_ID を入れてください。',
      );
    }

    if (kIsWeb) {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: WebAuthConfig.redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw GoogleSignInFailedException('Googleログイン画面を開けませんでした。');
      }
      return;
    }

    final googleSignIn = _googleSignIn;
    if (googleSignIn != null) {
      await _loginWithNativeGoogle(googleSignIn);
      return;
    }

    await _loginWithGoogleOAuth();
  }

  Future<void> _loginWithNativeGoogle(GoogleSignIn googleSignIn) async {
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw GoogleSignInCancelledException();
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw GoogleSignInFailedException(
        'Google の ID トークンを取得できませんでした。GOOGLE_IOS_CLIENT_ID と GOOGLE_WEB_CLIENT_ID を確認してください。',
      );
    }

    try {
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
    } on AuthException catch (error) {
      throw GoogleSignInFailedException(error.message);
    }
  }

  /// iOS クライアントがまだ無いときでも、既存の Web クライアントでログインできる。
  Future<void> _loginWithGoogleOAuth() async {
    if (_client.auth.currentSession != null) {
      return;
    }

    final sessionReady = Completer<void>();
    final subscription = _client.auth.onAuthStateChange.listen((event) {
      if (event.session != null && !sessionReady.isCompleted) {
        sessionReady.complete();
      }
    });

    try {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: SupabaseConfig.nativeAuthRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw GoogleSignInFailedException('Googleログイン画面を開けませんでした。');
      }
      await sessionReady.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw GoogleSignInFailedException(
            'Googleログインが完了しませんでした。Safari からカロナビに戻ったあと、もう一度試してください。Supabase の Redirect URLs に ${SupabaseConfig.nativeAuthRedirectUrl} があるかも確認してください。',
          );
        },
      );
    } on AuthException catch (error) {
      throw GoogleSignInFailedException(error.message);
    } finally {
      await subscription.cancel();
    }
  }

  /// Apple ID でログインする。
  ///
  /// - iOS / macOS: OS 標準のシートを出し、受け取った ID トークンで Supabase に
  ///   サインインする。成功したあと、authorization code だけを Edge Function に
  ///   渡す。交換に失敗してもログインは取り消さない。
  /// - それ以外（Web / Android）: Supabase の OAuth リダイレクトを使う。
  ///   この経路は authorization code をアプリに返さない。
  @override
  Future<void> loginWithApple() async {
    if (kIsWeb || !_supportsNativeApple) {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: WebAuthConfig.redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw AppleSignInFailedException(
          'Could not launch Apple sign-in browser.',
        );
      }
      return;
    }

    // リプレイ攻撃を防ぐため、生の nonce を Supabase に、
    // その SHA-256 を Apple に渡す。
    final rawNonce = _client.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw AppleSignInCancelledException();
      }
      throw AppleSignInFailedException(error.message);
    } on SignInWithAppleException catch (error) {
      throw AppleSignInFailedException(error.toString());
    }

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw AppleSignInFailedException('Apple ID token is missing.');
    }

    try {
      await finishNativeAppleSignIn(
        signIn: () => _client.auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: idToken,
          nonce: rawNonce,
        ),
        authorizationCode: credential.authorizationCode,
        storeCode: (code) => storeAppleAuthorizationCode(
          invoke: (functionName, {body}) =>
              _client.functions.invoke(functionName, body: body),
          authorizationCode: code,
        ),
      );
    } on AuthException catch (error) {
      throw AppleSignInFailedException(error.message);
    }
  }

  /// OS 標準のシートが使えるか（iOS / macOS のみ）。
  bool get _supportsNativeApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Future<void> logout() async {
    await _googleSignIn?.signOut();
    await _client.auth.signOut();
  }

  @override
  Future<AccountDeletionOutcome> deleteOwnAccount() {
    return deleteOwnAccountWithClient(_client);
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }
    return AuthUser(id: user.id, email: user.email);
  }
}

/// Supabase 未設定時のスタブ（常に未ログイン）。
class UnconfiguredAuthenticationRepository extends AuthenticationRepository {
  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> loginWithGoogle() async {
    throw StateError('Supabase is not configured.');
  }

  @override
  Future<void> loginWithApple() async {
    throw AppleSignInFailedException('Supabase is not configured.');
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AccountDeletionOutcome> deleteOwnAccount() async {
    throw AccountDeletionUnavailableException();
  }
}
