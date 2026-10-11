import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:military_calisthenics_women/core/platform/store_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps Apple HealthKit / Android Health Connect (via the `health`
/// package). Persists the user's connect toggle, requests permission on
/// enable, and exposes a [logWorkout] helper the workout screen calls after
/// a completed session.
///
/// iOS needs the HealthKit capability and NSHealth*UsageDescription keys;
/// Android needs the matching `android.permission.health.*` entries in
/// AndroidManifest.xml — all are already set up.
class HealthController extends ChangeNotifier {
  static const _kConnected = 'health.connected';

  final Health _health = Health();

  bool _connected = false;
  bool _busy = false;
  bool _loaded = false;

  bool get connected => _connected;
  bool get busy => _busy;
  bool get isLoaded => _loaded;

  static const List<HealthDataType> _iosTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.STEPS,
  ];

  static const List<HealthDataAccess> _iosAccess = [
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ,
  ];

  // Health Connect stores a workout's calories as a TotalCaloriesBurned
  // record, and Play review requires every requested permission to be
  // used — so Android only asks to write what [logWorkout] writes.
  static const List<HealthDataType> _androidTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  static const List<HealthDataAccess> _androidAccess = [
    HealthDataAccess.WRITE,
    HealthDataAccess.WRITE,
  ];

  Future<void> load() async {
    try {
      await _health.configure();
      final prefs = await SharedPreferences.getInstance();
      _connected = prefs.getBool(_kConnected) ?? false;
    } catch (error) {
      debugPrint('HealthController: load failed — $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// Toggling ON prompts the HealthKit / Health Connect permission sheet.
  /// Toggling OFF just stops us writing — the user revokes the OS-level
  /// permission themselves (Settings → Health on iOS, the Health Connect
  /// app on Android).
  Future<bool> setConnected(bool value) async {
    if (_busy) return _connected;
    if (value == _connected) return _connected;

    _busy = true;
    notifyListeners();
    try {
      if (value) {
        if (StorePlatform.isAndroid) {
          // Built in from Android 14; older phones need the Play Store app.
          final status = await _health.getHealthConnectSdkStatus();
          if (status != HealthConnectSdkStatus.sdkAvailable) {
            await _health.installHealthConnect();
            _connected = false;
            return false;
          }
        }
        final android = StorePlatform.isAndroid;
        final granted = await _health.requestAuthorization(
          android ? _androidTypes : _iosTypes,
          permissions: android ? _androidAccess : _iosAccess,
        );
        if (!granted) {
          _connected = false;
          return false;
        }
      }
      _connected = value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kConnected, _connected);
      return _connected;
    } catch (error) {
      debugPrint('HealthController: setConnected failed — $error');
      _connected = false;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Write a completed workout to HealthKit / Health Connect. Silent no-op when disconnected
  /// or on error — the workout still counts inside our own progress store.
  Future<void> logWorkout({
    required DateTime start,
    required DateTime end,
    required double activeEnergyKcal,
  }) async {
    if (!_connected) return;
    try {
      await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.CALISTHENICS,
        start: start,
        end: end,
        totalEnergyBurned: activeEnergyKcal.round(),
        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      );
    } catch (error) {
      debugPrint('HealthController: logWorkout failed — $error');
    }
  }
}
