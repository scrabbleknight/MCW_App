// GENERATED from ViralEngine/funnel-kit/dart/test/analytics_environment_test.dart — edit it there and run `npm run funnel:sync`.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:military_calisthenics_women/core/funnel/analytics_environment.dart';
import 'package:military_calisthenics_women/core/funnel/funnel_tracker.dart';

void main() {
  String? why(FunnelEnvironment e) => e.excludedReason;

  group('iOS', () {
    FunnelEnvironment ios(
      String? installer, {
      bool release = true,
      String? appStore,
    }) => classifyInstall(
      platform: TargetPlatform.iOS,
      release: release,
      installer: installer,
      appStore: appStore,
    );

    test('an App Store install counts', () {
      expect(ios('com.apple').isProduction, isTrue);
      expect(ios('com.apple').installSource, 'app_store');
    });
    test(
      'TestFlight, Xcode, ad-hoc and App Review (sandbox receipt) are out',
      () {
        expect(why(ios('com.apple.testflight')), 'testflight');
      },
    );
    test(
      'the Simulator is out',
      () => expect(why(ios('com.apple.simulator')), 'simulator'),
    );
    test(
      'no receipt information still counts: never drop a user on a guess',
      () {
        expect(ios(null).isProduction, isTrue);
      },
    );
    test('a debug or profile build is out', () {
      expect(why(ios('com.apple', release: false)), 'debug_build');
    });

    group('the signed AppTransaction decides when it answers', () {
      test('production counts', () {
        expect(ios('com.apple', appStore: 'production').isProduction, isTrue);
        expect(
          ios('com.apple', appStore: 'production').installSource,
          'app_store',
        );
      });
      test(
        'sandbox (TestFlight, App Review) is out, though the receipt path '
        'looks like the App Store\'s (iOS 18 SDK and later)',
        () => expect(why(ios('com.apple', appStore: 'sandbox')), 'testflight'),
      );
      test(
        'a store-signed build run from Xcode is out',
        () => expect(why(ios('com.apple', appStore: 'xcode')), 'xcode'),
      );
      test('production beats a TestFlight-looking receipt path', () {
        expect(
          ios('com.apple.testflight', appStore: 'production').isProduction,
          isTrue,
        );
      });
      test('the Simulator is out whatever it says', () {
        expect(
          why(ios('com.apple.simulator', appStore: 'production')),
          'simulator',
        );
      });
      test('an unknown answer falls back to the receipt path', () {
        expect(ios('com.apple', appStore: 'local').isProduction, isTrue);
        expect(
          why(ios('com.apple.testflight', appStore: 'local')),
          'testflight',
        );
      });
    });
  });

  group('Android', () {
    FunnelEnvironment android(
      String? installer, {
      bool emulator = false,
      bool testLab = false,
    }) => classifyInstall(
      platform: TargetPlatform.android,
      release: true,
      installer: installer,
      android: AndroidInstallFacts(emulator: emulator, testLab: testLab),
    );

    test('a Google Play install on a phone counts', () {
      expect(android('com.android.vending').isProduction, isTrue);
      expect(android('com.android.vending').installSource, 'google_play');
    });
    test('Play pre-launch robots (Firebase Test Lab) are out, though Play installed them', () {
      expect(why(android('com.android.vending', testLab: true)), 'test_lab');
    });
    test(
      'an emulator is out',
      () => expect(why(android(null, emulator: true)), 'emulator'),
    );
    test('other installers and restores count, labelled', () {
      expect(
        android('com.sec.android.easyMover').installSource,
        'com.sec.android.easyMover',
      );
      expect(android(null).installSource, 'unknown');
      expect(android(null).isProduction, isTrue);
    });
  });
}
