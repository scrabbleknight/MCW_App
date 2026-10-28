import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:military_calisthenics_women/core/funnel/funnel_tracker.dart';
import 'package:military_calisthenics_women/core/theme/tactical_theme.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/welcome_step.dart';

class _Sink implements FunnelSink {
  @override
  Future<void> log(String name, Map<String, Object> params) async {}
  @override
  Future<void> setCollectionEnabled(bool on) async {}
  @override
  Future<String?> appInstanceId() async => null;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FunnelTracker funnel;

  Future<void> pump(
    WidgetTester tester,
    Locale locale, {
    Size size = const Size(1170, 2532),
    double dpr = 3,
  }) async {
    tester.platformDispatcher.localeTestValue = locale;
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    funnel = FunnelTracker(
      onboardingVersion: 'test',
      onboardingStepCount: 1,
      sink: _Sink(),
    );
    await tester.runAsync(funnel.load);
    await tester.pumpWidget(
      MaterialApp(
        theme: TacticalTheme.dark(),
        home: Scaffold(
          body: WelcomeStep(
            onContinue: () => funnel.acceptByContinuing(),
            onLogIn: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  test('label choice', () {
    expect(welcomeCtaLabel(agreementNeeded: true), 'AGREE AND CONTINUE');
    expect(welcomeCtaLabel(agreementNeeded: false), 'Start Now');
  });

  testWidgets('EU: the button asks to agree, and tapping it grants consent', (
    tester,
  ) async {
    await pump(tester, const Locale('fr', 'FR'));
    expect(welcomeNeedsAgreement(), isTrue);
    expect(find.text('AGREE AND CONTINUE'), findsOneWidget);
    expect(find.text('Start Now'), findsNothing);
    expect(funnel.consent, AnalyticsConsent.unknown);

    await tester.tap(find.text('AGREE AND CONTINUE'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(funnel.consent, AnalyticsConsent.granted);
  });

  testWidgets('UK: the button keeps its old label', (tester) async {
    await pump(tester, const Locale('en', 'GB'));
    expect(welcomeNeedsAgreement(), isFalse);
    expect(find.text('Start Now'), findsOneWidget);
    expect(find.text('AGREE AND CONTINUE'), findsNothing);
  });

  testWidgets('EU: the longer label fits on a 320pt-wide phone', (
    tester,
  ) async {
    await pump(
      tester,
      const Locale('de', 'DE'),
      size: const Size(640, 1136),
      dpr: 2,
    );
    expect(find.text('AGREE AND CONTINUE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Same button size as before.
    expect(tester.getSize(find.byType(FilledButton)).height, 58);
  });
}
