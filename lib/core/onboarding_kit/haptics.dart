import 'package:flutter/services.dart';

/// Haptic taps for onboarding controls, on both iOS and Android.
///
/// [HapticFeedback] needs no permission on either platform; on Android it
/// follows the phone's own "touch feedback" setting.
abstract final class OnboardingHaptics {
  /// Option tiles, toggles, back chevrons and small links.
  static void tap() => HapticFeedback.lightImpact();

  /// Primary call-to-action buttons.
  static void press() => HapticFeedback.mediumImpact();

  /// Ruler and slider notches, swiped carousel pages.
  static void tick() => HapticFeedback.selectionClick();

  /// [callback] with a [tap] first; null stays null so disabled controls
  /// stay disabled.
  static VoidCallback? onTap(VoidCallback? callback) => callback == null
      ? null
      : () {
          tap();
          callback();
        };

  /// [callback] with a [press] first; null stays null.
  static VoidCallback? onPress(VoidCallback? callback) => callback == null
      ? null
      : () {
          press();
          callback();
        };
}
