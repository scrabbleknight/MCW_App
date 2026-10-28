// GENERATED from ViralEngine/funnel-kit/dart/funnel_tracker.dart — edit it there and run `npm run funnel:sync`.
import 'dart:async';
import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The commercial funnel, with the same event names and parameters in every
/// SwiftBee app (spec: ViralEngine/funnel-kit/README.md).
///
/// Consent first: nothing reaches Google Analytics until the user says yes
/// ([setConsent]). Events from before the answer wait in memory only (never
/// on disk, never sent): a yes sends them, a no discards them. Collection is
/// also off natively until then (FIREBASE_ANALYTICS_COLLECTION_ENABLED /
/// firebase_analytics_collection_enabled = false).
///
/// Only screen ids, counts and product ids are sent — never onboarding
/// answers, health details or anything typed by the user.
abstract final class FunnelEvents {
  /// Logged by Firebase itself on the first launch with collection on.
  static const firstOpen = 'first_open';
  static const onboardingStarted = 'onboarding_started';
  static const onboardingStepView = 'onboarding_step_view';
  static const onboardingComplete = 'onboarding_complete';
  static const paywallView = 'paywall_view';
  static const paywallDismiss = 'paywall_dismiss';
  static const purchaseAttempt = 'purchase_attempt';
  static const purchaseFailed = 'purchase_failed';
  static const trialStart = 'trial_start';
  static const purchaseVerified = 'purchase_verified';

  /// Google Analytics' standard revenue event, the only one Firebase's
  /// Revenue cards add up. Logged beside purchase_verified for real money.
  static const purchase = 'purchase';
  static const trialConvertedToPaid = 'trial_converted_to_paid';
  static const subscriptionRenewed = 'subscription_renewed';
  static const subscriptionCancelled = 'subscription_cancelled';
  static const subscriptionExpired = 'subscription_expired';
  static const firstCoreAction = 'first_core_action';
  static const acquisitionSurvey = 'acquisition_survey';
}

/// Where a paywall was shown.
abstract final class PaywallPlacement {
  /// Straight after onboarding, in the same visit.
  static const onboarding = 'onboarding';

  /// A later launch landing on the paywall (never subscribed, or lapsed).
  static const gate = 'gate';

  static const settings = 'settings';
  static const feature = 'feature';
}

/// How a paywall was left without buying.
abstract final class PaywallDismissMethod {
  static const close = 'close';
  static const back = 'back';
  static const systemBack = 'system_back';
  static const sheetDismiss = 'sheet_dismiss';
}

/// Why a purchase didn't go through. Never the store's own message.
abstract final class PurchaseFailure {
  static const cancelled = 'cancelled';
  static const pending = 'pending';
  static const network = 'network';
  static const storeUnavailable = 'store_unavailable';
  static const notAllowed = 'not_allowed';
  static const productUnavailable = 'product_unavailable';
  static const alreadyOwned = 'already_owned';
  static const verification = 'verification';
  static const unknown = 'unknown';

  /// Maps a store error code (in_app_purchase's IAPError.code / message)
  /// to a category.
  static String categorise(String? code, [String? message]) {
    // Letters only, so purchase_cancelled, BillingResponse.userCanceled and
    // SKErrorPaymentCancelled all read alike.
    final s = '${code ?? ''} ${message ?? ''}'.toLowerCase().replaceAll(
      RegExp('[^a-z]'),
      '',
    );
    bool any(List<String> words) => words.any(s.contains);
    if (any(['cancel'])) return cancelled;
    if (any(['pending', 'deferred'])) return pending;
    if (any([
      'network',
      'offline',
      'timeout',
      'servicedisconnected',
      'serviceunavailable',
    ])) {
      return network;
    }
    if (any(['billingunavailable', 'storeunavailable'])) {
      return storeUnavailable;
    }
    if (any(['notallowed'])) return notAllowed;
    if (any([
      'itemunavailable',
      'productnotavailable',
      'productunavailable',
      'notfound',
    ])) {
      return productUnavailable;
    }
    if (any(['alreadyowned', 'itemalready'])) return alreadyOwned;
    return unknown;
  }
}

