import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Result of an attempted log-in.
enum LoginOutcome {
  /// Sign-in succeeded and the credential belongs to a pre-existing account.
  existingUser,

  /// Sign-in technically succeeded, but Firebase reports this is a new user.
  /// The transient session is signed back out — the caller should show the
  /// "no account found" message and route the user to sign-up instead.
  newUserRejected,

  /// Sign-up mode only: the credential belonged to an existing account. The
  /// session is signed back out — the caller should tell the user to log in
  /// instead of creating a new account.
  existingUserRejected,

  /// User cancelled the provider flow (dismissed Google/Apple sheet, etc.).
  cancelled,
}

class LoginResult {
  const LoginResult(this.outcome, {this.user, this.error});
  final LoginOutcome outcome;
  final User? user;
  final Object? error;
}

/// Centralized entry point for the app's third-party sign-in flows.
///
/// Every method that produces a real Firebase session runs through
/// [_completeSignIn], which enforces the log-in-only contract: if
/// `additionalUserInfo.isNewUser` is true, the session is signed out again
/// and the caller receives [LoginOutcome.newUserRejected] instead of a User.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  bool _googleInitialized = false;

  Future<LoginResult> signInWithGoogle({bool signUp = false}) async {
    try {
      final google = GoogleSignIn.instance;
      if (!_googleInitialized) {
        await google.initialize();
        _googleInitialized = true;
      }
      final account = await google.authenticate();
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        return const LoginResult(LoginOutcome.cancelled);
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return _completeSignIn(credential, signUp: signUp);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return const LoginResult(LoginOutcome.cancelled);
      }
      return LoginResult(LoginOutcome.cancelled, error: error);
    } catch (error) {
      debugPrint('AuthService: Google sign-in failed — $error');
      return LoginResult(LoginOutcome.cancelled, error: error);
    }
  }

  Future<LoginResult> signInWithApple({bool signUp = false}) async {
    try {
      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauth = OAuthProvider('apple.com').credential(
        idToken: appleCred.identityToken,
        accessToken: appleCred.authorizationCode,
      );
      final result = await _completeSignIn(oauth, signUp: signUp);
      // Apple only returns the user's name on the FIRST authorization for the
      // app. Capture it then and persist it as the Firebase displayName so the
      // profile screen has something friendlier than the email address.
      final user = result.user;
      if (user != null) {
        final current = user.displayName?.trim() ?? '';
        final given = appleCred.givenName?.trim() ?? '';
        final family = appleCred.familyName?.trim() ?? '';
        final full = [given, family].where((s) => s.isNotEmpty).join(' ');
        if (current.isEmpty && full.isNotEmpty) {
          try {
            await user.updateDisplayName(full);
            await user.reload();
          } catch (error) {
            debugPrint('AuthService: updateDisplayName failed — $error');
          }
        }
      }
      return result;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return const LoginResult(LoginOutcome.cancelled);
      }
      return LoginResult(LoginOutcome.cancelled, error: error);
    } catch (error) {
      debugPrint('AuthService: Apple sign-in failed — $error');
      return LoginResult(LoginOutcome.cancelled, error: error);
    }
  }

  /// Kicks off SMS verification for [phoneE164] (E.164 format, e.g.
  /// "+447700900123") and completes with the `verificationId` the caller
  /// will need to redeem the SMS code the user types in the next step.
  ///
  /// On Android, if Firebase silently verifies the number (SIM present,
  /// auto-retrieval), the session is signed in immediately and this future
  /// resolves with `PhoneAutoResult.autoVerified(result)` — the caller
  /// should check the type before showing the code-entry screen.
  Future<PhoneCodeChallenge> sendPhoneCode(
    String phoneE164, {
    bool signUp = false,
  }) async {
    final completer = Completer<PhoneCodeChallenge>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          final result = await _completeSignIn(credential, signUp: signUp);
          if (!completer.isCompleted) {
            completer.complete(PhoneCodeChallenge.autoVerified(result));
          }
        } catch (error) {
          if (!completer.isCompleted) completer.completeError(error);
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
      codeSent: (verificationId, resendToken) {
        if (!completer.isCompleted) {
          completer.complete(PhoneCodeChallenge.codeSent(verificationId));
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          completer.complete(PhoneCodeChallenge.codeSent(verificationId));
        }
      },
    );

    return completer.future;
  }

  Future<LoginResult> signInWithPhoneCode({
    required String verificationId,
    required String smsCode,
    bool signUp = false,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return _completeSignIn(credential, signUp: signUp);
    } catch (error) {
      debugPrint('AuthService: phone code sign-in failed — $error');
      return LoginResult(LoginOutcome.cancelled, error: error);
    }
  }

  /// Deletes the currently signed-in Firebase user. For providers that
  /// require it (Apple, per App Store guideline 5.1.1(v)) this first forces
  /// a fresh sign-in to obtain a short-lived authorization code, revokes it
  /// with Firebase, reauthenticates the user, and only then calls delete.
  ///
  /// Returns a [DeleteAccountResult] describing what happened so the UI can
  /// message the user without needing to interpret provider-specific errors.
  Future<DeleteAccountResult> deleteCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) return DeleteAccountResult.notSignedIn;

    final providers =
        user.providerData.map((p) => p.providerId).toSet();

    try {
      if (providers.contains('apple.com')) {
        final appleCred = await SignInWithApple.getAppleIDCredential(
          scopes: const [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        final authCode = appleCred.authorizationCode;
        final oauth = OAuthProvider('apple.com').credential(
          idToken: appleCred.identityToken,
          accessToken: authCode,
        );
        await user.reauthenticateWithCredential(oauth);
        try {
          await _auth.revokeTokenWithAuthorizationCode(authCode);
        } catch (error) {
          debugPrint('AuthService: Apple token revoke failed — $error');
        }
        await user.delete();
        return DeleteAccountResult.success;
      }

      if (providers.contains('google.com')) {
        final google = GoogleSignIn.instance;
        if (!_googleInitialized) {
          await google.initialize();
          _googleInitialized = true;
        }
        final account = await google.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) return DeleteAccountResult.cancelled;
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        await user.reauthenticateWithCredential(credential);
        await user.delete();
        return DeleteAccountResult.success;
      }

      // Phone (or anything else): no silent reauth we can do here. Try a
      // direct delete; if Firebase demands a recent login, tell the UI so
      // it can bounce the user back to the log-in screen.
      await user.delete();
      return DeleteAccountResult.success;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return DeleteAccountResult.cancelled;
      }
      return DeleteAccountResult.failed(error.toString());
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return DeleteAccountResult.cancelled;
      }
      return DeleteAccountResult.failed(error.toString());
    } on FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        return DeleteAccountResult.needsRecentLogin;
      }
      return DeleteAccountResult.failed(error.message ?? error.code);
    } catch (error) {
      return DeleteAccountResult.failed(error.toString());
    }
  }

  Future<LoginResult> _completeSignIn(
    AuthCredential credential, {
    required bool signUp,
  }) async {
    try {
      final result = await _auth.signInWithCredential(credential);
      final isNew = result.additionalUserInfo?.isNewUser ?? false;
      if (!signUp && isNew) {
        // Log-in-only: undo the account we just created and surface a
        // "no account" result to the UI.
        await _auth.signOut();
        return const LoginResult(LoginOutcome.newUserRejected);
      }
      if (signUp && !isNew) {
        // Sign-up-only: the credential matches an existing account. Sign the
        // transient session back out and tell the UI to bounce them to log-in.
        await _auth.signOut();
        return const LoginResult(LoginOutcome.existingUserRejected);
      }
      return LoginResult(LoginOutcome.existingUser, user: result.user);
    } on FirebaseAuthException catch (error) {
      debugPrint('AuthService: Firebase sign-in failed — ${error.code}');
      return LoginResult(LoginOutcome.cancelled, error: error);
    }
  }
}

