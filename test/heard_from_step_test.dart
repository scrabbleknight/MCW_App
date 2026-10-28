import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:military_calisthenics_women/core/funnel/funnel_tracker.dart';
import 'package:military_calisthenics_women/core/theme/tactical_theme.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/onboarding_screen.dart';
import 'package:military_calisthenics_women/features/onboarding/presentation/steps/heard_from_step.dart';

void main() {
  final completed = <(String, String?)>[];

  Future<void> pump(
    WidgetTester tester, {
    String? selected,
    String? otherText,
  }) async {
    completed.clear();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: TacticalTheme.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: HeardFromStep(
              selected: selected,
              otherText: otherText,
              onCompleted: (id, text) => completed.add((id, text)),
            ),
          ),
        ),
      ),
    );
  }

  bool continueEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed != null;

  Future<void> pick(WidgetTester tester, String id) async {
    final tile = find.byKey(ValueKey('heard_from_$id'));
    await tester.scrollUntilVisible(tile, 200);
    await tester.tap(tile);
    await tester.pump();
  }

  testWidgets('Continue is blocked until an option is picked', (
    tester,
  ) async {
    await pump(tester);
    expect(continueEnabled(tester), isFalse);
    await tester.tap(find.text('CONTINUE'));
    expect(completed, isEmpty);

    await pick(tester, 'tiktok');
    expect(continueEnabled(tester), isTrue);
    await tester.tap(find.text('CONTINUE'));
    expect(completed, [('tiktok', null)]);
  });

  testWidgets('Other needs some text before Continue', (tester) async {
    await pump(tester);
    expect(find.text('Tell us where'), findsNothing);

    await pick(tester, 'other');
    final box = find.byKey(const ValueKey('heard_from_other_text'));
    expect(box, findsOneWidget);
    expect(continueEnabled(tester), isFalse);

    await tester.enterText(box, '   ');
    await tester.pump();
    expect(continueEnabled(tester), isFalse);

    await tester.enterText(box, '  a podcast ');
    await tester.pump();
    expect(continueEnabled(tester), isTrue);
    await tester.tap(find.text('CONTINUE'));
    expect(completed, [('other', 'a podcast')]);
  });

  testWidgets('an earlier answer is kept when coming back', (tester) async {
    await pump(tester, selected: 'other', otherText: 'gym poster');
    expect(continueEnabled(tester), isTrue);
    final text = find.text('gym poster');
    await tester.scrollUntilVisible(text, 200);
    expect(text, findsOneWidget);
  });

  test('options are in order and every id is a known acquisition source', () {
    final ids = HeardFromStep.options.map((o) => o.$1).toList();
    expect(ids.take(7), [
      'tiktok',
      'instagram',
      'youtube',
      'facebook',
      'pinterest',
      'snapchat',
      'google',
    ]);
    expect(ids[7], anyOf('app_store', 'google_play'));
    expect(ids.skip(8), ['friends', 'other']);
    expect(FunnelTracker.acquisitionSources.containsAll(ids), isTrue);
  });

  test('onboarding funnel counts heard_from as a question screen', () {
    // Welcome, 38 earlier screens + heard_from, then paywall and reveal.
    expect(OnboardingScreen.funnelStepCount, 39);
    expect(OnboardingScreen.funnelVersion, isNot('v1'));
  });
}
