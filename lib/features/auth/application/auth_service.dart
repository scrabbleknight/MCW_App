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

  Future<LoginResult> signInWithGoogle() async {
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
      return _completeSignIn(credential);
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

  Future<LoginResult> signInWithApple() async {
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
      return _completeSignIn(oauth);
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
  Future<PhoneCodeChallenge> sendPhoneCode(String phoneE164) async {
    final completer = Completer<PhoneCodeChallenge>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          final result = await _completeSignIn(credential);
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
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return _completeSignIn(credential);
    } catch (error) {
      debugPrint('AuthService: phone code sign-in failed — $error');
      return LoginResult(LoginOutcome.cancelled, error: error);
    }
  }

  Future<LoginResult> _completeSignIn(AuthCredential credential) async {
    try {
      final result = await _auth.signInWithCredential(credential);
      final isNew = result.additionalUserInfo?.isNewUser ?? false;
      if (isNew) {
        // Log-in-only: undo the account we just created and surface a
        // "no account" result to the UI.
        await _auth.signOut();
        return const LoginResult(LoginOutcome.newUserRejected);
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
