import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/notifications/workout_reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Workout reminder settings. Persists the toggle, chosen time and selected
/// weekdays, and keeps the scheduled local notifications in step with them.
class ReminderController extends ChangeNotifier {
  static const _kEnabled = 'reminder.enabled';
  static const _kHour = 'reminder.hour';
  static const _kMinute = 'reminder.minute';
  static const _kDays = 'reminder.days';

  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  Set<int> _days = const {1, 2, 3, 4, 5};
  bool _loaded = false;
  final Completer<void> _ready = Completer<void>();

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
      if (!_ready.isCompleted) _ready.complete();
      notifyListeners();
    }
    // Re-register on every launch so the schedule survives reinstalls and
    // time zone changes.
    await _schedule();
  }

  /// Called when the user allows notifications during onboarding, which
  /// promises workout reminders: turn them on with the default time and days.
  Future<void> enableFromOnboarding() async {
    // Let load() finish first, or its read of the stored "off" setting
    // would land after this and cancel the reminders scheduled here.
    await _ready.future;
    _enabled = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, true);
    await prefs.setStringList(_kDays, _days.map((e) => e.toString()).toList());
    await _schedule();
  }

  Future<void> setEnabled(bool value) async {
    // Turning reminders on is pointless without permission to post them.
    if (value && !await WorkoutReminders.instance.ensurePermission()) {
      value = false;
    }
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
    await _schedule();
  }

  Future<void> setTime(TimeOfDay t) async {
    _time = t;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHour, t.hour);
    await prefs.setInt(_kMinute, t.minute);
    await _schedule();
  }

  Future<void> toggleDay(int weekday) async {
    final next = {..._days};
    if (!next.remove(weekday)) next.add(weekday);
    _days = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kDays, next.map((e) => e.toString()).toList());
    await _schedule();
  }

  Future<void> _schedule() => WorkoutReminders.instance.schedule(
        enabled: _enabled,
        hour: _time.hour,
        minute: _time.minute,
        weekdays: _days,
      );
}
