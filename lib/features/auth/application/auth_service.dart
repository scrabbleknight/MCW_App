import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:military_calisthenics_women/core/platform/store_platform.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Result of an attempted log-in.
enum LoginOutcome {
  /// Sign-in succeeded — either an existing account or a newly created one.
  signedIn,

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
/// Log in and sign up are the same operation: every method that produces a
/// real Firebase session runs through [_completeSignIn], which accepts both
/// new and returning users. (Rejecting one or the other can't work because
/// `signInWithCredential` has already created the Firebase user by the time
/// `isNewUser` is known — the user would be locked out of both screens.)
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
      return await _completeSignIn(credential);
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
      final result = await _completeSignIn(oauth);
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
      return await _completeSignIn(credential);
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

    final providers = user.providerData.map((p) => p.providerId).toSet();
    final usesAppleSignIn =
        providers.contains('apple.com') && StorePlatform.supportsAppleSignIn;

    // Delete on the server where we can: no "sign in again" step needed.
    // Apple accounts keep the flow below, because Apple requires revoking
    // their token with a fresh authorization code.
    if (!usesAppleSignIn && await _deleteOnServer()) {
      return DeleteAccountResult.success;
    }

    try {
      if (usesAppleSignIn) {
        final appleCred = await SignInWithApple.getAppleIDCredential(
          scopes: const [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        final authCode = appleCred.authorizationCode;
        final oauth = OAuthProvider(
          'apple.com',
        ).credential(idToken: appleCred.identityToken, accessToken: authCode);
        await user.reauthenticateWithCredential(oauth);
        try {
          await _auth.revokeTokenWithAuthorizationCode(authCode);
        } catch (error) {
          debugPrint('AuthService: Apple token revoke failed — $error');
        }
        await _deleteUserData(user.uid);
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
        await _deleteUserData(user.uid);
        await user.delete();
        return DeleteAccountResult.success;
      }

      // Phone (or anything else): no silent reauth we can do here. Try a
      // direct delete; if Firebase demands a recent login, tell the UI so
      // it can bounce the user back to the log-in screen.
      await _deleteUserData(user.uid);
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

  /// Calls the `deleteAccount` Cloud Function (functions/index.js), which
  /// deletes the caller's account and feedback with the Admin SDK — no
  /// recent sign-in needed. Returns false if it couldn't, so the caller can
  /// fall back to deleting from the app.
  Future<bool> _deleteOnServer() async {
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west2',
      ).httpsCallable('deleteAccount').call<void>();
      // The account no longer exists; drop the stale local session.
      await _auth.signOut();
      return true;
    } catch (error) {
      debugPrint('AuthService: server delete failed — $error');
      return false;
    }
  }

  /// Deletes the workout feedback stored under [uid] in Firestore. Best
  /// effort: a failure here must not block deleting the account itself.
  Future<void> _deleteUserData(String uid) async {
    final firestore = FirebaseFirestore.instance;
    for (final collection in ['session_feedback', 'quit_feedback']) {
      try {
        final parent = firestore.collection(collection).doc(uid);
        final entries = await parent.collection('entries').get();
        for (final doc in entries.docs) {
          await doc.reference.delete();
        }
        await parent.delete();
      } catch (error) {
        debugPrint('AuthService: deleting $collection failed — $error');
      }
    }
  }

  Future<LoginResult> _completeSignIn(AuthCredential credential) async {
    // Someone who used a referral code before making an account is signed
    // in anonymously, and their referral record hangs off that uid. Turn
    // that user into the real account so the record comes with them. If the
    // account already exists, sign in to it instead.
    final anonymous = _auth.currentUser;
    if (anonymous != null && anonymous.isAnonymous) {
      try {
        final result = await anonymous.linkWithCredential(credential);
        return LoginResult(LoginOutcome.signedIn, user: result.user);
      } on FirebaseAuthException catch (error) {
        const alreadyAnAccount = {
          'credential-already-in-use',
          'email-already-in-use',
          'account-exists-with-different-credential',
        };
        if (!alreadyAnAccount.contains(error.code)) {
          debugPrint('AuthService: linking failed — ${error.code}');
          return LoginResult(LoginOutcome.cancelled, error: error);
        }
        // Phone and Apple credentials are single-use; Firebase hands back a
        // fresh one with the error.
        credential = error.credential ?? credential;
      }
    }
    try {
      final result = await _auth.signInWithCredential(credential);
      return LoginResult(LoginOutcome.signedIn, user: result.user);
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
  static const notSignedIn = DeleteAccountResult._(
    DeleteAccountKind.notSignedIn,
  );
  static const needsRecentLogin = DeleteAccountResult._(
    DeleteAccountKind.needsRecentLogin,
  );

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
