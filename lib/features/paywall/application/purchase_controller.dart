import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:military_calisthenics_women/core/dev/dev_access.dart';
import 'package:military_calisthenics_women/core/dev/review_access.dart';
import 'package:military_calisthenics_women/core/platform/store_platform.dart';
import 'package:military_calisthenics_women/features/paywall/presentation/paywall_step.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin controller around [InAppPurchase]. Boots on app start, queries the
/// two subscription products from the store, listens to the purchase
/// stream, and exposes a Future-per-purchase surface the paywall can await.
/// [checkAccess] keeps an onboarded user in the app only while the store
/// says the subscription is live.
///
/// Not opinionated about receipt validation yet — we call
/// [InAppPurchase.completePurchase] on every incoming transaction so the
/// system stops re-emitting it, but no server-side check runs.
class PurchaseController extends ChangeNotifier {
  // Google Play caps product IDs at 40 characters and bans capitals, so the
  // App Store IDs can't be reused there.
  static String get _weeklyId => StorePlatform.isAndroid
      ? 'com.swiftbee.militarycalisthenics.weekly'
      : 'com.swiftbee.militarycalisthenicswomen.weekly';
  static String get _yearlyId => StorePlatform.isAndroid
      ? 'com.swiftbee.militarycalisthenics.annual'
      : 'com.swiftbee.militarycalisthenicswomen.annual';
  static Set<String> get _productIds => {_weeklyId, _yearlyId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  final Map<String, ProductDetails> _products = {};

  /// Play only: the offer to buy for each product. A free-trial offer when
  /// Play says the user is eligible for one, otherwise the base plan.
  final Map<String, String> _playOfferTokens = {};
  bool _storeAvailable = false;
  bool _loaded = false;
  final Completer<void> _ready = Completer<void>();

  Completer<PurchaseOutcome>? _pending;
  bool _restoreInFlight = false;

  /// True once any transaction (fresh purchase or restore) has come back
  /// as `purchased` / `restored` this session. Used to short-circuit the
  /// platform buy sheet when the user already owns a subscription — the
  /// OS would otherwise show its "You are currently subscribed to this"
  /// alert on every plan tap.
  bool _hasActiveEntitlement = false;
  bool get hasActiveEntitlement => _hasActiveEntitlement;

  /// A one-shot check-existing-subscription pass. First call asks the store;
  /// subsequent calls read the cached result so we don't spam the store on
  /// every plan tap.
  bool _didProbeForEntitlement = false;
  Completer<void>? _entitlementFlipCompleter;

  /// When the store last confirmed an active subscription (epoch ms).
  static const _kVerifiedAt = 'purchase.verified_at_ms';

  /// How long an offline user keeps access after the store last confirmed
  /// their subscription. Long enough for travel; short enough that a
  /// cancelled subscription can't be kept alive by staying offline.
  static const offlineGrace = Duration(days: 14);

  AppAccess _access = AppAccess.checking;
  bool _accessCheckInFlight = false;
  DateTime? _accessCheckedAt;

  bool get isLoaded => _loaded;

  /// Completes once [load] has finished talking to the store, successfully or
  /// not. Await it before asking whether the user is subscribed.
  Future<void> get ready => _ready.future;
  bool get isStoreAvailable => _storeAvailable;
  bool get isBusy => _pending != null || _restoreInFlight;

  /// Whether a user who has finished onboarding may use the app. The store
  /// review account and developer builds always may.
  AppAccess get access => ReviewAccess.isReviewAccount || DevAccess.isDeveloper
      ? AppAccess.allowed
      : _access;

  /// Asks the store whether the subscription is still active and updates
  /// [access]. Opens straight away for anyone confirmed within
  /// [offlineGrace] while the store answers. Skips the check if one finished
  /// less than [ifOlderThan] ago.
  Future<void> checkAccess({Duration ifOlderThan = Duration.zero}) async {
    final checkedAt = _accessCheckedAt;
    if (_accessCheckInFlight) return;
    if (checkedAt != null &&
        DateTime.now().difference(checkedAt) < ifOlderThan) {
      return;
    }
    _accessCheckInFlight = true;
    try {
      await ready;
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      var verifiedMs = prefs.getInt(_kVerifiedAt);
      if (verifiedMs == null) {
        // Users who onboarded before this check existed have no record yet.
        // Start their grace window now rather than locking them out offline.
        verifiedMs = now.millisecondsSinceEpoch;
        await prefs.setInt(_kVerifiedAt, verifiedMs);
      }
      final withinGrace =
          now.difference(DateTime.fromMillisecondsSinceEpoch(verifiedMs)) <
          offlineGrace;
      if (_access == AppAccess.checking && withinGrace) {
        _access = AppAccess.allowed;
        notifyListeners();
      }

      final active = await _queryStore();
      if (active == true) {
        _markEntitled();
      } else if (active == false) {
        _hasActiveEntitlement = false;
        _access = AppAccess.notSubscribed;
      } else {
        _access = withinGrace ? AppAccess.allowed : AppAccess.needsConnection;
      }
      _accessCheckedAt = DateTime.now();
    } finally {
      _accessCheckInFlight = false;
      notifyListeners();
    }
  }

  ProductDetails? productFor(PaywallPlan plan) => _products[_idFor(plan)];

  Future<void> load() async {
    try {
      _storeAvailable = await _iap.isAvailable();
      if (_storeAvailable) {
        _sub = _iap.purchaseStream.listen(
          _onPurchaseUpdate,
          onError: (error) =>
              debugPrint('PurchaseController: stream error — $error'),
        );
        final response = await _iap.queryProductDetails(_productIds);
        for (final p in response.productDetails) {
          if (p is GooglePlayProductDetails) {
            _addPlayOffer(p);
          } else {
            _products[p.id] = p;
          }
        }
        if (response.notFoundIDs.isNotEmpty) {
          debugPrint(
            'PurchaseController: products not found — ${response.notFoundIDs}',
          );
        }
      }
    } catch (error, stack) {
      debugPrint('PurchaseController: load failed — $error');
      debugPrintStack(stackTrace: stack);
    } finally {
      _loaded = true;
      if (!_ready.isCompleted) _ready.complete();
      notifyListeners();
    }
  }

  /// Starts the platform purchase sheet for [plan]. Completes with the
  /// terminal outcome (or [PurchaseOutcome.pending] if another purchase is
  /// already in-flight).
  Future<PurchaseOutcome> purchase(PaywallPlan plan) async {
    if (!_storeAvailable) return PurchaseOutcome.storeUnavailable;
    if (_pending != null) return PurchaseOutcome.pending;

    // Before we launch the platform buy sheet, silently check whether this
    // store account already has an active subscription. If it does we treat
    // the tap as an instant success — no double-billing, no "you are already
    // subscribed" system alert.
    if (await checkExistingSubscription()) {
      return PurchaseOutcome.success;
    }

    final product = _products[_idFor(plan)];
    if (product == null) return PurchaseOutcome.productNotFound;

    _pending = Completer<PurchaseOutcome>();
    notifyListeners();

    try {
      final param = product is GooglePlayProductDetails
          ? GooglePlayPurchaseParam(
              productDetails: product,
              offerToken: _playOfferTokens[product.id],
            )
          : PurchaseParam(productDetails: product);
      final started = await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) {
        _resolvePending(PurchaseOutcome.failed);
      }
    } catch (error, stack) {
      debugPrint('PurchaseController: buy failed — $error');
      debugPrintStack(stackTrace: stack);
      _resolvePending(PurchaseOutcome.failed);
    }
    return _pending?.future ?? Future.value(PurchaseOutcome.failed);
  }

