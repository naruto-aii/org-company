import 'dart:async';

import 'package:ayg/repositories/auth_exceptions.dart';
import 'package:ayg/repositories/authentication_repository.dart';

class MockAuthenticationRepository extends AuthenticationRepository {
  MockAuthenticationRepository({AuthUser? currentUser})
    : _currentUser = currentUser;

  AuthUser? _currentUser;
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  bool restoreSessionCalled = false;
  bool loginWithGoogleCalled = false;
  bool loginWithAppleCalled = false;
  bool logoutCalled = false;
  bool deleteOwnAccountCalled = false;
  bool simulateDeleteUnavailable = false;
  bool simulateDeleteFailure = false;
  bool simulateAppleRevokeFailed = false;
  String deleteFailureMessage = 'invalid_grant raw-token-body';
  bool simulateGoogleSignInCancelled = false;
  bool simulateGoogleSignInFailure = false;
  String googleSignInFailureMessage = 'Google sign-in failed.';
  bool simulateAppleSignInCancelled = false;
  bool simulateAppleSignInFailure = false;
  String appleSignInFailureMessage = 'Apple sign-in failed.';

  void setCurrentUser(AuthUser? user) {
    _currentUser = user;
    _controller.add(_currentUser);
  }

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  Future<void> restoreSession() async {
    restoreSessionCalled = true;
  }

  @override
  Future<void> loginWithGoogle() async {
    loginWithGoogleCalled = true;
    if (simulateGoogleSignInCancelled) {
      throw GoogleSignInCancelledException();
    }
    if (simulateGoogleSignInFailure) {
      throw GoogleSignInFailedException(googleSignInFailureMessage);
    }
    _currentUser = const AuthUser(
      id: 'test-user-id',
      email: 'test@example.com',
    );
    _controller.add(_currentUser);
  }

  @override
  Future<void> loginWithApple() async {
    loginWithAppleCalled = true;
    if (simulateAppleSignInCancelled) {
      throw AppleSignInCancelledException();
    }
    if (simulateAppleSignInFailure) {
      throw AppleSignInFailedException(appleSignInFailureMessage);
    }
    _currentUser = const AuthUser(
      id: 'test-user-id',
      email: 'test@example.com',
    );
    _controller.add(_currentUser);
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<AccountDeletionOutcome> deleteOwnAccount() async {
    deleteOwnAccountCalled = true;
    if (simulateDeleteUnavailable) {
      throw AccountDeletionUnavailableException();
    }
    if (simulateDeleteFailure) {
      throw AccountDeletionFailedException(deleteFailureMessage);
    }
    return AccountDeletionOutcome(appleRevokeFailed: simulateAppleRevokeFailed);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
