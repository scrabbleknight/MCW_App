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
/// answers, health details or anything typed by the user, apart from the
/// "Other" answer to "How did you find us?" ([acquisitionSurvey]).
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

  /// Paywall exit recovery offer (recovery_offer.dart): someone tried to
  /// leave the paywall without buying, and what happened next.
  static const paywallExitAttempt = 'paywall_exit_attempt';
  static const recoveryOfferShown = 'recovery_offer_shown';
  static const recoveryOfferAccepted = 'recovery_offer_accepted';
  static const recoveryOfferDeclined = 'recovery_offer_declined';
  static const recoveryTrialStarted = 'recovery_trial_started';
  static const recoveryTrialConverted = 'recovery_trial_converted';
  static const recoveryOfferPurchaseFailed = 'recovery_offer_purchase_failed';
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

  /// The App Store / Google Play purchase sheet was closed without buying.
  /// The paywall itself stays open; only [FunnelTracker.paywallExitAttempt]
  /// uses it, to say what opened the recovery offer.
  static const storeSheetCancel = 'store_sheet_cancel';
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

/// Where the button that turns analytics on by continuing says "Agree and
/// Continue" (the user's call, 2026-10-28): the EU and EEA, whose
/// regulators want people to agree before analytics starts. Read from the
/// phone's region, so no permission is needed. A phone with no region gets
/// it too, to be safe.
abstract final class AnalyticsAgreement {
  static const regions = {
    'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR', //
    'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK',
    'SI', 'ES', 'SE', 'IS', 'LI', 'NO',
  };

  /// Without [countryCode] it reads `PlatformDispatcher.instance`, which
  /// widget tests can't change, so apps pass the view's region in
  /// (`View.of(context).platformDispatcher.locale.countryCode`); same value.
  static bool needed([String? countryCode]) {
    final code = (countryCode ?? PlatformDispatcher.instance.locale.countryCode)
        ?.toUpperCase();
    return code == null || code.isEmpty || regions.contains(code);
  }
}

/// Whether this install belongs to a real store user. Analytics never turns
/// on for developer builds, simulators and emulators, TestFlight, or Google's
/// test devices (Play pre-launch reports) — whatever the consent answer, which
/// is still kept. Nothing is ever sent on a guess either way: an install that
/// can't be told apart counts as production.
class FunnelEnvironment {
  const FunnelEnvironment.production([this.installSource])
    : excludedReason = null;
  const FunnelEnvironment.excluded(String this.excludedReason)
    : installSource = null;

  /// debug_build | simulator | emulator | testflight | test_lab, or null.
  final String? excludedReason;

  /// app_store | google_play | the installing package | unknown.
  final String? installSource;

  bool get isProduction => excludedReason == null;