enum AnalyticsConsent { unknown, granted, denied }

/// Where events go. [FirebaseFunnelSink] in apps that use firebase_analytics
/// directly; apps with their own analytics service adapt it.
abstract class FunnelSink {
  Future<void> log(String name, Map<String, Object> params);
  Future<void> setCollectionEnabled(bool enabled);

  /// Firebase's anonymous app-instance id (user_pseudo_id in BigQuery).
  Future<String?> appInstanceId();
}

class FirebaseFunnelSink implements FunnelSink {
  FirebaseFunnelSink([FirebaseAnalytics? analytics]) : _fa = analytics;

  final FirebaseAnalytics? _fa;

  /// Null when Firebase didn't start (degraded launch): everything no-ops.
  FirebaseAnalytics? get _analytics {
    try {
      return _fa ?? FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> log(String name, Map<String, Object> params) async {
    await _analytics?.logEvent(name: name, parameters: params);
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    final fa = _analytics;
    if (fa == null) return;
    await fa.setAnalyticsCollectionEnabled(enabled);
    // Withdrawing consent also forgets the app-instance id.
    if (!enabled) await fa.resetAnalyticsData();
  }

  @override
  Future<String?> appInstanceId() async {
    try {
      return await _analytics?.appInstanceId;
    } catch (_) {
      return null;
    }
  }
}

/// What the server's purchase check (verifyStorePurchase) said about a
/// store transaction.
class VerifiedPurchase {
  const VerifiedPurchase({
    required this.event,
    required this.isNew,
    required this.transactionId,
    required this.productId,
    required this.offer,
    required this.paid,
    required this.environment,
    this.value,
    this.currency,
  });

  factory VerifiedPurchase.fromJson(Map<String, dynamic> j) => VerifiedPurchase(
    event: j['event'] as String?,
    isNew: j['isNew'] == true,
    transactionId: j['transactionId'] as String? ?? '',
    productId: j['productId'] as String? ?? '',
    offer: j['offer'] as String? ?? 'none',
    paid: j['paid'] == true,
    environment: j['environment'] as String? ?? 'production',
    value: (j['value'] as num?)?.toDouble(),
    currency: j['currency'] as String?,
  );

  /// trial_start, purchase_verified, trial_converted_to_paid,
  /// subscription_renewed — or null (a restore of something already known).
  final String? event;

  /// First time the server's ledger has seen this store transaction.
  final bool isNew;
  final String transactionId;
  final String productId;

  /// trial | intro | promo | offer_code | none
  final String offer;

  /// Money changed hands (not a free trial or a free reward).
  final bool paid;

  /// production | sandbox (Xcode/TestFlight/license testers).
  final String environment;
  final double? value;
  final String? currency;
}

/// One per app. Load it at startup, before anything logs.
class FunnelTracker extends ChangeNotifier {
  FunnelTracker({
    required this.onboardingVersion,
    required this.onboardingStepCount,
    this.consentRequired = true,
    FunnelSink? sink,
  }) : _sink = sink ?? FirebaseFunnelSink();

  /// False only for an app that collects analytics without asking (Glance,
  /// the user's call): events go straight out and there's no consent sheet.
  final bool consentRequired;

  /// Bump whenever onboarding screens are added, removed or reordered, so
  /// funnels from different versions aren't mixed.
  final String onboardingVersion;
  final int onboardingStepCount;

  final FunnelSink _sink;

  static const _kConsent = 'funnel.consent.v1';
  static const _kOnce = 'funnel.once.v1';
  static const _kTransactions = 'funnel.transactions.v1';

  SharedPreferences? _prefs;
  late AnalyticsConsent _consent = consentRequired
      ? AnalyticsConsent.unknown
      : AnalyticsConsent.granted;
  final Set<String> _once = {};
  final List<String> _transactions = [];

  /// Things logged at most once per app session (a paywall rebuilding).
  final Set<String> _sessionOnce = {};

  /// Events logged while consent is unanswered, this session only.
  final List<(String, Map<String, Object>)> _awaitingConsent = [];
  bool _completedThisSession = false;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  AnalyticsConsent get consent => _consent;
  bool get canCollect => _consent == AnalyticsConsent.granted;

  Future<void> load() async {
    try {
      final prefs = _prefs = await SharedPreferences.getInstance();
      _consent = switch (prefs.getString(_kConsent)) {
        'granted' => AnalyticsConsent.granted,
        'denied' => AnalyticsConsent.denied,
        _ => AnalyticsConsent.unknown,
      };
      if (!consentRequired) _consent = AnalyticsConsent.granted;
      _once.addAll(prefs.getStringList(_kOnce) ?? const []);
      _transactions.addAll(prefs.getStringList(_kTransactions) ?? const []);
      // Collection is off natively until consent; turn it on each launch.
      if (canCollect) await _sink.setCollectionEnabled(true);
    } catch (e) {
      debugPrint('[funnel] load failed: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setConsent(bool granted) async {
    final was = _consent;
    _consent = granted ? AnalyticsConsent.granted : AnalyticsConsent.denied;
    notifyListeners();
    try {
      await _prefs?.setString(_kConsent, granted ? 'granted' : 'denied');
      if (granted || was == AnalyticsConsent.granted) {
        await _sink.setCollectionEnabled(granted);
      }
      final waiting = List.of(_awaitingConsent);
      _awaitingConsent.clear();
      if (granted) {
        for (final (name, params) in waiting) {
          await _sink.log(name, params);
        }
      }
    } catch (e) {
      debugPrint('[funnel] saving consent failed: $e');
    }
  }

  /// Going on from Welcome, whose small print says analytics is on
  /// ([AnalyticsSmallPrint]). Keeps an answer already given in Settings.
  Future<void> acceptByContinuing() async {
    if (_consent == AnalyticsConsent.unknown) await setConsent(true);
  }

  /// The app-instance id to send with a purchase check, only with consent.
  Future<String?> appInstanceIdIfConsented() async =>
      canCollect ? _sink.appInstanceId() : null;

  // --------------------------------------------------------- onboarding ---

  void onboardingStarted() {
    if (!_firstTime(FunnelEvents.onboardingStarted)) return;
    _log(FunnelEvents.onboardingStarted, _onboardingParams());
  }

  /// [index] is the screen's 0-based position; it's sent 1-based.
  void onboardingStepView(String screenId, int index) {
    _log(FunnelEvents.onboardingStepView, {
      'screen_id': screenId,
      'step_index': index + 1,
      ..._onboardingParams(),
    });
  }

  void onboardingComplete() {
    _completedThisSession = true;
    if (!_firstTime(FunnelEvents.onboardingComplete)) return;
    _log(FunnelEvents.onboardingComplete, _onboardingParams());
  }

  Map<String, Object> _onboardingParams() => {
    'onboarding_version': onboardingVersion,
    'step_count': onboardingStepCount,
  };

  // ------------------------------------------------------------ paywall ---

  /// [PaywallPlacement.onboarding] if onboarding finished in this visit,
  /// else [PaywallPlacement.gate].
  String get gatePlacement => _completedThisSession
      ? PaywallPlacement.onboarding
      : PaywallPlacement.gate;

  void paywallView({required String paywallId, required String placement}) {
    if (!_sessionOnce.add('paywall_view:$paywallId:$placement')) return;
    _log(FunnelEvents.paywallView, {
      'paywall_id': paywallId,
      'placement': placement,
      'onboarding_version': onboardingVersion,
    });
  }

  void paywallDismiss({
    required String paywallId,
    required String placement,
    required String method,
  }) {
    _log(FunnelEvents.paywallDismiss, {
      'paywall_id': paywallId,
      'placement': placement,
      'method': method,
    });
  }

  void purchaseAttempt({required String productId, String? placement}) {
    _log(FunnelEvents.purchaseAttempt, {
      'product_id': productId,
      if (placement != null) 'placement': placement,
    });
  }

  void purchaseFailed({required String productId, required String category}) {
    _log(FunnelEvents.purchaseFailed, {
      'product_id': productId,
      'failure_category': category,
    });
  }

  // -------------------------------------------------------- purchases ---

  /// Logs what the server verified, once per store transaction. Restores
  /// (event null) and transactions the ledger already knew are never logged
  /// as acquisitions.
  ///
  /// Only acquisitions (trial_start, purchase_verified, plus GA's standard
  /// purchase for real money) go to analytics.
  /// StoreKit also hands the app renewals it missed while closed; those stay
  /// in the server's commerce ledger, which sees every renewal whether or
  /// not the app is opened.
  void recordVerified(VerifiedPurchase v) {
    final event = v.event;
    if (event == null || !v.isNew || v.transactionId.isEmpty) return;
    if (event != FunnelEvents.trialStart &&
        event != FunnelEvents.purchaseVerified) {
      return;
    }
    if (_transactions.contains(v.transactionId)) return;
    _transactions.add(v.transactionId);
    if (_transactions.length > 50) _transactions.removeAt(0);
    unawaited(_save(_kTransactions, _transactions));
    _log(event, {
      'product_id': v.productId,
      'offer': v.offer,
      'paid': v.paid ? 1 : 0,
      'environment': v.environment,
      if (v.paid && v.value != null) 'value': v.value!,
      if (v.paid && v.currency != null) 'currency': v.currency!,
    });
    // Sandbox money isn't real, so it stays out of the Revenue cards.
    if (event == FunnelEvents.purchaseVerified &&
        v.paid &&
        v.value != null &&
        v.currency != null &&
        v.environment == 'production') {
      _log(FunnelEvents.purchase, {
        'value': v.value!,
        'currency': v.currency!,
        'product_id': v.productId,
        'offer': v.offer,
      });
    }
  }

  // -------------------------------------------------------- engagement ---

  void firstCoreAction(String action) {
    if (!_firstTime(FunnelEvents.firstCoreAction)) return;
    _log(FunnelEvents.firstCoreAction, {'action': action});
  }

  // ------------------------------------------------------- acquisition ---

  /// The platform ids "How did you find us?" may send. ViralEngine's
  /// platform names where there is one, so the answer lines up with its
  /// per-post attribution.
  static const acquisitionSources = {
    'tiktok',
    'instagram',
    'facebook',
    'youtube',
    'pinterest',
    'snapchat',
    'google',
    'app_store',
    'google_play',
    'friends',
    'other',
  };

  /// The user's own answer to "How did you find us?". Only a known platform
  /// id goes in `source`: anything else becomes `other`. With `other`,
  /// [otherText] (what they typed, the user's call 2026-10-28) goes in
  /// `other_text`, cut to Google Analytics' 100-character limit. Logged
  /// each time the question is answered; reports use the latest per user.
  void acquisitionSurvey(String source, {String? otherText}) {
    final known = acquisitionSources.contains(source) ? source : 'other';
    final text = otherText?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    _log(FunnelEvents.acquisitionSurvey, {
      'source': known,
      if (known == 'other' && text.isNotEmpty)
        'other_text': text.length > maxOtherText
            ? text.substring(0, maxOtherText)
            : text,
      'onboarding_version': onboardingVersion,
    });
  }

  /// Google Analytics keeps at most 100 characters of a parameter.
  static const maxOtherText = 100;

  // ---------------------------------------------------------- plumbing ---

  /// Once per install, whether or not it was sent (declined consent counts).
  bool _firstTime(String key) {
    if (!_once.add(key)) return false;
    unawaited(_save(_kOnce, _once.toList()));
    return true;
  }

  Future<void> _save(String key, List<String> value) async {
    try {
      await _prefs?.setStringList(key, value);
    } catch (e) {
      debugPrint('[funnel] saving $key failed: $e');
    }
  }

  void _log(String name, Map<String, Object> params) {
    if (kDebugMode) {
      debugPrint('[funnel] $name ${jsonEncode(params)}');
      // Lets reports leave out events from developer builds.
      params = {...params, 'debug_build': 1};
    }
    if (_consent == AnalyticsConsent.unknown) {
      if (_awaitingConsent.length < 40) _awaitingConsent.add((name, params));
      return;
    }
    if (!canCollect) return;
    unawaited(
      _sink.log(name, params).catchError((Object e) {
        debugPrint('[funnel] $name failed: $e');
      }),
    );
  }
}
