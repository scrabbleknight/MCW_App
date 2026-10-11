import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the weekly workout reminders as local notifications, so they
/// fire on time even with the app closed and without a server.
class WorkoutReminders {
  WorkoutReminders._();

  static final WorkoutReminders instance = WorkoutReminders._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // One ID per weekday so each can be replaced on its own.
  static const _idBase = 100; // + weekday (1–7)

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'workout_reminders',
      'Workout reminders',
      channelDescription: 'A nudge on the days you train.',
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Registers the plugin without asking for permission, so no system sheet
  /// appears at launch before the user has been told why.
  Future<void> _initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    try {
      await _plugin.initialize(settings);
      _initialized = true;
    } catch (error) {
      debugPrint('WorkoutReminders: initialize failed — $error');
    }
    // Reminders fire at a wall-clock time, so they need the device's zone.
    try {
      tz_data.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (error) {
      debugPrint('WorkoutReminders: time zone setup failed — $error');
    }
  }

  /// Replaces the reminders: one at [hour]:[minute] on each of [weekdays]
  /// (DateTime.monday … DateTime.sunday), or none when [enabled] is false.
  Future<void> schedule({
    required bool enabled,
    required int hour,
    required int minute,
    required Set<int> weekdays,
  }) async {
    await _initialize();
    try {
      for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
        await _plugin.cancel(_idBase + day);
      }
      if (!enabled) return;
      for (final day in weekdays) {
        await _plugin.zonedSchedule(
          _idBase + day,
          'Time to train',
          "Today's workout is ready. Let's get it done.",
          _nextWeekdayAt(day, hour, minute),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } catch (error) {
      debugPrint('WorkoutReminders: schedule failed — $error');
    }
  }

  /// Cancels every reminder (used when the account is deleted).
  Future<void> cancelAll() async {
    await _initialize();
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('WorkoutReminders: cancelAll failed — $error');
    }
  }

  /// Whether the OS lets us post notifications, asking once if it doesn't.
  Future<bool> ensurePermission() async {
    await _initialize();
    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (await android?.areNotificationsEnabled() ?? false) return true;
        return await android?.requestNotificationsPermission() ?? false;
      }
      if (Platform.isIOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final current = await ios?.checkPermissions();
        if (current?.isEnabled ?? false) return true;
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (error) {
      debugPrint('WorkoutReminders: permission check failed — $error');
    }
    return false;
  }

  tz.TZDateTime _nextWeekdayAt(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    // Step by calendar day (not 24 hours) so the time survives clock changes.
    for (var offset = 0; ; offset++) {
      final at = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + offset,
        hour,
        minute,
      );
      if (at.weekday == weekday && at.isAfter(now)) return at;
    }
  }
}