  /// From the build mode alone: release builds count. A debug or profile
  /// build only sends with `--dart-define=FUNNEL_ANALYTICS_IN_DEBUG=true`
  /// (for Firebase DebugView), and its events then carry `debug_build: 1`.
  static FunnelEnvironment fromBuildMode() =>
      kReleaseMode || const bool.fromEnvironment('FUNNEL_ANALYTICS_IN_DEBUG')
      ? const FunnelEnvironment.production()
      : const FunnelEnvironment.excluded('debug_build');
}

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

  /// Where the install came from (user property `install_source`), so
  /// reports can split store users from anything else.
  Future<void> setInstallSource(String? source) async {
    if (source == null) return;
    try {
      await _analytics?.setUserProperty(name: 'install_source', value: source);
    } catch (_) {}
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
    Future<FunnelEnvironment> Function()? environment,
  }) : _sink = sink ?? FirebaseFunnelSink(),
       _probe = environment ?? (() async => FunnelEnvironment.fromBuildMode());

  /// False only for an app that collects analytics without asking (Glance,
  /// the user's call): events go straight out and there's no consent sheet.
  final bool consentRequired;

  /// Bump whenever onboarding screens are added, removed or reordered, so
  /// funnels from different versions aren't mixed.
  final String onboardingVersion;
  final int onboardingStepCount;

  final FunnelSink _sink;

  /// Tells a store install from a test one (detectFunnelEnvironment in
  /// analytics_environment.dart); without it, only the build mode counts.
  final Future<FunnelEnvironment> Function() _probe;
  FunnelEnvironment? _env;
  Future<FunnelEnvironment>? _envFuture;

  /// The environment is known and collection is as it should be: events go
  /// straight through from here.
  bool _ready = false;

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

  /// Events logged before the environment is known (the first moments of a
  /// launch), sent or dropped once it is.
  final List<(String, Map<String, Object>)> _awaitingEnvironment = [];
  bool _completedThisSession = false;
  bool _loaded = false;

  /// Called after a new trial_start or purchase_verified is logged (whether
  /// or not it was sent). The recovery offer listens here for its trials.
  void Function(VerifiedPurchase purchase)? onAcquisition;

  bool get isLoaded => _loaded;
  AnalyticsConsent get consent => _consent;
  bool get canCollect => _consent == AnalyticsConsent.granted;

  /// Null until [load] has looked.
  FunnelEnvironment? get environment => _env;
  bool get _sending => canCollect && (_env?.isProduction ?? false);

  Future<FunnelEnvironment> _ensureEnvironment() async {
    if (_env != null) return _env!;
    final env = await (_envFuture ??= _probe().catchError((Object e) {
      debugPrint('[funnel] environment check failed: $e');
      return FunnelEnvironment.fromBuildMode();
    }));
    if (_env == null) {
      _env = env;
      if (!env.isProduction) {
        debugPrint('[funnel] analytics stays off: ${env.excludedReason}');
      }
    }
    return _env!;
  }

  /// What was logged before the environment was known. Called once
  /// collection is on (Firebase drops events logged while it's off).
  void _flushAwaitingEnvironment() {
    final waiting = List.of(_awaitingEnvironment);
    _awaitingEnvironment.clear();
    for (final (name, params) in waiting) {
      _log(name, params);
    }
  }

  /// Collection on, and where the install came from.
  Future<void> _startCollecting() async {
    await _sink.setCollectionEnabled(true);
    final sink = _sink;
    if (sink is FirebaseFunnelSink) {
      await sink.setInstallSource(_env?.installSource);
    }
  }

  Future<void> load() async {
    try {
      final prefs = _prefs = await SharedPreferences.getInstance();
      _consent = switch (prefs.getString(_kConsent)) {
        'granted' => AnalyticsConsent.granted,
        'denied' => AnalyticsConsent.denied,
        _ => AnalyticsConsent.unknown,
      };
      // Without a consent question analytics is on, unless switched off in
      // Settings.
      if (!consentRequired && _consent != AnalyticsConsent.denied) {
        _consent = AnalyticsConsent.granted;
      }
      _once.addAll(prefs.getStringList(_kOnce) ?? const []);
      _transactions.addAll(prefs.getStringList(_kTransactions) ?? const []);
      final env = await _ensureEnvironment();
      // Collection is off natively until consent; turn it on each launch.
      if (_sending) {
        await _startCollecting();
      } else if (!env.isProduction) {
        // Firebase remembers "on" across launches: a tester's phone that said
        // yes on an older build must stop sending automatic events too.
        await _sink.setCollectionEnabled(false);
      }
      _ready = true;
      _flushAwaitingEnvironment();
    } catch (e) {
      debugPrint('[funnel] load failed: $e');
    }
    if (!_ready) {
      _env ??= FunnelEnvironment.fromBuildMode();
      _ready = true;
      _flushAwaitingEnvironment();
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
      final env = await _ensureEnvironment();
      if (granted && env.isProduction) {
        await _startCollecting();
      } else if (!granted && was == AnalyticsConsent.granted) {
        await _sink.setCollectionEnabled(false);
      }
      _ready = true;
      _flushAwaitingEnvironment();
      final waiting = List.of(_awaitingConsent);
      _awaitingConsent.clear();
      if (granted && env.isProduction) {
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
      _sending ? _sink.appInstanceId() : null;

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
    onAcquisition?.call(v);
  }

  // ---------------------------------------------- exit recovery offer ---

  /// Someone tried to leave the paywall without buying: the close button,
  /// Android back, or closing the store's purchase sheet
  /// ([PaywallDismissMethod.storeSheetCancel]). [offerEligible] is whether
  /// the recovery offer could be shown to them then.
  void paywallExitAttempt({
    required String paywallId,
    required String placement,
    required String method,
    required bool offerEligible,
  }) {
    _log(FunnelEvents.paywallExitAttempt, {
      'paywall_id': paywallId,
      'placement': placement,
      'method': method,
      'offer_eligible': offerEligible ? 1 : 0,
    });
  }

  /// [offer] is RecoveryOfferTerms.analyticsParams: offer and product ids,
  /// currency, prices, trial days and the post code where there is one.
  void recoveryOfferShown(
    Map<String, Object> offer, {
    required String trigger,
    required String placement,
  }) {
    _log(FunnelEvents.recoveryOfferShown, {
      ...offer,
      'trigger': trigger,
      'placement': placement,
    });
  }

  /// "Claim My Special Offer" tapped; the store sheet opens next.
  void recoveryOfferAccepted(Map<String, Object> offer) {
    _log(FunnelEvents.recoveryOfferAccepted, offer);
  }

  /// "No thanks", or the offer closed by back / swipe.
  void recoveryOfferDeclined(Map<String, Object> offer, {required String method}) {
    _log(FunnelEvents.recoveryOfferDeclined, {...offer, 'method': method});
  }

  void recoveryOfferPurchaseFailed(
    Map<String, Object> offer, {
    required String category,
  }) {
    _log(FunnelEvents.recoveryOfferPurchaseFailed, {
      ...offer,
      'failure_category': category,
    });
  }

  /// The server verified a new free-trial transaction on the recovery
  /// product (beside the usual trial_start).
  void recoveryTrialStarted(Map<String, Object> offer, {required String environment}) {
    _log(FunnelEvents.recoveryTrialStarted, {
      ...offer,
      'environment': environment,
    });
  }

  /// The recovery subscription was still active after its trial ended, as
  /// seen on a later launch. An app-side estimate, once per install: the
  /// commerce ledger's trial_converted_to_paid is the authoritative count.
  void recoveryTrialConverted(Map<String, Object> offer) {
    if (!_firstTime(FunnelEvents.recoveryTrialConverted)) return;
    _log(FunnelEvents.recoveryTrialConverted, offer);
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
    final env = _env;
    if (env == null || !_ready) {
      if (_awaitingEnvironment.length < 40) {
        _awaitingEnvironment.add((name, params));
      }
      return;
    }
    if (!env.isProduction) return;
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
