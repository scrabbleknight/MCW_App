import 'dart:async';
import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:military_calisthenics_women/core/funnel/funnel_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Crashlytics: crashes and uncaught errors from real installs.
///
/// Collection is off natively (Info.plist FirebaseCrashlyticsCollectionEnabled,
/// AndroidManifest firebase_crashlytics_collection_enabled) and only turns on
/// with the same analytics consent as the funnel ([applyConsent]). Reports
/// held on the phone from before the answer are sent on a yes and deleted on
/// a no. No user id is ever set: a report carries Crashlytics' own random
/// installation id, the device model, OS and app version, and the stack.
///
/// Debug builds never report, unless built with
/// `--dart-define=CRASHLYTICS_IN_DEBUG=true` to test the setup. A build with
/// `--dart-define=CRASHLYTICS_TEST_CRASH=true` also crashes once, a few
/// seconds after reporting turns on, to check reports arrive.
abstract final class CrashReporting {
  static const _inDebug = bool.fromEnvironment('CRASHLYTICS_IN_DEBUG');
  static const _testCrash = bool.fromEnvironment('CRASHLYTICS_TEST_CRASH');
  static const _kTestCrashed = 'crash_reporting.test_crashed';

  static bool get _buildMayReport => !kDebugMode || _inDebug;

  static AnalyticsConsent? _applied;

  /// Null when Firebase didn't start (degraded launch): everything no-ops.
  static FirebaseCrashlytics? get _crashlytics {
    try {
      return FirebaseCrashlytics.instance;
    } catch (_) {
      return null;
    }
  }

  /// Sends Flutter framework errors and uncaught async errors to
  /// Crashlytics (only once collection is on). Call after Firebase starts.
  static void install() {
    if (_crashlytics == null) return;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      _crashlytics?.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Uncaught: $error');
      _crashlytics?.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Follows the analytics consent answer: on for yes, off for no or not
  /// yet answered (reports wait on the phone until then).
  static Future<void> applyConsent(AnalyticsConsent consent) async {
    if (_applied == consent) return;
    _applied = consent;
    final on = consent == AnalyticsConsent.granted && _buildMayReport;
    final c = _crashlytics;
    if (c == null) return;
    try {
      await c.setCrashlyticsCollectionEnabled(on);
      if (on) {
        await c.sendUnsentReports();
        if (_testCrash) unawaited(_crashOnceForTest(c));
      } else if (consent == AnalyticsConsent.denied) {
        await c.deleteUnsentReports();
      }
    } catch (e) {
      debugPrint('[crash] applying consent failed: $e');
    }
  }

  static Future<void> _crashOnceForTest(FirebaseCrashlytics c) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kTestCrashed) ?? false) return;
    await prefs.setBool(_kTestCrashed, true);
    await c.recordError(
      StateError('Crashlytics test: non-fatal'),
      StackTrace.current,
      reason: 'CRASHLYTICS_TEST_CRASH build',
    );
    await Future<void>.delayed(const Duration(seconds: 5));
    c.crash();
  }
}
