import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps Apple HealthKit (via the `health` package). Persists the user's
/// connect toggle, requests read+write permission on enable, and exposes a
/// [logWorkout] helper the workout screen calls after a completed session.
///
/// Requires the HealthKit capability in Xcode and the NSHealth*UsageDescription
/// keys in Info.plist — both are already set up.
class HealthController extends ChangeNotifier {
  static const _kConnected = 'health.connected';

  final Health _health = Health();

  bool _connected = false;
  bool _busy = false;
  bool _loaded = false;

  bool get connected => _connected;
  bool get busy => _busy;
  bool get isLoaded => _loaded;

  static const List<HealthDataType> _types = [
    HealthDataType.WORKOUT,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.STEPS,
  ];

  static const List<HealthDataAccess> _access = [
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ,
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

  /// Toggling ON prompts the HealthKit permission sheet. Toggling OFF just
  /// stops us writing — iOS doesn't allow apps to revoke their own permission
  /// (the user does that in Settings → Health → Data Access & Devices).
  Future<bool> setConnected(bool value) async {
    if (_busy) return _connected;
    if (value == _connected) return _connected;

    _busy = true;
    notifyListeners();
    try {
      if (value) {
        final granted = await _health.requestAuthorization(
          _types,
          permissions: _access,
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

  /// Write a completed workout to HealthKit. Silent no-op when disconnected
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
