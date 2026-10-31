// GENERATED from ViralEngine/funnel-kit/dart/test/recovery_offer_test.dart — edit it there and run `npm run funnel:sync`.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:military_calisthenics_women/core/funnel/funnel_tracker.dart';
import 'package:military_calisthenics_women/core/funnel/recovery_offer.dart';

Future<FunnelEnvironment> _store() async =>
    const FunnelEnvironment.production('google_play');

class _Sink implements FunnelSink {
  final events = <(String, Map<String, Object>)>[];

  @override
  Future<void> log(String name, Map<String, Object> params) async =>
      events.add((name, params));
  @override
  Future<void> setCollectionEnabled(bool on) async {}
  @override
  Future<String?> appInstanceId() async => null;
}

RecoveryPricePhase _phase(
  int micros,
  String formatted,
  String period, {
  int cycles = 1,
  bool finite = true,
  String currency = 'GBP',
}) => RecoveryPricePhase(
  priceMicros: micros,
  formattedPrice: formatted,
  currency: currency,
  billingPeriod: period,
  cycles: cycles,
  finite: finite,
);

final _trial = _phase(0, 'Free', 'P1W');
final _discount = _phase(11240000, '£11.24', 'P1M');
final _regular = _phase(14990000, '£14.99', 'P1M', cycles: 0, finite: false);

RecoveryOfferTerms? _play(List<RecoveryPricePhase> phases) =>
    RecoveryOfferTerms.fromPlayPhases(
      productId: 'rescue',
      offerId: 'recovery-7d-25',
      phases: phases,
    );

