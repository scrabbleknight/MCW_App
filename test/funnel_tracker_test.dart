// GENERATED from ViralEngine/funnel-kit/dart/test/funnel_tracker_test.dart — edit it there and run `npm run funnel:sync`.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:military_calisthenics_women/core/funnel/funnel_tracker.dart';

class _Sink implements FunnelSink {
  final events = <(String, Map<String, Object>)>[];
  final enabled = <bool>[];

  @override
  Future<void> log(String name, Map<String, Object> params) async =>
      events.add((name, params));
  @override
  Future<void> setCollectionEnabled(bool on) async => enabled.add(on);
  @override
  Future<String?> appInstanceId() async => 'instance-1';
}

Future<(FunnelTracker, _Sink)> _tracker([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sink = _Sink();
  final t = FunnelTracker(
    onboardingVersion: 'v1',
    onboardingStepCount: 3,
    sink: sink,
  );
  await t.load();
  await Future<void>.delayed(Duration.zero);
  return (t, sink);
}

VerifiedPurchase _purchase(
  String id, {
  String? event = 'trial_start',
  bool isNew = true,
}) => VerifiedPurchase(
  event: event,
  isNew: isNew,
  transactionId: id,
  productId: 'annual',
  offer: 'trial',
  paid: false,
  environment: 'sandbox',
);

void main() {
  test('nothing is sent before consent; a yes sends what waited', () async {
    final (t, sink) = await _tracker();
    t.onboardingStarted();
    t.onboardingStepView('first', 0);
    await Future<void>.delayed(Duration.zero);
    expect(sink.events, isEmpty);
    expect(sink.enabled, isEmpty);
    await t.setConsent(true);
    t.onboardingStarted(); // once per install
    await Future<void>.delayed(Duration.zero);
    expect(sink.enabled, [true]);
    expect(sink.events.map((e) => e.$1), [
      'onboarding_started',
      'onboarding_step_view',
    ]);
  });

  test(
    'continuing from Welcome turns analytics on, unless Settings said no',
    () async {
      final (t, sink) = await _tracker();
      await t.acceptByContinuing();
      expect(t.consent, AnalyticsConsent.granted);
      expect(sink.enabled, [true]);

      final (off, offSink) = await _tracker({'funnel.consent.v1': 'denied'});
      await off.acceptByContinuing();
      expect(off.consent, AnalyticsConsent.denied);
      expect(offSink.enabled, isEmpty);
    },
  );

  test('acquisition survey sends known platforms only', () async {
    final (t, sink) = await _tracker({'funnel.consent.v1': 'granted'});
    t.acquisitionSurvey('tiktok');
    t.acquisitionSurvey('my mate Dave on a podcast');
    await Future<void>.delayed(Duration.zero);
    expect(sink.events.map((e) => (e.$1, e.$2['source'])), [
      ('acquisition_survey', 'tiktok'),
      ('acquisition_survey', 'other'),
    ]);
  });

  test('"Other" sends what was typed, tidied and cut to 100', () async {
    final (t, sink) = await _tracker({'funnel.consent.v1': 'granted'});
    t
      ..acquisitionSurvey('other', otherText: '  a   podcast\n')
      ..acquisitionSurvey('tiktok', otherText: 'ignored')
      ..acquisitionSurvey('other', otherText: 'x' * 150);
    await Future<void>.delayed(Duration.zero);
    expect(sink.events[0].$2['other_text'], 'a podcast');
    expect(sink.events[1].$2.containsKey('other_text'), isFalse);
    expect(sink.events[2].$2['other_text'], 'x' * 100);
  });

  test('a no discards what waited and sends nothing later', () async {
    final (t, sink) = await _tracker();
    t.onboardingStepView('first', 0);
    await t.setConsent(false);
    t.onboardingStepView('second', 1);
    await Future<void>.delayed(Duration.zero);
    expect(sink.events, isEmpty);
    expect(sink.enabled, isEmpty);
  });

  test('step views are 1-based and carry the onboarding version', () async {
    final (t, sink) = await _tracker({'funnel.consent.v1': 'granted'});
    t.onboardingStepView('gender', 0);
    await Future<void>.delayed(Duration.zero);
    final (name, params) = sink.events.single;
    expect(name, 'onboarding_step_view');
    expect(params['screen_id'], 'gender');
    expect(params['step_index'], 1);
    expect(params['onboarding_version'], 'v1');
    expect(params['step_count'], 3);
  });

  test(
    'completion and first core action are logged once per install',
    () async {
      final (t, sink) = await _tracker({'funnel.consent.v1': 'granted'});
      t
        ..onboardingComplete()
        ..onboardingComplete()
        ..firstCoreAction('session_complete')
        ..firstCoreAction('session_complete');
      await Future<void>.delayed(Duration.zero);
      expect(sink.events.map((e) => e.$1), [
        'onboarding_complete',
        'first_core_action',
      ]);
      expect(t.gatePlacement, PaywallPlacement.onboarding);
    },
  );

  test(
    'a verified purchase is logged once; restores and known ones never',
    () async {
      final (t, sink) = await _tracker({'funnel.consent.v1': 'granted'});
      t
        ..recordVerified(_purchase('tx1'))
        ..recordVerified(_purchase('tx1'))
        ..recordVerified(_purchase('tx2', event: null))
        ..recordVerified(_purchase('tx3', isNew: false))
        // Renewals StoreKit replays at launch stay in the server ledger.
        ..recordVerified(_purchase('tx4', event: 'subscription_renewed'))
        ..recordVerified(_purchase('tx5', event: 'trial_converted_to_paid'));
      await Future<void>.delayed(Duration.zero);
      expect(sink.events.map((e) => e.$1), ['trial_start']);
      expect(sink.events.single.$2['paid'], 0);
    },
  );

  test(
    'real money also logs GA purchase; trials and sandbox never',
    () async {
      final (t, sink) = await _tracker({'funnel.consent.v1': 'granted'});
      VerifiedPurchase paid(String id, String env) => VerifiedPurchase(
        event: 'purchase_verified',
        isNew: true,
        transactionId: id,
        productId: 'monthly',
        offer: 'none',
        paid: true,
        environment: env,
        value: 14.99,
        currency: 'GBP',
      );
      t
        ..recordVerified(_purchase('tx1'))
        ..recordVerified(paid('tx2', 'sandbox'))
        ..recordVerified(paid('tx3', 'production'))
        ..recordVerified(paid('tx3', 'production'));
      await Future<void>.delayed(Duration.zero);
      expect(sink.events.map((e) => e.$1), [
        'trial_start',
        'purchase_verified',
        'purchase_verified',
        'purchase',
      ]);
      expect(sink.events.last.$2, containsPair('value', 14.99));
      expect(sink.events.last.$2, containsPair('currency', 'GBP'));
      expect(sink.events.last.$2, containsPair('product_id', 'monthly'));
    },
  );

  test('paywall views are once per session per placement', () async {
    final (t, sink) = await _tracker({'funnel.consent.v1': 'granted'});
    t
      ..paywallView(paywallId: 'p', placement: 'gate')
      ..paywallView(paywallId: 'p', placement: 'gate');
    await Future<void>.delayed(Duration.zero);
    expect(sink.events.length, 1);
  });

  test('withdrawing consent turns collection off', () async {
    final (t, sink) = await _tracker({'funnel.consent.v1': 'granted'});
    await t.setConsent(false);
    t.firstCoreAction('x');
    await Future<void>.delayed(Duration.zero);
    expect(sink.enabled, [true, false]);
    expect(sink.events, isEmpty);
  });

  test('store errors map to categories, never raw messages', () {
    expect(PurchaseFailure.categorise('purchase_cancelled'), 'cancelled');
    expect(
      PurchaseFailure.categorise('BillingResponse.serviceUnavailable'),
      'network',
    );
    expect(PurchaseFailure.categorise('storekit2_purchase_pending'), 'pending');
    expect(PurchaseFailure.categorise('weird', 'something odd'), 'unknown');
  });

  test('an app without a consent question sends straight away', () async {
    SharedPreferences.setMockInitialValues({});
    final sink = _Sink();
    final t = FunnelTracker(
      onboardingVersion: 'v1',
      onboardingStepCount: 3,
      consentRequired: false,
      sink: sink,
    );
    // Even before load() finishes.
    t.paywallView(paywallId: 'p', placement: PaywallPlacement.feature);
    await Future<void>.delayed(Duration.zero);
    expect(sink.events.map((e) => e.$1), [FunnelEvents.paywallView]);
    await t.load();
    expect(t.consent, AnalyticsConsent.granted);
  });

  test('"Agree and Continue" in the EU and EEA, or with no region', () {
    expect(AnalyticsAgreement.needed('FR'), isTrue);
    expect(AnalyticsAgreement.needed('no'), isTrue);
    expect(AnalyticsAgreement.needed(''), isTrue);
    expect(AnalyticsAgreement.needed('GB'), isFalse);
    expect(AnalyticsAgreement.needed('US'), isFalse);
    expect(AnalyticsAgreement.needed('CH'), isFalse);
  });

  test('without a consent question, the Settings switch still turns it off',
      () async {
    SharedPreferences.setMockInitialValues({'funnel.consent.v1': 'denied'});
    final sink = _Sink();
    final t = FunnelTracker(
      onboardingVersion: 'v1',
      onboardingStepCount: 3,
      consentRequired: false,
      sink: sink,
    );
    await t.load();
    expect(t.consent, AnalyticsConsent.denied);
    t.firstCoreAction('x');
    await Future<void>.delayed(Duration.zero);
    expect(sink.events, isEmpty);
    await t.setConsent(true);
    t.paywallView(paywallId: 'p', placement: PaywallPlacement.feature);
    await Future<void>.delayed(Duration.zero);
    expect(sink.events.map((e) => e.$1), [FunnelEvents.paywallView]);
  });
}