/// Result of [AuthService.sendPhoneCode]. Either Firebase auto-verified the
/// number (Android SIM auto-fill) and produced a full [LoginResult], or an
/// SMS was sent and we now have a `verificationId` to redeem.
class PhoneCodeChallenge {
  const PhoneCodeChallenge._({this.verificationId, this.autoResult});

  factory PhoneCodeChallenge.codeSent(String verificationId) =>
      PhoneCodeChallenge._(verificationId: verificationId);

  factory PhoneCodeChallenge.autoVerified(LoginResult result) =>
      PhoneCodeChallenge._(autoResult: result);

  final String? verificationId;
  final LoginResult? autoResult;

  bool get wasAutoVerified => autoResult != null;
}

/// Result of [AuthService.deleteCurrentAccount].
class DeleteAccountResult {
  const DeleteAccountResult._(this.kind, [this.message]);

  final DeleteAccountKind kind;
  final String? message;

  static const success = DeleteAccountResult._(DeleteAccountKind.success);
  static const cancelled = DeleteAccountResult._(DeleteAccountKind.cancelled);
  static const notSignedIn =
      DeleteAccountResult._(DeleteAccountKind.notSignedIn);
  static const needsRecentLogin =
      DeleteAccountResult._(DeleteAccountKind.needsRecentLogin);

  factory DeleteAccountResult.failed(String message) =>
      DeleteAccountResult._(DeleteAccountKind.failed, message);
}

enum DeleteAccountKind {
  success,
  cancelled,
  notSignedIn,
  needsRecentLogin,
  failed,
}
