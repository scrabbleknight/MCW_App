// GENERATED from ViralEngine/funnel-kit/dart/recovery_offer.dart — edit it there and run `npm run funnel:sync`.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'funnel_tracker.dart';
import 'install_attribution.dart';

/// The paywall exit recovery offer (spec: ViralEngine/funnel-kit/README.md,
/// "Exit recovery offer"): shown once per install to someone who tries to
/// leave the paywall without buying.
///
/// It's sold on a twin of Monthly (same price, same iOS subscription group)
/// so the main paywall's Monthly never picks it up, including in builds
/// that predate it:
/// - Google Play: an offer of two phases, 7 days free then the first month
///   25% off, then the base plan.
/// - App Store: an introductory offer can only be one phase, so iOS gets
///   the 7-day free trial and then the normal price (the user's call,
///   2026-10-31).
///
/// Everything the screen says comes from what the store returned
/// ([RecoveryOfferTerms]); if the store's offer isn't the expected shape,
/// there's no offer rather than a screen that promises something else.
@immutable
class RecoveryOfferTerms {
  const RecoveryOfferTerms({
    required this.productId,
    required this.offerId,
    required this.trialDays,
    required this.regularPrice,
    required this.regularAmount,
    required this.currency,
    this.discountedPrice,
    this.discountedAmount,
  });

  final String productId;

  /// Play's offer id, or Apple's introductory offer (`intro`).
  final String offerId;
  final int trialDays;

  /// What every month costs after the offer, as the store formats it.
  final String regularPrice;
  final double regularAmount;

  /// ISO 4217, e.g. GBP.
  final String currency;

  /// The first paid month, when the offer discounts it (Play). Null when
  /// the first payment is the regular price (App Store).
  final String? discountedPrice;
  final double? discountedAmount;

  bool get hasDiscount => discountedPrice != null;

  /// Whole percent off the first month, e.g. 25. Null without a discount.
  int? get discountPercent {
    final d = discountedAmount;
    if (d == null || regularAmount <= 0) return null;
    return ((1 - d / regularAmount) * 100).round();
  }

  String get firstPaymentPrice => discountedPrice ?? regularPrice;
  double get firstPaymentAmount => discountedAmount ?? regularAmount;

  /// When the first payment is taken for a trial starting at [start].
  DateTime firstPaymentDate(DateTime start) =>
      DateTime(start.year, start.month, start.day + trialDays);

  /// When the regular price starts, after the discounted month.
  DateTime regularPriceDate(DateTime start) {
    final first = firstPaymentDate(start);
    return hasDiscount ? DateTime(first.year, first.month + 1, first.day) : first;
  }

  /// Parameters every recovery_* event carries.
  Map<String, Object> analyticsParams() => {
    'offer_id': offerId,
    'product_id': productId,
    'currency': currency,
    'price': _round2(firstPaymentAmount),
    'regular_price': _round2(regularAmount),
    'trial_days': trialDays,
    'discount_pct': discountPercent ?? 0,
    if (InstallAttribution.instance.postCode != null)
      'post_code': InstallAttribution.instance.postCode!,
  };

  static double _round2(double v) => (v * 100).round() / 100;

  /// Play: the offer's pricing phases, in order. Accepts exactly a free
  /// trial, then optionally one cheaper month, then the monthly base plan.
  static RecoveryOfferTerms? fromPlayPhases({
    required String productId,
    required String offerId,
    required List<RecoveryPricePhase> phases,
  }) {
    if (phases.length < 2 || phases.length > 3) return null;
    final trial = phases.first;
    final regular = phases.last;
    final trialDays = isoPeriodDays(trial.billingPeriod) * trial.cycles;
    if (trial.priceMicros != 0 || !trial.finite || trialDays <= 0) return null;
    if (regular.finite || regular.priceMicros <= 0) return null;
    if (isoPeriodMonths(regular.billingPeriod) != 1) return null;
    RecoveryPricePhase? discounted;
    if (phases.length == 3) {
      discounted = phases[1];
      if (!discounted.finite ||
          discounted.cycles != 1 ||
          isoPeriodMonths(discounted.billingPeriod) != 1 ||
          discounted.priceMicros <= 0 ||
          discounted.priceMicros >= regular.priceMicros ||
          discounted.currency != regular.currency) {
        return null;
      }
    }
    return RecoveryOfferTerms(
      productId: productId,
      offerId: offerId,
      trialDays: trialDays,
      regularPrice: regular.formattedPrice,
      regularAmount: regular.priceMicros / 1000000,
      currency: regular.currency,
      discountedPrice: discounted?.formattedPrice,
      discountedAmount: discounted == null
          ? null
          : discounted.priceMicros / 1000000,
    );
  }

