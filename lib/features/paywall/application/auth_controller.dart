import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Minimal authentication controller.
///
/// Real Firebase auth is wired in; if Firebase failed to initialise, the
/// controller degrades to an anonymous local session so the rest of the app
/// keeps working.
class AuthController extends ChangeNotifier {
  User? _user;
  bool _loaded = false;
  StreamSubscription<User?>? _sub;

  bool get isLoaded => _loaded;
  User? get user => _user;
  String? get uid => _user?.uid;
  bool get hasAuthenticatedAccount => _user != null && !(_user?.isAnonymous ?? true);

  Future<void> load() async {
    try {
      final auth = FirebaseAuth.instance;
      _user = auth.currentUser;
      _sub = auth.authStateChanges().listen((user) {
        _user = user;
        notifyListeners();
      });
    } catch (error, stackTrace) {
      debugPrint('AuthController: Firebase Auth unavailable — $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      debugPrint('AuthController: signOut failed — $error');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
