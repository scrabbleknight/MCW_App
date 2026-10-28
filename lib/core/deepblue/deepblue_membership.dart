// GENERATED from ViralEngine/deepblue-kit/dart/deepblue_membership.dart — edit it there and run `npm run deepblue:sync`.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'deepblue_config.dart';
import 'deepblue_membership_logic.dart';

export 'deepblue_membership_logic.dart';

/// DeepBlue All Access in the app: a sign-in to the central DeepBlue account
/// (Firebase project deepblue-members; deepblue.org.uk signs in to it) kept
/// entirely separate from the app's own sign-in, and the membership that
/// account has.
///
/// The membership is only ever granted by the central server (verified
/// Stripe webhooks). This class just asks `deepblueGetMembership` and caches
/// the answer for [DeepBlueMembershipSnapshot.offlineGrace].
///
/// It runs as its own named FirebaseApp ('deepblue'), so signing in or out
/// here never changes the user the app itself is signed in as.
class DeepBlueMembership extends ChangeNotifier {
  DeepBlueMembership._();

  static final instance = DeepBlueMembership._();

  static const _appName = 'deepblue';
  static const _region = 'europe-west2';
  static const _cacheKey = 'deepblue.membership';

  FirebaseAuth? _auth;
  FirebaseFunctions? _functions;
  StreamSubscription<User?>? _authSub;
  DeepBlueMembershipSnapshot _snapshot = DeepBlueMembershipSnapshot.none;
  bool _refreshing = false;
  String? _lastError;

  /// Off on a platform until its store's rules are met (see deepblue_config).
  bool get enabled {
    if (kIsWeb) return false;
    final platformOn = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => DeepBlueConfig.iosEnabled,
      TargetPlatform.android => DeepBlueConfig.androidEnabled,
      _ => false,
    };
    return platformOn && DeepBlueConfig.centralOptions != null;
  }

  bool get isReady => _auth != null;

  /// Signed in to a DeepBlue account (Google, Apple or phone).
  User? get user => _auth?.currentUser;

  DeepBlueMembershipSnapshot get snapshot => _snapshot;

  String? get lastError => _lastError;

  /// Called with a fresh DeepBlue ID token after every successful check, for
  /// apps whose premium lives on their own server (Glance passes it to its
  /// `linkDeepBlueMembership`, which re-checks it with the central project).
  Future<void> Function(String deepBlueIdToken)? onChecked;

  /// The entitlement: a live DeepBlue All Access membership on this device.
  bool get hasAccess => enabled && user != null && _snapshot.grantsAt(DateTime.now());

  /// Call once at startup, after the app's own Firebase.initializeApp.
  Future<void> init() async {
    if (!enabled || _auth != null) return;
    try {
      final app = Firebase.apps.any((a) => a.name == _appName)
          ? Firebase.app(_appName)
          : await Firebase.initializeApp(
              name: _appName,
              options: DeepBlueConfig.centralOptions,
            );
      _auth = FirebaseAuth.instanceFor(app: app);
      _functions = FirebaseFunctions.instanceFor(app: app, region: _region);
      await _loadCache();
      _authSub = _auth!.authStateChanges().listen((u) {
        if (u == null) {
          _setSnapshot(DeepBlueMembershipSnapshot.none);
        } else {
          unawaited(refresh());
        }
      });
    } catch (e) {
      debugPrint('[deepblue] init failed: $e');
    }
    notifyListeners();
  }

  /// Asks the server for the membership. Keeps the cached answer if the
  /// server can't be reached; replaces it with whatever the server says
  /// otherwise (so a cancellation or refund takes effect).
  Future<void> refresh() async {
    final functions = _functions;
    if (!enabled || functions == null || user == null || _refreshing) return;
    _refreshing = true;
    try {
      final res = await functions
          .httpsCallable('deepblueGetMembership')
          .call<Map<Object?, Object?>>();
      _lastError = null;
      _setSnapshot(
        DeepBlueMembershipSnapshot.fromServer(res.data, now: DateTime.now()),
      );
      final hook = onChecked;
      final token = hook == null ? null : await user?.getIdToken();
      if (hook != null && token != null) await hook(token);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[deepblue] membership check failed: ${e.code}');
      if (e.code == 'unauthenticated') _setSnapshot(DeepBlueMembershipSnapshot.none);
    } catch (e) {
      debugPrint('[deepblue] membership check failed: $e');
    } finally {
      _refreshing = false;
    }
  }

  // ── Sign-in ──────────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() => _run(
    () => _auth!.signInWithProvider(GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'})),
  );

  Future<void> signInWithApple() => _run(
    () => _auth!.signInWithProvider(AppleAuthProvider()..addScope('email')),
  );

  /// Sends a code by SMS. [onCodeSent] gets a function that finishes signing
  /// in with the code the user types. Android may sign in by itself when it
  /// reads the SMS; [onSignedIn] is called then.
  Future<void> startPhoneSignIn(
    String phoneNumber, {
    required void Function(Future<void> Function(String code) confirm) onCodeSent,
    required void Function(String message) onError,
    void Function()? onSignedIn,
  }) async {
    final auth = _auth;
    if (auth == null) return onError('DeepBlue sign-in isn\'t available.');
    await auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        await _run(() => auth.signInWithCredential(credential));
        onSignedIn?.call();
      },
      verificationFailed: (e) => onError(errorText(e)),
      codeSent: (verificationId, _) => onCodeSent(
        (code) => _run(
          () => auth.signInWithCredential(
            PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code),
          ),
        ),
      ),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> signOut() async {
    await _auth?.signOut();
    _setSnapshot(DeepBlueMembershipSnapshot.none);
  }

  Future<void> _run(Future<Object?> Function() signIn) async {
    if (_auth == null) throw StateError('DeepBlue sign-in isn\'t available.');
    await signIn();
    await refresh();
  }

  /// Words a user can act on.
  static String errorText(Object e) {
    final code = e is FirebaseException ? e.code : '';
    return switch (code) {
      'account-exists-with-different-credential' =>
        'This email already has a DeepBlue account with a different sign-in method. Use that one.',
      'invalid-phone-number' => 'Enter your number with the country code, for example +44 7700 900123.',
      'invalid-verification-code' => 'That code isn\'t right. Check the text message and try again.',
      'session-expired' => 'That code has expired. Send a new one.',
      'too-many-requests' => 'Too many attempts. Wait a few minutes and try again.',
      'web-context-canceled' || 'canceled' => 'Sign-in was cancelled.',
      'network-request-failed' => 'No connection. Check your internet and try again.',
      _ => 'Sign-in didn\'t work. Please try again.',
    };
  }

  // ── Cache ────────────────────────────────────────────────────────────────

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        _snapshot = DeepBlueMembershipSnapshot.fromJson(
          (jsonDecode(raw) as Map).cast<String, Object?>(),
        );
      }
    } catch (e) {
      debugPrint('[deepblue] cache unreadable: $e');
    }
  }

  void _setSnapshot(DeepBlueMembershipSnapshot s) {
    if (s == _snapshot) return;
    _snapshot = s;
    notifyListeners();
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(s.toJson()));
      } catch (_) {}
    }());
  }

  /// Delete Account: forgets the DeepBlue sign-in on this device (the
  /// DeepBlue account itself is managed at deepblue.org.uk/account).
  Future<void> reset() async {
    await signOut();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