  /// Play: finds [offerId] among the entries queryProductDetails returned
  /// for the recovery product (one per base plan and per offer). Play only
  /// returns offers this user is eligible for, so no entry means no offer.
  static RecoveryOfferTerms? fromGooglePlay(
    Iterable<ProductDetails> details,
    String offerId,
  ) {
    for (final p in details.whereType<GooglePlayProductDetails>()) {
      final offers = p.productDetails.subscriptionOfferDetails;
      final index = p.subscriptionIndex;
      if (offers == null || index == null) continue;
      final offer = offers[index];
      if (offer.offerId != offerId) continue;
      return fromPlayPhases(
        productId: p.id,
        offerId: offerId,
        phases: [
          for (final ph in offer.pricingPhases)
            RecoveryPricePhase(
              priceMicros: ph.priceAmountMicros,
              formattedPrice: ph.formattedPrice,
              currency: ph.priceCurrencyCode,
              billingPeriod: ph.billingPeriod,
              cycles: ph.billingCycleCount,
              finite: ph.recurrenceMode != RecurrenceMode.infiniteRecurring,
            ),
        ],
      );
    }
    return null;
  }

  /// App Store: the recovery product's introductory offer, which must be a
  /// free trial on a monthly subscription. [regularPrice] is StoreKit 2's
  /// display price; the intro terms come from StoreKit 1, the only API the
  /// plugin exposes them through.
  static RecoveryOfferTerms? fromAppStoreIntro({
    required String productId,
    required String regularPrice,
    required double regularAmount,
    required String currency,
    required bool freeTrial,
    required int trialUnits,
    required int trialUnitDays,
    required int trialPeriods,
    required int productPeriodMonths,
  }) {
    final days = trialUnits * trialUnitDays * trialPeriods;
    if (!freeTrial || days <= 0 || productPeriodMonths != 1) return null;
    if (regularAmount <= 0) return null;
    return RecoveryOfferTerms(
      productId: productId,
      offerId: 'intro',
      trialDays: days,
      regularPrice: regularPrice,
      regularAmount: regularAmount,
      currency: currency,
    );
  }

  /// App Store: asks StoreKit 1 for [product]'s introductory offer.
  static Future<RecoveryOfferTerms?> fromAppStore(ProductDetails product) async {
    final response = await SKRequestMaker().startProductRequest([product.id]);
    final sk1 = response.products.where((p) => p.productIdentifier == product.id);
    if (sk1.isEmpty) return null;
    final intro = sk1.first.introductoryPrice;
    final period = sk1.first.subscriptionPeriod;
    if (intro == null || period == null) return null;
    return fromAppStoreIntro(
      productId: product.id,
      regularPrice: product.price,
      regularAmount: product.rawPrice,
      currency: product.currencyCode,
      freeTrial: intro.paymentMode == SKProductDiscountPaymentMode.freeTrail,
      trialUnits: intro.subscriptionPeriod.numberOfUnits,
      trialUnitDays: _unitDays(intro.subscriptionPeriod.unit),
      trialPeriods: intro.numberOfPeriods,
      productPeriodMonths: period.unit == SKSubscriptionPeriodUnit.month
          ? period.numberOfUnits
          : 0,
    );
  }

  static int _unitDays(SKSubscriptionPeriodUnit unit) => switch (unit) {
    SKSubscriptionPeriodUnit.day => 1,
    SKSubscriptionPeriodUnit.week => 7,
    // A month or a year can't be a 7-day trial; 0 rejects it.
    _ => 0,
  };

