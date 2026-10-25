import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:military_calisthenics_women/core/dev/dev_access.dart';
import 'package:military_calisthenics_women/core/dev/review_access.dart';
import 'package:military_calisthenics_women/core/funnel/funnel_tracker.dart';
import 'package:military_calisthenics_women/core/funnel/install_attribution.dart';
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

  /// iOS twin of Annual whose introductory offer is the referral friend
  /// discount (50% off the first year). Apple only gives intro offers to new
  /// subscribers, which is who the friend discount is for.
  static const _yearlyFriendId =
      'com.swiftbee.militarycalisthenicswomen.annual.friend';

  /// Play: the friend discount is a developer-determined offer on the annual
  /// base plan. Play never picks it by itself.
  static const _playFriendOfferId = 'referral-friend';

  static Set<String> get _productIds => {
    _weeklyId,
    _yearlyId,
    if (!StorePlatform.isAndroid) _yearlyFriendId,
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  final Map<String, ProductDetails> _products = {};

  /// Play only: the offer to buy for each product. A free-trial offer when
  /// Play says the user is eligible for one, otherwise the base plan.
  final Map<String, String> _playOfferTokens = {};

  /// Products whose free trial this user can still get. Play only returns
  /// trial offers to eligible users; on iOS StoreKit 2 is asked directly.
  final Set<String> _trialEligible = {};

  /// Play only: the friend discount offer for each product, and what its
  /// first phase costs as Play formats it.
  final Map<String, String> _playFriendOfferTokens = {};
  final Map<String, String> _playFriendPrices = {};

  /// The subscription the store last reported as bought or still active.
  PurchaseDetails? _activeSubscription;

  /// Called with every purchase the store reports as bought or restored,
  /// after access has been granted. The referral programme listens here.
  void Function(PurchaseDetails purchase)? onPurchase;

  /// Logs purchase attempts and the ones that don't go through.
  FunnelTracker? funnel;

  /// The product of the purchase sheet currently open, for purchase_failed.
  String? _buyingProductId;
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

  /// What [plan] renews at, as the store formats it for this user: their
  /// currency, with tax included wherever the store shows it that way. Null
  /// until the store has returned the product.
  PlanPrice? priceFor(PaywallPlan plan) {
    final product = _products[_idFor(plan)];
    if (product == null) return null;
    if (product is GooglePlayProductDetails) {
      // Play reports an offer's first pricing phase as its price, which is
      // "Free" for a trial. The last phase is the recurring price.
      final offers = product.productDetails.subscriptionOfferDetails;
      final index = product.subscriptionIndex;
      if (offers != null && index != null) {
        final phase = offers[index].pricingPhases.last;
        return (
          formatted: phase.formattedPrice,
          amount: phase.priceAmountMicros / 1000000,
        );
      }
    }
    return (formatted: product.price, amount: product.rawPrice);
  }

  /// Whether the store has the referral friend discount for [plan]. Only
  /// Annual has one (50% off the first year).
  /// On iOS the discount is an introductory offer, which Apple gives once
  /// per subscription group: someone who has had a trial or subscription
  /// before would pay full price, so they aren't offered it.
  bool hasFriendOffer(PaywallPlan plan) {
    if (plan != PaywallPlan.yearly) return false;
    return StorePlatform.isAndroid
        ? _playFriendOfferTokens.containsKey(_yearlyId)
        : _products.containsKey(_yearlyFriendId) &&
              _trialEligible.contains(_yearlyFriendId);
  }

  /// iOS: the store has the friend discount, but Apple won't give it to
  /// this user because they've had a trial or subscription before.
  bool get friendOfferIneligible =>
      !StorePlatform.isAndroid &&
      _products.containsKey(_yearlyFriendId) &&
      !_trialEligible.contains(_yearlyFriendId);

  /// What the friend discount's first phase costs, where the store says
  /// (Play). Null on iOS: StoreKit shows it on the purchase sheet.
  String? friendOfferPrice(PaywallPlan plan) => _playFriendPrices[_idFor(plan)];

  /// The plan of the subscription the store last reported, if any.
  PaywallPlan? get currentPlan => switch (_activeSubscription?.productID) {
    null => null,
    final id when id == _weeklyId => PaywallPlan.weekly,
    _ => PaywallPlan.yearly,
  };

  /// What the server needs to look the current subscription up: the Play
  /// purchase token, or Apple's signed transaction.
  String? get currentVerificationData =>
      _activeSubscription?.verificationData.serverVerificationData;

  /// Whether buying [plan] starts with a free trial for this user. Before the
  /// store has returned the product, assume the trial the stores are set up
  /// with: the yearly plan has one, the weekly plan doesn't.
  bool hasFreeTrial(PaywallPlan plan) {
    final id = _idFor(plan);
    if (!_products.containsKey(id)) return plan == PaywallPlan.yearly;
    return _trialEligible.contains(id);
  }

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
        if (!StorePlatform.isAndroid) await _checkAppStoreTrial();
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
  /// already in-flight). With [friendDiscount], buys it with the referral
  /// friend discount instead of the usual trial; the server must have
  /// accepted a friend's code first (ReferralController.applyCode).
  Future<PurchaseOutcome> purchase(
    PaywallPlan plan, {
    bool friendDiscount = false,
    String? placement,
  }) async {
    final attemptId = friendDiscount && !StorePlatform.isAndroid
        ? _yearlyFriendId
        : _idFor(plan);
    funnel?.purchaseAttempt(productId: attemptId, placement: placement);
    if (!_storeAvailable) {
      _logFailure(attemptId, PurchaseFailure.storeUnavailable);
      return PurchaseOutcome.storeUnavailable;
    }
    if (_pending != null) return PurchaseOutcome.pending;

    // Before we launch the platform buy sheet, silently check whether this
    // store account already has an active subscription. If it does we treat
    // the tap as an instant success — no double-billing, no "you are already
    // subscribed" system alert.
    if (await checkExistingSubscription()) {
      _logFailure(attemptId, PurchaseFailure.alreadyOwned);
      return PurchaseOutcome.success;
    }

    if (friendDiscount && !hasFriendOffer(plan)) {
      _logFailure(attemptId, PurchaseFailure.productUnavailable);
      return PurchaseOutcome.productNotFound;
    }
    final id = friendDiscount && !StorePlatform.isAndroid
        ? _yearlyFriendId
        : _idFor(plan);
    final product = _products[id];
    if (product == null) {
      _logFailure(id, PurchaseFailure.productUnavailable);
      return PurchaseOutcome.productNotFound;
    }
    final offerToken = friendDiscount
        ? _playFriendOfferTokens[id]
        : _playOfferTokens[id];
    if (StorePlatform.isAndroid && friendDiscount && offerToken == null) {
      _logFailure(id, PurchaseFailure.productUnavailable);
      return PurchaseOutcome.productNotFound;
    }

    return _buy(
      product is GooglePlayProductDetails
          ? GooglePlayPurchaseParam(
              productDetails: product,
              offerToken: offerToken,
              // "ve_<post code>" when the install came from a social post's
              // link, so Play ties the subscription to that post. Play needs
              // an account id with it: a random per-install one.
              obfuscatedProfileId:
                  InstallAttribution.instance.obfuscatedProfileId,
              applicationUserName:
                  InstallAttribution.instance.obfuscatedAccountId,
            )
          : PurchaseParam(productDetails: product),
    );
  }

  void _logFailure(String? productId, String category) {
    funnel?.purchaseFailed(
      // Play's errors don't name the product.
      productId: productId == null || productId.isEmpty
          ? _buyingProductId ?? ''
          : productId,
      category: category,
    );
  }

  /// iOS: buys the plan an Apple promotional offer the server signed for a
  /// referral reward is for. That's usually the user's own plan, but the
  /// half-price year is always Annual, so a Weekly subscriber upgrades. The
  /// user is usually subscribed already, so this skips the
  /// existing-subscription check.
  Future<PurchaseOutcome> purchaseWithPromotionalOffer(
    SignedPromotionalOffer offer,
  ) async {
    if (!_storeAvailable) return PurchaseOutcome.storeUnavailable;
    if (_pending != null) return PurchaseOutcome.pending;
    final product = _products[offer.productId];
    if (product == null) return PurchaseOutcome.productNotFound;
    return _buy(
      Sk2PurchaseParam(
        productDetails: product,
        promotionalOffer: SK2PromotionalOffer(
          offerId: offer.offerId,
          signature: SK2SubscriptionOfferSignature(
            keyID: offer.keyId,
            nonce: offer.nonce,
            timestamp: offer.timestamp,
            signature: offer.signature,
          ),
        ),
      ),
    );
  }

  Future<PurchaseOutcome> _buy(PurchaseParam param) async {
    _pending = Completer<PurchaseOutcome>();
    _buyingProductId = param.productDetails.id;
    notifyListeners();

    try {
      if (kDebugMode && param is GooglePlayPurchaseParam) {
        debugPrint(
          '[funnel] Play purchase profile id: ${param.obfuscatedProfileId}, '
          'account id: ${param.applicationUserName}',
        );
      }
      final started = await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) {
        _logFailure(null, PurchaseFailure.unknown);
        _resolvePending(PurchaseOutcome.failed);
      }
    } catch (error, stack) {
      debugPrint('PurchaseController: buy failed — $error');
      debugPrintStack(stackTrace: stack);
      _logFailure(null, PurchaseFailure.categorise(error.toString()));
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
          if (_isSubscription(purchase.productID)) {
            _activeSubscription = purchase;
          }
          _markEntitled();
          _resolvePending(PurchaseOutcome.success);
          onPurchase?.call(purchase);
          break;
        case PurchaseStatus.error:
          debugPrint(
            'PurchaseController: transaction error — ${purchase.error}',
          );
          if (_pending != null) {
            _logFailure(
              purchase.productID,
              PurchaseFailure.categorise(
                purchase.error?.code,
                purchase.error?.message,
              ),
            );
          }
          _resolvePending(PurchaseOutcome.failed);
          break;
        case PurchaseStatus.canceled:
          if (_pending != null) {
            _logFailure(purchase.productID, PurchaseFailure.cancelled);
          }
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
    if (offer.offerId == _playFriendOfferId) {
      _products.putIfAbsent(details.id, () => details);
      _playFriendOfferTokens[details.id] = offer.offerIdToken;
      _playFriendPrices[details.id] = offer.pricingPhases.first.formattedPrice;
      return;
    }
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
      _trialEligible.add(details.id);
    }
  }

  /// Apple shows the introductory offer only to users who haven't had one in
  /// the subscription group. If the check fails, assume they can, which is
  /// how the paywall behaved before this check existed.
  Future<void> _checkAppStoreTrial() async {
    if (_products.containsKey(_yearlyId)) {
      try {
        if (await SK2Product.isIntroductoryOfferEligible(_yearlyId)) {
          _trialEligible.add(_yearlyId);
        }
      } catch (error) {
        debugPrint(
          'PurchaseController: trial eligibility check failed — $error',
        );
        _trialEligible.add(_yearlyId);
      }
    }
    // The friend discount is the friend twin's introductory offer. Unlike
    // the trial, don't assume eligibility when the check fails: offering
    // 50% off and charging full price would be worse than not offering it.
    if (_products.containsKey(_yearlyFriendId)) {
      try {
        if (await SK2Product.isIntroductoryOfferEligible(_yearlyFriendId)) {
          _trialEligible.add(_yearlyFriendId);
        }
      } catch (error) {
        debugPrint('PurchaseController: friend offer check failed — $error');
      }
    }
  }

  String _idFor(PaywallPlan plan) => switch (plan) {
    PaywallPlan.weekly => _weeklyId,
    PaywallPlan.yearly => _yearlyId,
  };

  bool _isSubscription(String productId) =>
      productId == _weeklyId ||
      productId == _yearlyId ||
      productId == _yearlyFriendId;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// An Apple promotional offer the server signed (claimReferralReward).
typedef SignedPromotionalOffer = ({
  String productId,
  String offerId,
  String keyId,
  String nonce,
  int timestamp,
  String signature,
});

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