  /// Asks the store for an active subscription. Returns `true` when it
  /// reported one (restored or previously purchased), `false` otherwise.
  Future<bool> restore() async => await _queryStore() ?? _hasActiveEntitlement;

  /// Asks the store for active subscriptions. Both stores only report live
  /// ones here — StoreKit 2 reads `Transaction.currentEntitlements`, Play
  /// returns current purchases — so a cancelled subscription drops out once
  /// it expires. Null when the store couldn't be asked (offline, no store).
  Future<bool?> _queryStore() async {
    if (!_storeAvailable || _restoreInFlight) return null;
    _restoreInFlight = true;
    // Reuse the entitlement-flip completer so the wait below trips as soon
    // as _onPurchaseUpdate marks the account entitled.
    _entitlementFlipCompleter ??= Completer<void>();
    notifyListeners();
    try {
      await _iap.restorePurchases();
      // Give the store a short window to deliver restored transactions on
      // the purchase stream before we report back.
      await Future.any([
        _entitlementFlipCompleter!.future,
        Future<void>.delayed(const Duration(seconds: 3)),
      ]);
      return _hasActiveEntitlement;
    } catch (error) {
      debugPrint('PurchaseController: restore failed — $error');
      return null;
    } finally {
      _restoreInFlight = false;
      _didProbeForEntitlement = true;
      notifyListeners();
    }
  }

