import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for an App Store / Google Play rating once per device, after the
/// user finishes their first workout.
///
/// Uses the OS's own review sheet (SKStoreReviewController on iOS, the Play
/// In-App Review API on Android) rather than a custom popup: Apple rejects
/// custom review prompts (guideline 5.6.1) and Google forbids asking anything
/// before showing the rating card. Both OSes rate-limit the sheet and may
/// silently not show it, so we never follow up with a store link here —
/// Settings → "Rate Us!" covers users who want to review on their own.
abstract final class ReviewPrompt {
  static const _requestedKey = 'review_prompt_requested';

  /// Requests the review sheet once [navigator] is back on its first route
  /// with nothing on top (celebration modals closed). No-op if it has been
  /// requested on this device before.
  static Future<void> requestWhenIdle(
    NavigatorState navigator, {
    Duration initialDelay = const Duration(milliseconds: 900),
    Duration timeout = const Duration(minutes: 2),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_requestedKey) ?? false) return;
    } catch (_) {
      return;
    }

    await Future<void>.delayed(initialDelay);
    final deadline = DateTime.now().add(timeout);
    while (navigator.mounted && navigator.canPop()) {
      if (DateTime.now().isAfter(deadline)) return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (!navigator.mounted) return;

    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_requestedKey, true);
      await review.requestReview();
    } catch (error) {
      debugPrint('ReviewPrompt: request failed — $error');
    }
  }
}
