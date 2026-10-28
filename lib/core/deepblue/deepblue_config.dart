import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// DeepBlue All Access settings for THIS app. Written once by
/// deepblue-kit/sync.js and then edited by hand; sync never overwrites it.
abstract final class DeepBlueConfig {
  /// Google Play: recognising a membership bought on the web is allowed, as
  /// long as the app doesn't link to or advertise the web purchase.
  static const androidEnabled = true;

  /// Apple guideline 3.1.3(b) (Multiplatform Services): an iOS app may only
  /// unlock a web-bought subscription if the same subscription is also sold
  /// as an in-app purchase in that app. Keep false until this app sells an
  /// All Access in-app subscription that the central server also credits.
  static const iosEnabled = false;

  /// This app registered in the central DeepBlue Firebase project
  /// (deepblue-members). Public config, generated 2026-10-28. On iOS, Google
  /// sign-in also needs the URL scheme 'app-1-354080549560-ios-1abba788e6871affb4a24d'
  /// added to Info.plist before iosEnabled is turned on.
  static FirebaseOptions? get centralOptions => switch (defaultTargetPlatform) {
    TargetPlatform.android => const FirebaseOptions(
      apiKey: 'AIzaSyCP6XBd2IQa5BRKaNctSeb68ZWFflTLBK0',
      appId: '1:354080549560:android:564b95a2a3fbe866b4a24d',
      messagingSenderId: '354080549560',
      projectId: 'deepblue-members',
      storageBucket: 'deepblue-members.firebasestorage.app',
    ),
    TargetPlatform.iOS => const FirebaseOptions(
      apiKey: 'AIzaSyBOfGvcpeiUW5tIQeBS6KS0SC9JepXt8TI',
      appId: '1:354080549560:ios:1abba788e6871affb4a24d',
      messagingSenderId: '354080549560',
      projectId: 'deepblue-members',
      storageBucket: 'deepblue-members.firebasestorage.app',
      iosBundleId: 'com.swiftbee.militaryCalisthenicsWomen',
    ),
    _ => null,
  };
}