  /// Silent variant of [restore] used to short-circuit the buy sheet when
  /// the user already owns a subscription. Returns the cached result after
  /// the first probe so we don't repeatedly hit the store on every
  /// plan-card tap.
  Future<bool> checkExistingSubscription() async {
    if (!_storeAvailable) return false;
    if (_hasActiveEntitlement) return true;
    if (_didProbeForEntitlement) return false;
    return restore();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Nothing to do — user is still on the platform sheet.
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _markEntitled();
          _resolvePending(PurchaseOutcome.success);
          break;
        case PurchaseStatus.error:
          debugPrint(
            'PurchaseController: transaction error — ${purchase.error}',
          );
          _resolvePending(PurchaseOutcome.failed);
          break;
        case PurchaseStatus.canceled:
          _resolvePending(PurchaseOutcome.cancelled);
          break;
      }
      if (purchase.pendingCompletePurchase) {
        // Fire-and-forget; the transaction has to be completed even if
        // the paywall isn't awaiting it (e.g. restored on cold start).
        unawaited(_iap.completePurchase(purchase));
      }
    }
  }

  void _markEntitled() {
    _hasActiveEntitlement = true;
    _access = AppAccess.allowed;
    unawaited(_recordVerified());
    final completer = _entitlementFlipCompleter;
    _entitlementFlipCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _recordVerified() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kVerifiedAt, DateTime.now().millisecondsSinceEpoch);
    } catch (error) {
      debugPrint('PurchaseController: saving verification failed — $error');
    }
  }

  void _resolvePending(PurchaseOutcome outcome) {
    final completer = _pending;
    _pending = null;
    notifyListeners();
    if (completer != null && !completer.isCompleted) {
      completer.complete(outcome);
    }
  }

  /// Play returns one entry per base plan and per offer. Keep the base plan
  /// as the product, but buy a free-trial offer whenever Play offers one
  /// (it only returns offers the user is eligible for).
  void _addPlayOffer(GooglePlayProductDetails details) {
    final offers = details.productDetails.subscriptionOfferDetails;
    final index = details.subscriptionIndex;
    if (offers == null || index == null) {
      _products[details.id] = details;
      return;
    }
    final offer = offers[index];
    final isBasePlan = offer.offerId == null;
    final hasFreeTrial = offer.pricingPhases.any(
      (phase) => phase.priceAmountMicros == 0,
    );
    if (isBasePlan) {
      _products[details.id] = details;
      _playOfferTokens.putIfAbsent(details.id, () => offer.offerIdToken);
    } else {
      _products.putIfAbsent(details.id, () => details);
    }
    if (hasFreeTrial) {
      _playOfferTokens[details.id] = offer.offerIdToken;
    }
  }

  String _idFor(PaywallPlan plan) => switch (plan) {
        PaywallPlan.weekly => _weeklyId,
        PaywallPlan.yearly => _yearlyId,
      };

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Whether an onboarded user can use the app right now.
enum AppAccess {
  /// The store hasn't answered yet and there's no recent confirmation.
  checking,

  /// Subscribed (or confirmed recently enough to ride out being offline).
  allowed,

  /// The store says there's no active subscription.
  notSubscribed,

  /// Offline for longer than [PurchaseController.offlineGrace].
  needsConnection,
}

/// Terminal state of a purchase attempt.
enum PurchaseOutcome {
  success,
  cancelled,
  failed,
  storeUnavailable,
  productNotFound,
  pending,
}