  /// Debug builds run with `--dart-define=RECOVERY_OFFER_PREVIEW=true`:
  /// sample terms (UK prices) so the screen can be seen before the store has
  /// the offer. Still once per install (reinstall to see it again). Buying
  /// it fails (no such product). Always null in release builds.
  static const preview =
      kDebugMode && bool.fromEnvironment('RECOVERY_OFFER_PREVIEW');

  static RecoveryOfferTerms? debugPreview(bool isAndroid) {
    if (!preview) return null;
    return RecoveryOfferTerms(
      productId: 'preview',
      offerId: 'preview',
      trialDays: 7,
      regularPrice: '£14.99',
      regularAmount: 14.99,
      currency: 'GBP',
      discountedPrice: isAndroid ? '£11.24' : null,
      discountedAmount: isAndroid ? 11.24 : null,
    );
  }

  /// Days in an ISO 8601 period of days or weeks (P7D, P1W); 0 otherwise.
  static int isoPeriodDays(String period) {
    final m = RegExp(r'^P(\d+)([DW])$').firstMatch(period);
    if (m == null) return 0;
    final n = int.parse(m.group(1)!);
    return m.group(2) == 'W' ? n * 7 : n;
  }

  /// Months in an ISO 8601 period of months (P1M); 0 otherwise.
  static int isoPeriodMonths(String period) {
    final m = RegExp(r'^P(\d+)M$').firstMatch(period);
    return m == null ? 0 : int.parse(m.group(1)!);
  }
}

/// One Play pricing phase, as plain values (tests build these directly).
@immutable
class RecoveryPricePhase {
  const RecoveryPricePhase({
    required this.priceMicros,
    required this.formattedPrice,
    required this.currency,
    required this.billingPeriod,
    required this.cycles,
    required this.finite,
  });

  final int priceMicros;
  final String formattedPrice;
  final String currency;

  /// ISO 8601, e.g. P1W, P1M.
  final String billingPeriod;
  final int cycles;

  /// False for the base plan's never-ending phase.
  final bool finite;
}

/// The words on the recovery screen, from the store's terms. Apps with
/// their own translations can build their own from [RecoveryOfferTerms];
/// these are the English defaults every app shares, so the price and
/// renewal disclosure read the same everywhere.
class RecoveryOfferCopy {
  RecoveryOfferCopy(this.terms, {required this.isAndroid, DateTime? now})
    : now = now ?? DateTime.now();

  final RecoveryOfferTerms terms;
  final bool isAndroid;
  final DateTime now;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

  static String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  String get headline => 'Wait! Here\'s something extra for you 🎁';

  String get subhead => terms.hasDiscount
      ? 'Try everything FREE for ${terms.trialDays} days, plus get '
            '${terms.discountPercent}% off your first month.'
      : 'Try everything FREE for ${terms.trialDays} days.';

  String get primaryCta => 'Claim My Special Offer';

  /// [leaving]: declining closes the app (Android back or close). Otherwise
  /// the user goes back to the paywall.
  String declineCta({required bool leaving}) =>
      leaving ? 'No thanks, I\'ll leave' : 'No thanks';

  /// The three steps of the timeline: (when, what).
  List<(String, String)> get timeline {
    final first = terms.firstPaymentDate(now);
    return [
      ('Today', '${terms.trialDays} days free. Full access, no charge.'),
      if (terms.hasDiscount) ...[
        (
          date(first),
          'First payment: ${terms.discountedPrice} for your first month '
              '(${terms.discountPercent}% off ${terms.regularPrice}).',
        ),
        (
          date(terms.regularPriceDate(now)),
          'Then ${terms.regularPrice}/month.',
        ),
      ] else
        (date(first), 'First payment: ${terms.regularPrice}/month.'),
    ];
  }

  String get priceLine => terms.hasDiscount
      ? '${terms.trialDays} days free, then ${terms.discountedPrice} for the '
            'first month, then ${terms.regularPrice}/month'
      : '${terms.trialDays} days free, then ${terms.regularPrice}/month';

