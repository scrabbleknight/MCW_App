import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Session-time user preferences. Currently just the rest duration between
/// main exercises — a settings screen will eventually expose a slider that
/// writes back through [setRestSeconds]. Persisted so a user's chosen pace
/// survives relaunch.
class WorkoutSettingsController extends ChangeNotifier {
  static const _kRestSeconds = 'workout.rest_seconds';
  static const _defaultRestSeconds = 10;

  int _restSeconds = _defaultRestSeconds;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  int get restSeconds => _restSeconds;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _restSeconds = prefs.getInt(_kRestSeconds) ?? _defaultRestSeconds;
    } catch (error) {
      debugPrint('WorkoutSettingsController: load failed — $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setRestSeconds(int seconds) async {
    _restSeconds = seconds.clamp(5, 120);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kRestSeconds, _restSeconds);
  }
}