void main() {
  group('Play phases', () {
    test('7 days free, a month 25% off, then the base plan', () {
      final t = _play([_trial, _discount, _regular])!;
      expect(t.trialDays, 7);
      expect(t.discountedPrice, '£11.24');
      expect(t.regularPrice, '£14.99');
      expect(t.discountPercent, 25);
      expect(t.firstPaymentPrice, '£11.24');
      expect(t.currency, 'GBP');
      final start = DateTime(2026, 11, 1, 15);
      expect(t.firstPaymentDate(start), DateTime(2026, 11, 8));
      expect(t.regularPriceDate(start), DateTime(2026, 12, 8));
    });

    test('a P7D trial reads as 7 days; a trial alone has no discount', () {
      final t = _play([_phase(0, 'Free', 'P7D'), _regular])!;
      expect(t.trialDays, 7);
      expect(t.hasDiscount, isFalse);
      expect(t.discountPercent, isNull);
      expect(t.firstPaymentPrice, '£14.99');
    });

    test('anything else is no offer, never a guess', () {
      // No free first phase.
      expect(_play([_discount, _regular]), isNull);
      // Discount no cheaper than the regular price.
      expect(_play([_trial, _phase(14990000, '£14.99', 'P1M'), _regular]), isNull);
      // Discount for more than one month.
      expect(_play([_trial, _phase(11240000, '£11.24', 'P1M', cycles: 2), _regular]), isNull);
      // Yearly base plan.
      expect(_play([_trial, _phase(49990000, '£49.99', 'P1Y', finite: false)]), isNull);
      // Base plan missing.
      expect(_play([_trial, _discount]), isNull);
      // Mixed currencies.
      expect(_play([_trial, _phase(11240000, '€11.24', 'P1M', currency: 'EUR'), _regular]), isNull);
    });
  });

  group('App Store intro', () {
    RecoveryOfferTerms? ios({bool free = true, int units = 1, int unitDays = 7, int months = 1}) =>
        RecoveryOfferTerms.fromAppStoreIntro(
          productId: 'monthly.recovery',
          regularPrice: '£14.99',
          regularAmount: 14.99,
          currency: 'GBP',
          freeTrial: free,
          trialUnits: units,
          trialUnitDays: unitDays,
          trialPeriods: 1,
          productPeriodMonths: months,
        );

    test('a one-week free trial on a monthly product', () {
      final t = ios()!;
      expect(t.trialDays, 7);
      expect(t.hasDiscount, isFalse);
      expect(t.offerId, 'intro');
    });

    test('pay-as-you-go intro offers and yearly products are refused', () {
      expect(ios(free: false), isNull);
      expect(ios(months: 12), isNull);
      expect(ios(unitDays: 0), isNull);
    });
  });

  group('copy', () {
    test('Play: says the discount, both prices and the first payment date', () {
      final c = RecoveryOfferCopy(
        _play([_trial, _discount, _regular])!,
        isAndroid: true,
        now: DateTime(2026, 11, 1),
      );
      expect(c.subhead, 'Try everything FREE for 7 days, plus get 25% off your first month.');
      expect(c.timeline.map((s) => s.$1), ['Today', '8 November 2026', '8 December 2026']);
      expect(c.disclosure, contains('£11.24 is taken on 8 November 2026'));
      expect(c.disclosure, contains('renews automatically every month at £14.99'));
      expect(c.disclosure, contains('Google Play'));
      expect(c.declineCta(leaving: true), "No thanks, I'll leave");
    });

    test('iOS: no discount is claimed', () {
      final c = RecoveryOfferCopy(
        _play([_trial, _regular])!,
        isAndroid: false,
        now: DateTime(2026, 11, 1),
      );
      expect(c.subhead, 'Try everything FREE for 7 days.');
      expect(c.subhead, isNot(contains('%')));
      expect(c.disclosure, isNot(contains('%')));
      expect(c.timeline, hasLength(2));
      expect(c.disclosure, contains('Apple ID'));
      expect(c.declineCta(leaving: false), 'No thanks');
    });
  });

  group('controller', () {
    Future<(RecoveryOfferController, FunnelTracker, _Sink)> make([
      Map<String, Object> prefs = const {},
    ]) async {
      SharedPreferences.setMockInitialValues({'funnel.consent.v1': 'granted', ...prefs});
      final sink = _Sink();
      final tracker = FunnelTracker(
        onboardingVersion: 'v1',
        onboardingStepCount: 1,
        sink: sink,
        environment: _store,
      );
      await tracker.load();
      final c = RecoveryOfferController(tracker: tracker)..productIds.add('rescue');
      await c.load();
      return (c, tracker, sink);
    }

    test('shown once per install, remembered across launches', () async {
      final (c, _, sink) = await make();
      expect(c.alreadyShown, isFalse);
      await c.markShown(_play([_trial, _discount, _regular])!, trigger: 'system_back', placement: 'gate');
      expect(c.alreadyShown, isTrue);
      await Future<void>.delayed(Duration.zero);
      final shown = sink.events.singleWhere((e) => e.$1 == 'recovery_offer_shown').$2;
      expect(shown['offer_id'], 'recovery-7d-25');
      expect(shown['price'], 11.24);
      expect(shown['regular_price'], 14.99);
      expect(shown['currency'], 'GBP');
      expect(shown['trigger'], 'system_back');

      final prefs = await SharedPreferences.getInstance();
      final (again, _, _) = await make({
        'recovery_offer.shown_at.v1': prefs.getInt('recovery_offer.shown_at.v1')!,
      });
      expect(again.alreadyShown, isTrue);
    });

    test('a verified trial on the recovery product logs recovery_trial_started', () async {
      final (c, tracker, sink) = await make();
      await c.markShown(_play([_trial, _discount, _regular])!, trigger: 'close', placement: 'gate');
      VerifiedPurchase trial(String id, String product) => VerifiedPurchase(
        event: 'trial_start',
        isNew: true,
        transactionId: id,
        productId: product,
        offer: 'trial',
        paid: false,
        environment: 'sandbox',
      );
      tracker.recordVerified(trial('t1', 'annual'));
      tracker.recordVerified(trial('t2', 'rescue'));
      await Future<void>.delayed(Duration.zero);
      final started = sink.events.where((e) => e.$1 == 'recovery_trial_started').toList();
      expect(started, hasLength(1));
      expect(started.single.$2['offer_id'], 'recovery-7d-25');
      expect(started.single.$2['environment'], 'sandbox');
    });

    test('converted only once the trial is over and the store still has it', () async {
      final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
      final (c, _, sink) = await make({
        'recovery_offer.trial.v1':
            '{"at":${eightDaysAgo.millisecondsSinceEpoch},"days":7,"params":{"offer_id":"recovery-7d-25"}}',
      });
      c.observeActive('annual');
      c.observeActive('rescue');
      c.observeActive('rescue');
      await Future<void>.delayed(Duration.zero);
      expect(sink.events.where((e) => e.$1 == 'recovery_trial_converted'), hasLength(1));
    });

    test('not converted while the trial is still running', () async {
      final (c, _, sink) = await make({
        'recovery_offer.trial.v1':
            '{"at":${DateTime.now().millisecondsSinceEpoch},"days":7,"params":{}}',
      });
      c.observeActive('rescue');
      await Future<void>.delayed(Duration.zero);
      expect(sink.events.where((e) => e.$1 == 'recovery_trial_converted'), isEmpty);
    });
  });
}