  /// Auto-renewal and cancellation terms, shown under the button.
  String get disclosure {
    final first = date(terms.firstPaymentDate(now));
    final store = isAndroid
        ? 'Google Play (Payments & subscriptions)'
        : 'your Apple ID settings (Subscriptions)';
    final charges = terms.hasDiscount
        ? 'Your first payment of ${terms.discountedPrice} is taken on $first, '
              'unless you cancel before then. After the first month you\'ll '
              'pay ${terms.regularPrice} a month.'
        : 'Your first payment of ${terms.regularPrice} is taken on $first, '
              'unless you cancel before then.';
    return '$charges The subscription renews automatically every month at '
        '${terms.regularPrice} until you cancel. Cancel any time in $store, '
        'at least 24 hours before the trial ends or the next renewal, and '
        'you won\'t be charged again. One offer per person; existing '
        'subscribers keep their current plan.';
  }
}

/// Shows the recovery offer at most once per install and connects its
/// analytics. One per app, created beside the PurchaseController.
class RecoveryOfferController {
  RecoveryOfferController({required FunnelTracker tracker}) : _tracker = tracker {
    tracker.onAcquisition = _onAcquisition;
  }

  final FunnelTracker _tracker;

  static const _kShown = 'recovery_offer.shown_at.v1';
  static const _kTrial = 'recovery_offer.trial.v1';

  SharedPreferences? _prefs;
  bool _shown = false;
  bool _loaded = false;

  /// Recovery product ids (iOS twin and Play product), so its verified
  /// trials can be told apart. Set by the PurchaseController.
  final Set<String> productIds = {};

  /// The terms of the offer the user saw, for the trial events.
  RecoveryOfferTerms? _lastShown;

  /// Whether the offer was already shown on this install. Treated as shown
  /// until [load] has read it, so nobody sees it twice.
  bool get alreadyShown => !_loaded || _shown;

  Future<void> load() async {
    try {
      final prefs = _prefs = await SharedPreferences.getInstance();
      _shown = prefs.getInt(_kShown) != null;
    } catch (e) {
      debugPrint('[recovery] load failed: $e');
      _shown = true;
    }
    _loaded = true;
  }

  /// Records that [terms] are about to be shown, before the screen opens,
  /// so even a crash doesn't bring it back.
  Future<void> markShown(
    RecoveryOfferTerms terms, {
    required String trigger,
    required String placement,
  }) async {
    _shown = true;
    _lastShown = terms;
    _tracker.recoveryOfferShown(
      terms.analyticsParams(),
      trigger: trigger,
      placement: placement,
    );
    try {
      await _prefs?.setInt(_kShown, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[recovery] saving shown failed: $e');
    }
  }

  void _onAcquisition(VerifiedPurchase v) {
    if (v.event != FunnelEvents.trialStart || !productIds.contains(v.productId)) {
      return;
    }
    final terms = _lastShown;
    final params = terms?.analyticsParams() ?? {'product_id': v.productId};
    _tracker.recoveryTrialStarted(params, environment: v.environment);
    unawaited(_saveTrial(params, terms?.trialDays ?? 7));
  }

  Future<void> _saveTrial(Map<String, Object> params, int trialDays) async {
    try {
      await _prefs?.setString(
        _kTrial,
        jsonEncode({
          'at': DateTime.now().millisecondsSinceEpoch,
          'days': trialDays,
          'params': params,
        }),
      );
    } catch (e) {
      debugPrint('[recovery] saving trial failed: $e');
    }
  }

  /// Hand every purchased/restored recovery-product update here. Once the
  /// trial is over and the store still reports the subscription, logs
  /// recovery_trial_converted (once).
  void observeActive(String productId) {
    if (!productIds.contains(productId)) return;
    final raw = _prefs?.getString(_kTrial);
    if (raw == null) return;
    try {
      final saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final started = DateTime.fromMillisecondsSinceEpoch(saved['at'] as int);
      final days = saved['days'] as int;
      // A day's slack: the store renews around the trial's end, not on it.
      if (DateTime.now().difference(started) < Duration(days: days + 1)) return;
      _tracker.recoveryTrialConverted(
        Map<String, Object>.from(saved['params'] as Map),
      );
    } catch (e) {
      debugPrint('[recovery] reading trial failed: $e');
    }
  }
}
