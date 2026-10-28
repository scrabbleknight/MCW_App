import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:military_calisthenics_women/core/funnel/funnel_tracker.dart';
import 'package:military_calisthenics_women/core/theme/tactical_theme.dart';
import 'package:military_calisthenics_women/features/onboarding/application/onboarding_controller.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/onboarding_screen.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/experience_step.dart';
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
            onContinueWithoutAnalytics: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  test('label choice', () {
    expect(welcomeCtaLabel(agreementNeeded: true), 'Agree and Continue');
    expect(welcomeCtaLabel(agreementNeeded: false), 'Start Now');
  });

  testWidgets('EU: the button asks to agree, and tapping it grants consent', (
    tester,
  ) async {
    await pump(tester, const Locale('fr', 'FR'));
    expect(welcomeNeedsAgreement(), isTrue);
    expect(find.text('Agree and Continue'), findsOneWidget);
    expect(find.text('Start Now'), findsNothing);
    expect(funnel.consent, AnalyticsConsent.unknown);

    await tester.tap(find.text('Agree and Continue'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(funnel.consent, AnalyticsConsent.granted);
  });

  testWidgets('UK: the button keeps its old label', (tester) async {
    await pump(tester, const Locale('en', 'GB'));
    expect(welcomeNeedsAgreement(), isFalse);
    expect(find.text('Start Now'), findsOneWidget);
    expect(find.text('Agree and Continue'), findsNothing);
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
    expect(find.text('Agree and Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Same button size as before.
    expect(tester.getSize(find.byType(FilledButton)).height, 58);
  });

  const noAnalytics = 'Continue without analytics';

  testWidgets('EU: a "Continue without analytics" link under the button', (
    tester,
  ) async {
    await pump(tester, const Locale('fr', 'FR'));
    final link = find.text(noAnalytics);
    expect(link, findsOneWidget);
    // Under the button, and a text link rather than a button.
    expect(
      tester.getTopLeft(link).dy,
      greaterThan(tester.getBottomLeft(find.byType(FilledButton)).dy),
    );
    expect(
      find.ancestor(of: link, matching: find.byType(ButtonStyleButton)),
      findsNothing,
    );
    expect(
      find.ancestor(of: link, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      tester.widget<Text>(link).style?.decoration,
      TextDecoration.underline,
    );
  });

  testWidgets('GB: no link', (tester) async {
    await pump(tester, const Locale('en', 'GB'));
    expect(find.text(noAnalytics), findsNothing);
  });

  testWidgets('EU: the link fits on a 320pt-wide phone', (tester) async {
    await pump(
      tester,
      const Locale('nl', 'NL'),
      size: const Size(640, 1136),
      dpr: 2,
    );
    expect(find.text(noAnalytics), findsOneWidget);
    expect(tester.takeException(), isNull);
    final right = tester.getTopRight(find.text(noAnalytics)).dx;
    final left = tester.getTopLeft(find.text(noAnalytics)).dx;
    expect(left, greaterThanOrEqualTo(0));
    expect(right, lessThanOrEqualTo(320));
  });

  testWidgets('EU: tapping the link turns analytics off and moves on', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('it', 'IT');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final tracker = FunnelTracker(
      onboardingVersion: 'test',
      onboardingStepCount: 1,
      sink: _Sink(),
    );
    await tester.runAsync(tracker.load);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => OnboardingController()),
          ChangeNotifierProvider.value(value: tracker),
        ],
        child: MaterialApp(
          theme: TacticalTheme.dark(),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ExperienceStep), findsNothing);

    await tester.tap(find.text(noAnalytics));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tracker.consent, AnalyticsConsent.denied);
    expect(find.byType(ExperienceStep), findsOneWidget);
  });
}
