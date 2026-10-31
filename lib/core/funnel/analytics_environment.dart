// GENERATED from ViralEngine/funnel-kit/dart/analytics_environment.dart — edit it there and run `npm run funnel:sync`.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'funnel_tracker.dart';

/// Is this a store install by a real user? Pass to
/// `FunnelTracker(environment: detectFunnelEnvironment)`.
///
/// Left out (analytics never turns on, whatever the consent answer):
/// - debug and profile builds ([FunnelEnvironment.fromBuildMode]);
/// - iOS: the Simulator, TestFlight, Xcode / ad-hoc installs and App Review.
///   StoreKit 2's signed AppTransaction says which App Store environment the
///   app came from (production, or sandbox for TestFlight and App Review, or
///   xcode), answered by the app's AppDelegate on [environmentChannel]. Where
///   it can't answer (iOS 15, offline before the App Store has vouched for
///   the install), the receipt's path decides as before: package_info_plus
///   reports com.apple.simulator / com.apple.testflight, the App Store
///   com.apple. Apps built with the iOS 18 SDK or later reportedly get an
///   App Store-style receipt path under TestFlight too, which is why the
///   AppTransaction comes first;
/// - Android: emulators and Firebase Test Lab, which runs Google Play's
///   pre-launch reports (both answered by the app's MainActivity on
///   [environmentChannel]).
///
/// Google Play's internal and closed testing tracks install from Play like
/// production, so they can't be told apart here. Anything that can't be
/// checked counts as production: a real user is never left out on a guess.
Future<FunnelEnvironment> detectFunnelEnvironment() async {
  final release = FunnelEnvironment.fromBuildMode().isProduction;
  if (!release) return FunnelEnvironment.fromBuildMode();
  String? installer;
  String? appStore;
  var android = const AndroidInstallFacts();
  try {
    installer = (await PackageInfo.fromPlatform()).installerStore;
  } catch (e) {
    debugPrint('[funnel] installer check failed, counting it: $e');
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    android = await AndroidInstallFacts.read();
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    appStore = await readAppStoreEnvironment();
  }
  return classifyInstall(
    platform: defaultTargetPlatform,
    release: release,
    installer: installer,
    appStore: appStore,
    android: android,
  );
}

/// The decision itself, kept apart so every case is tested.
FunnelEnvironment classifyInstall({
  required TargetPlatform platform,
  required bool release,
  String? installer,
  String? appStore,
  AndroidInstallFacts android = const AndroidInstallFacts(),
}) {
  if (!release) return const FunnelEnvironment.excluded('debug_build');
  switch (platform) {
    case TargetPlatform.iOS:
      if (installer == 'com.apple.simulator') {
        return const FunnelEnvironment.excluded('simulator');
      }
      switch (appStore) {
        case 'production':
          return const FunnelEnvironment.production('app_store');
        case 'sandbox':
          return const FunnelEnvironment.excluded('testflight');
        case 'xcode':
          return const FunnelEnvironment.excluded('xcode');
      }
      return switch (installer) {
        'com.apple.simulator' => const FunnelEnvironment.excluded('simulator'),
        'com.apple.testflight' => const FunnelEnvironment.excluded(
          'testflight',
        ),
        _ => const FunnelEnvironment.production('app_store'),
      };
    case TargetPlatform.android:
      if (android.emulator) return const FunnelEnvironment.excluded('emulator');
      if (android.testLab) return const FunnelEnvironment.excluded('test_lab');
      return FunnelEnvironment.production(switch (installer) {
        'com.android.vending' => 'google_play',
        null || '' => 'unknown',
        final other => other,
      });
    default:
      return const FunnelEnvironment.production();
  }
}

/// What MainActivity reports: an emulator by its hardware (ranchu / goldfish /
/// vbox86) or emulator build (sdk_gphone…, generic…), never by looser
/// heuristics that real phones can match; Test Lab by
/// `Settings.System "firebase.test.lab" == "true"`.
class AndroidInstallFacts {
  const AndroidInstallFacts({this.emulator = false, this.testLab = false});

  final bool emulator;
  final bool testLab;

  static Future<AndroidInstallFacts> read() async {
    try {
      final m = await environmentChannel.invokeMapMethod<String, Object?>(
        'environment',
      );
      return AndroidInstallFacts(
        emulator: m?['emulator'] == true,
        testLab: m?['testLab'] == true,
      );
    } on MissingPluginException {
      return const AndroidInstallFacts(); // an app that hasn't added the channel
    } catch (e) {
      debugPrint('[funnel] Android environment check failed, counting it: $e');
      return const AndroidInstallFacts();
    }
  }
}

/// iOS: the App Store environment of the signed AppTransaction —
/// 'production', 'sandbox' (TestFlight, App Review) or 'xcode' — or null
/// when it can't be had: iOS 15, an app without the channel, or no answer
/// within [timeout] (the App Store is asked when nothing is cached).
Future<String?> readAppStoreEnvironment({
  Duration timeout = const Duration(seconds: 4),
}) async {
  try {
    final m = await environmentChannel
        .invokeMapMethod<String, Object?>('environment')
        .timeout(timeout);
    final env = m?['appStore'];
    return env is String ? env : null;
  } on MissingPluginException {
    return null;
  } catch (e) {
    debugPrint('[funnel] App Store environment check failed: $e');
    return null;
  }
}

const environmentChannel = MethodChannel('swiftbee/funnel_environment');
