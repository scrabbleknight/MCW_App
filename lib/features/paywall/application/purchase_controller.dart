import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:military_calisthenics_women/features/paywall/presentation/paywall_step.dart';

/// Thin controller around [InAppPurchase]. Boots on app start, queries the
/// two subscription products from the store, listens to the purchase
/// stream, and exposes a Future-per-purchase surface the paywall can await.
///
/// Not opinionated about receipt validation yet — we call
/// [InAppPurchase.completePurchase] on every incoming transaction so the
/// system stops re-emitting it, but no server-side check runs. Slot that in
/// before shipping to production; sandbox testing works without it.
class PurchaseController extends ChangeNotifier {
  static const _weeklyId = 'com.swiftbee.militarycalisthenicswomen.weekly';
  static const _yearlyId = 'com.swiftbee.militarycalisthenicswomen.annual';
  static const _productIds = {_weeklyId, _yearlyId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  final Map<String, ProductDetails> _products = {};
  bool _storeAvailable = false;
  bool _loaded = false;

  Completer<PurchaseOutcome>? _pending;
  bool _restoreInFlight = false;

  /// True once any transaction (fresh purchase or restore) has come back
  /// as `purchased` / `restored` this session. Used to short-circuit the
  /// platform buy sheet when the user already owns a subscription — the
  /// OS would otherwise show its "You are currently subscribed to this"
  /// alert on every plan tap.
  bool _hasActiveEntitlement = false;
  bool get hasActiveEntitlement => _hasActiveEntitlement;

  /// A one-shot check-existing-subscription pass. First call kicks the
  /// StoreKit restore flow; subsequent calls read the cached result so we
  /// don't spam the Apple-ID password prompt on every plan tap.
  bool _didProbeForEntitlement = false;
  Completer<void>? _entitlementFlipCompleter;

  bool get isLoaded => _loaded;
  bool get isStoreAvailable => _storeAvailable;
  bool get isBusy => _pending != null || _restoreInFlight;

  ProductDetails? productFor(PaywallPlan plan) =>
      _products[_idFor(plan)];

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
          _products[p.id] = p;
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
    // Apple ID already has an active subscription. If it does we treat the
    // tap as an instant success — no double-billing, no "you are already
    // subscribed" system alert.
    if (await checkExistingSubscription()) {
      return PurchaseOutcome.success;
    }

    final product = _products[_idFor(plan)];
    if (product == null) return PurchaseOutcome.productNotFound;

    _pending = Completer<PurchaseOutcome>();
    notifyListeners();

    try {
      final param = PurchaseParam(productDetails: product);
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

  /// Kicks off the App Store restore flow. Any restored purchases arrive
  /// via [_onPurchaseUpdate]; the caller waits on that. Returns `true` when
  /// StoreKit surfaced an active entitlement (restored or previously
  /// purchased), `false` otherwise.
  Future<bool> restore() async {
    if (!_storeAvailable || _restoreInFlight) return _hasActiveEntitlement;
    _restoreInFlight = true;
    // Reuse the entitlement-flip completer so the wait below trips as soon
    // as _onPurchaseUpdate marks the account entitled.
    _entitlementFlipCompleter ??= Completer<void>();
    notifyListeners();
    try {
      await _iap.restorePurchases();
      // Give StoreKit a short window to deliver restored transactions on
      // the purchase stream before we report back.
      await Future.any([
        _entitlementFlipCompleter!.future,
        Future<void>.delayed(const Duration(seconds: 3)),
      ]);
      return _hasActiveEntitlement;
    } catch (error) {
      debugPrint('PurchaseController: restore failed — $error');
      return _hasActiveEntitlement;
    } finally {
      _restoreInFlight = false;
      _didProbeForEntitlement = true;
      notifyListeners();
    }
  }

  /// Silent variant of [restore] used to short-circuit the buy sheet when
  /// the user already owns a subscription. Returns the cached result after
  /// the first probe so we don't repeatedly hit the App Store on every
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
    final completer = _entitlementFlipCompleter;
    _entitlementFlipCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
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

/// Terminal state of a purchase attempt.
enum PurchaseOutcome {
  success,
  cancelled,
  failed,
  storeUnavailable,
  productNotFound,
  pending,
}
