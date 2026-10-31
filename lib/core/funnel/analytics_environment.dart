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
/// - iOS: the Simulator, TestFlight, Xcode / ad-hoc installs and App Review —
///   everything but an App Store receipt (package_info_plus reports
///   com.apple.simulator / com.apple.testflight; the App Store is com.apple);
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
  var android = const AndroidInstallFacts();
  try {
    installer = (await PackageInfo.fromPlatform()).installerStore;
  } catch (e) {
    debugPrint('[funnel] installer check failed, counting it: $e');
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    android = await AndroidInstallFacts.read();
  }
  return classifyInstall(
    platform: defaultTargetPlatform,
    release: release,
    installer: installer,
    android: android,
  );
}

/// The decision itself, kept apart so every case is tested.
FunnelEnvironment classifyInstall({
  required TargetPlatform platform,
  required bool release,
  String? installer,
  AndroidInstallFacts android = const AndroidInstallFacts(),
}) {
  if (!release) return const FunnelEnvironment.excluded('debug_build');
  switch (platform) {
    case TargetPlatform.iOS:
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

const environmentChannel = MethodChannel('swiftbee/funnel_environment');
