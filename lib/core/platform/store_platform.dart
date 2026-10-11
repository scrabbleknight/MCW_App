import 'package:flutter/foundation.dart';

/// Store- and OS-specific identifiers and copy, so screens don't hard-code
/// App Store / Apple wording that would be wrong (and rejected) on Google
/// Play.
abstract final class StorePlatform {
  static const _appStoreId = '6809903076';
  static const androidPackage = 'com.swiftbee.military_calisthenics_women';

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Sign in with Apple only works natively on Apple platforms; on Android
  /// it would need a separate web Services ID flow, so we hide it there.
  static bool get supportsAppleSignIn => !isAndroid;

  static String get storeName => isAndroid ? 'Google Play' : 'App Store';

  /// "Google account" / "Apple ID" — the identity the store bills.
  static String get billingAccountName =>
      isAndroid ? 'Google Play account' : 'Apple ID';

  /// Name of the OS health store the app syncs workouts with.
  static String get healthAppName =>
      isAndroid ? 'Health Connect' : 'Apple Health';

  static Uri get manageSubscriptionsUri => isAndroid
      ? Uri.parse(
          'https://play.google.com/store/account/subscriptions'
          '?package=$androidPackage',
        )
      : Uri.parse('https://apps.apple.com/account/subscriptions');

  /// Play Store listing links open straight in the Play Store app on
  /// Android, where the review box sits on the listing itself.
  static Uri get writeReviewUri => isAndroid
      ? Uri.parse(
          'https://play.google.com/store/apps/details?id=$androidPackage',
        )
      : Uri.parse(
          'https://apps.apple.com/app/id$_appStoreId?action=write-review',
        );

  /// Completes "Manage or cancel any time in …".
  static String get manageSubscriptionsLocation => isAndroid
      ? 'the Play Store under Payments & subscriptions'
      : 'your device Settings';

  /// Where the user goes to cancel a subscription themselves.
  static String get cancelSubscriptionInstructions => isAndroid
      ? 'Your subscription is billed through Google Play and won\'t be '
            'cancelled automatically. To stop future charges, open the Play '
            'Store app → tap your profile icon → Payments & subscriptions → '
            'Subscriptions, then cancel this app.'
      : "Your App Store subscription is billed by Apple and won't "
            'be cancelled automatically. To stop future charges, open '
            'the iPhone Settings app → tap your name → Subscriptions, '
            'then cancel this app.';
}
