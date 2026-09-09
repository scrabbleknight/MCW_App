import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around [FirebaseMessaging] for onboarding-time permission
/// prompting and later token lookups. Kept intentionally minimal — deeper
/// routing (foreground handlers, background isolate, deep links) is wired in
/// separate call-sites once we know what payloads we're delivering.
class NotificationsController {
  const NotificationsController();

  /// Prompts the OS for notification permission. On iOS this pops the
  /// system alert; on Android 13+ it triggers the runtime permission. The
  /// returned [NotificationsPermission] tells the caller what to render
  /// next (settings deep-link if permanently denied, etc).
  Future<NotificationsPermission> requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return _mapStatus(settings.authorizationStatus);
    } catch (error, stack) {
      debugPrint('NotificationsController: requestPermission failed — $error');
      debugPrintStack(stackTrace: stack);
      return NotificationsPermission.unavailable;
    }
  }

  /// Fetches the current APNs / FCM token if permission has been granted.
  /// Returns null if the platform isn't ready yet (e.g. simulator without
  /// APNs sandbox).
  Future<String?> currentToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (error) {
      debugPrint('NotificationsController: getToken failed — $error');
      return null;
    }
  }

  NotificationsPermission _mapStatus(AuthorizationStatus status) =>
      switch (status) {
        AuthorizationStatus.authorized => NotificationsPermission.granted,
        AuthorizationStatus.provisional => NotificationsPermission.granted,
        AuthorizationStatus.denied => NotificationsPermission.denied,
        AuthorizationStatus.notDetermined =>
          NotificationsPermission.notDetermined,
      };
}

enum NotificationsPermission {
  granted,
  denied,
  notDetermined,
  unavailable,
}
