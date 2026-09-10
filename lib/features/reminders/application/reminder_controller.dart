import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI-only workout reminder settings. Persists the toggle, chosen time, and
/// selected weekdays across relaunches. No OS-level notification is scheduled
/// yet — wire flutter_local_notifications to this controller when it lands.
class ReminderController extends ChangeNotifier {
  static const _kEnabled = 'reminder.enabled';
  static const _kHour = 'reminder.hour';
  static const _kMinute = 'reminder.minute';
  static const _kDays = 'reminder.days';

  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  Set<int> _days = const {1, 2, 3, 4, 5};
  bool _loaded = false;

  bool get enabled => _enabled;
  TimeOfDay get time => _time;
  Set<int> get days => _days;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kEnabled) ?? false;
      final h = prefs.getInt(_kHour) ?? 9;
      final m = prefs.getInt(_kMinute) ?? 0;
      _time = TimeOfDay(hour: h, minute: m);
      final raw = prefs.getStringList(_kDays);
      if (raw != null && raw.isNotEmpty) {
        _days = raw.map(int.parse).toSet();
      }
    } catch (error) {
      debugPrint('ReminderController: load failed — $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
  }

  Future<void> setTime(TimeOfDay t) async {
    _time = t;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHour, t.hour);
    await prefs.setInt(_kMinute, t.minute);
  }

  Future<void> toggleDay(int weekday) async {
    final next = {..._days};
    if (!next.remove(weekday)) next.add(weekday);
    _days = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kDays, next.map((e) => e.toString()).toList());
  }
}
