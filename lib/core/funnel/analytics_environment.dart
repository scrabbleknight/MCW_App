// GENERATED from ViralEngine/funnel-kit/dart/analytics_environment.dart — edit it there and run `npm run funnel:sync`.
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'funnel_tracker.dart';

/// Is this a store install by a real user? Pass to
/// `FunnelTracker(environment: detectFunnelEnvironment)`.
///
/// Left out (analytics never turns on, whatever the consent answer):
/// - debug and profile builds ([FunnelEnvironment.fromBuildMode]);
/// - the iOS Simulator and Android emulators (device_info_plus);
/// - TestFlight (the App Store receipt is a sandbox one: package_info_plus
///   reports the installer as com.apple.testflight);
/// - Firebase Test Lab, which runs Google Play's pre-launch reports
///   (Settings.System "firebase.test.lab", read by the app's MainActivity on
///   the [testLabChannel] channel).
///
/// Google Play's internal and closed testing tracks install from Play like
/// production, so they can't be told apart here. Anything that can't be
/// checked counts as production: a real user is never left out on a guess.
Future<FunnelEnvironment> detectFunnelEnvironment() async {
  final mode = FunnelEnvironment.fromBuildMode();
  if (!mode.isProduction) return mode;
  try {
    final installer = (await PackageInfo.fromPlatform()).installerStore;
    final device = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final ios = await device.iosInfo;
      if (!ios.isPhysicalDevice || installer == 'com.apple.simulator') {
        return const FunnelEnvironment.excluded('simulator');
      }
      if (installer == 'com.apple.testflight') {
        return const FunnelEnvironment.excluded('testflight');
      }
      return const FunnelEnvironment.production('app_store');
    }
    if (Platform.isAndroid) {
      final android = await device.androidInfo;
      if (!android.isPhysicalDevice) {
        return const FunnelEnvironment.excluded('emulator');
      }
      if (await _isTestLab()) {
        return const FunnelEnvironment.excluded('test_lab');
      }
      return FunnelEnvironment.production(switch (installer) {
        'com.android.vending' => 'google_play',
        null || '' => 'unknown',
        final other => other,
      });
    }
  } catch (e) {
    debugPrint('[funnel] environment check failed, counting it: $e');
  }
  return mode;
}

/// Android: MainActivity answers `isTestLab` with
/// `Settings.System.getString(contentResolver, "firebase.test.lab") == "true"`.
const testLabChannel = MethodChannel('swiftbee/funnel_environment');

Future<bool> _isTestLab() async {
  try {
    return await testLabChannel.invokeMethod<bool>('isTestLab') ?? false;
  } on MissingPluginException {
    return false; // an app that hasn't added the channel
  } catch (_) {
    return false;
  }
}
