import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:military_calisthenics_women/core/platform/store_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'funnel_tracker.dart';

/// What trial users go on to do: MCW's own events, beside the shared funnel
/// kit's (funnel_tracker.dart is generated from ViralEngine, so these live
/// here instead).
///
/// trial_start itself is the kit's, from the server's purchase check.
abstract final class TrialEvents {
  /// Every workout, with `workout_number` (1, 2, 3…).
  static const workoutStarted = 'workout_started';
  static const workoutCompleted = 'workout_completed';
  static const workoutQuit = 'workout_quit';

  /// Once per install each, for simple funnels.
  static const firstWorkoutStarted = 'first_workout_started';
  static const firstWorkoutCompleted = 'first_workout_completed';

  /// The second workout started: they came back for another session.
  static const secondSessionStarted = 'second_session_started';

  /// The app was opened on the first / second calendar day after the trial
  /// started (after access began, for anyone without a known trial).
  static const returnDay1 = 'return_day_1';
  static const returnDay2 = 'return_day_2';

  /// The store says the trial will not renew. Seen on the next app open, so
  /// `hours_since_trial_start` is an upper bound; on iOS the commerce
  /// ledger has the exact time from Apple's notification.
  static const trialCancelled = 'trial_cancelled';

  /// The trial has ended and the subscription is still active.
  static const subscriptionConverted = 'subscription_converted';

  /// The app went to the background: how long this visit lasted.
  static const visitEnd = 'visit_end';

  /// The app went to the background during onboarding: the screen it was
  /// left on. Most of these never come back (onboarding_step_view shows it).
  static const onboardingExit = 'onboarding_exit';
}

/// Where a subscriber is, sent as `sub_state` on every event here and as a
/// user property, so engagement time and retention can be split by it.
abstract final class SubState {
  static const none = 'none';
  static const trial = 'trial';
  static const trialCancelled = 'trial_cancelled';
  static const paid = 'paid';
}

/// What the store says about the live subscription.
class StoreRenewalStatus {
  const StoreRenewalStatus({
    required this.productId,
    required this.willAutoRenew,
    this.inFreeTrial,
    this.startedAt,
    this.expiresAt,
  });

  final String productId;
  final bool willAutoRenew;

  /// iOS only: the current period is a free-trial introductory offer.
  final bool? inFreeTrial;

  /// iOS: the subscription's original purchase. Android: this purchase.
  final DateTime? startedAt;

  /// iOS only: when the current period (the trial, during one) ends.
  final DateTime? expiresAt;
}

/// Asks the store for the live subscription's renewal status, or null when
/// there's none (or the store can't be asked).
typedef RenewalStatusProbe = Future<StoreRenewalStatus?> Function();

/// iOS: StoreKit 2 through the AppDelegate's swiftbee/subscription_status
/// channel (in_app_purchase doesn't expose renewal info). Android: Play
/// Billing's past purchases, which carry isAutoRenewing.
Future<StoreRenewalStatus?> storeRenewalStatus() async {
  if (kIsWeb) return null;
  if (StorePlatform.isAndroid) {
    final addition = InAppPurchase.instance
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();
    if (response.error != null) return null;
    GooglePlayPurchaseDetails? latest;
    for (final p in response.pastPurchases) {
      final wrapper = p.billingClientPurchase;
      if (wrapper.purchaseState != PurchaseStateWrapper.purchased) continue;
      if (latest == null ||
          wrapper.purchaseTime > latest.billingClientPurchase.purchaseTime) {
        latest = p;
      }
    }
    if (latest == null) return null;
    final w = latest.billingClientPurchase;
    return StoreRenewalStatus(
      productId: latest.productID,
      willAutoRenew: w.isAutoRenewing,
      startedAt: DateTime.fromMillisecondsSinceEpoch(w.purchaseTime),
    );
  }
  const channel = MethodChannel('swiftbee/subscription_status');
  final raw = await channel.invokeMapMethod<String, Object?>('status');
  if (raw == null || raw['productId'] == null) return null;
  DateTime? at(Object? ms) =>
      ms is num ? DateTime.fromMillisecondsSinceEpoch(ms.toInt()) : null;
  return StoreRenewalStatus(
    productId: raw['productId']! as String,
    willAutoRenew: raw['willAutoRenew'] == true,
    inFreeTrial: raw['inFreeTrial'] as bool?,
    startedAt: at(raw['originalPurchaseDate']),
    expiresAt: at(raw['expirationDate']),
  );
}

/// Logs what trial users do after the paywall: workouts started and
/// finished, coming back on days 1 and 2, cancelling or converting, and how
/// long each visit lasts.
///
/// Sends only what [FunnelTracker] would: with analytics consent, from a
/// store install. Nothing is queued while consent is unanswered. No user id
/// is set; Firebase's random app-instance id is the only identifier. Only
/// counts, durations, product ids and screen ids are sent.
class TrialEngagement {
  TrialEngagement({
    required FunnelTracker tracker,
    required int Function(String productId) trialDaysFor,
    FunnelSink? sink,
    RenewalStatusProbe? renewalStatus,
    Future<void> Function(String name, String value)? setUserProperty,
    DateTime Function()? clock,
  }) : _tracker = tracker,
       _trialDaysFor = trialDaysFor,
       _sink = sink ?? FirebaseFunnelSink(),
       _renewalStatus = renewalStatus ?? storeRenewalStatus,
       _setUserProperty = setUserProperty ?? _firebaseUserProperty,
       _now = clock ?? DateTime.now;

  final FunnelTracker _tracker;
  final int Function(String productId) _trialDaysFor;
  final FunnelSink _sink;
  final RenewalStatusProbe _renewalStatus;
  final Future<void> Function(String name, String value) _setUserProperty;
  final DateTime Function() _now;

  static const _kState = 'trial_engagement.v1';

  /// How often the store is asked about renewal while the app is in use.
  static const statusCheckEvery = Duration(hours: 6);
  static final _conversionSlack = const Duration(days: 1).inMilliseconds;

  SharedPreferences? _prefs;
  _State _state = _State();
  bool _loaded = false;
  DateTime? _statusCheckedAt;
  String? _sentSubState;

  DateTime? _visitStartedAt;
  int _visitWorkouts = 0;
  AppLifecycleListener? _lifecycle;

  /// Onboarding's current screen, for onboarding_exit. Null outside it.
  ({String screenId, int index, DateTime since})? _onboardingScreen;
  DateTime? _onboardingStartedAt;

  bool get _sending =>
      _tracker.canCollect && (_tracker.environment?.isProduction ?? false);

  String get subState => _state.subState;

  Future<void> load() async {
    try {
      final prefs = _prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kState);
      if (raw != null) {
        _state = _State.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      }
    } catch (e) {
      debugPrint('[trial] load failed: $e');
    }
    _loaded = true;
  }

  /// Starts timing visits. Call once, when the app starts.
  void startVisits() {
    _visitStartedAt = _now();
    _lifecycle ??= AppLifecycleListener(
      onShow: () => _visitStartedAt = _now(),
      onHide: _endVisit,
    );
  }

  void dispose() => _lifecycle?.dispose();

  // ------------------------------------------------------------ trial ---

  /// From the server's purchase check ([FunnelTracker.onAcquisition]).
  void onAcquisition(VerifiedPurchase v) {
    if (v.event == FunnelEvents.trialStart) {
      final now = _now();
      _state
        ..trialStartMs = now.millisecondsSinceEpoch
        ..trialProductId = v.productId
        ..trialEndMs = now
            .add(Duration(days: _trialDaysFor(v.productId)))
            .millisecondsSinceEpoch
        ..subState = SubState.trial;
    } else if (v.event == FunnelEvents.purchaseVerified && v.paid) {
      _state.subState = SubState.paid;
    }
    _save();
    _syncSubState();
  }

  /// The app is open past the subscription gate: on launch and on every
  /// return to the foreground. Logs return_day_1/2 and checks the store for
  /// a cancelled or converted trial now and then.
  Future<void> onAppOpened() async {
    if (!_loaded) return;
    final now = _now();
    _state.accessStartMs ??= now.millisecondsSinceEpoch;
    final day = _daysSinceStart(now);
    if (day == 1 || day == 2) {
      final name = day == 1 ? TrialEvents.returnDay1 : TrialEvents.returnDay2;
      if (_state.once.add(name)) {
        _log(name, {
          'anchor': _state.trialStartMs != null ? 'trial' : 'access',
          'workouts_completed': _state.workoutsCompleted,
        });
      }
    }
    _save();
    _syncSubState();
    final checked = _statusCheckedAt;
    if (checked != null && now.difference(checked) < statusCheckEvery) return;
    _statusCheckedAt = now;
    await _checkRenewal();
  }

  Future<void> _checkRenewal() async {
    StoreRenewalStatus? status;
    try {
      status = await _renewalStatus();
    } catch (e) {
      debugPrint('[trial] renewal status failed: $e');
      return;
    }
    if (status == null) return;
    final now = _now();

    // A trial this install didn't see start (bought before this build, or
    // restored): iOS says so directly.
    if (_state.trialStartMs == null &&
        status.inFreeTrial == true &&
        status.startedAt != null) {
      _state
        ..trialStartMs = status.startedAt!.millisecondsSinceEpoch
        ..trialProductId = status.productId
        ..subState = SubState.trial;
    }
    if (status.inFreeTrial == true && status.expiresAt != null) {
      _state.trialEndMs = status.expiresAt!.millisecondsSinceEpoch;
    }

    final trialStart = _state.trialStartMs;
    final trialEnd = _state.trialEndMs;
    if (trialStart != null && trialEnd != null) {
      final inTrial =
          status.inFreeTrial ?? now.millisecondsSinceEpoch < trialEnd;
      final params = <String, Object>{
        'product_id': status.productId,
        'hours_since_trial_start': _hoursSince(trialStart, now),
        'workouts_completed': _state.workoutsCompleted,
      };
      if (inTrial && !status.willAutoRenew) {
        _state.subState = SubState.trialCancelled;
        if (_state.once.add(TrialEvents.trialCancelled)) {
          _log(TrialEvents.trialCancelled, {...params, 'detected': 'app_open'});
        }
      } else if (status.inFreeTrial == false ||
          (status.inFreeTrial == null &&
              status.willAutoRenew &&
              now.millisecondsSinceEpoch >= trialEnd + _conversionSlack)) {
        // Still subscribed after the trial's end: the first payment went
        // through. iOS says the period is paid; Play only lists the
        // purchase, so a day's slack lets a trial cancelled at the last
        // moment drop off the list first.
        _state.subState = SubState.paid;
        if (_state.once.add(TrialEvents.subscriptionConverted)) {
          _log(TrialEvents.subscriptionConverted, params);
        }
      } else if (inTrial && status.willAutoRenew) {
        // Cancelled, then turned back on.
        _state.subState = SubState.trial;
      }
    } else if (status.inFreeTrial == false) {
      _state.subState = SubState.paid;
    }
    _save();
    _syncSubState();
  }

  // --------------------------------------------------------- workouts ---

  void workoutStarted({required int dayIndex}) {
    _state.workoutsStarted++;
    final n = _state.workoutsStarted;
    final params = {'workout_number': n, 'day_index': dayIndex};
    _log(TrialEvents.workoutStarted, params);
    if (n == 1 && _state.once.add(TrialEvents.firstWorkoutStarted)) {
      _log(TrialEvents.firstWorkoutStarted, params);
    }
    if (n == 2 && _state.once.add(TrialEvents.secondSessionStarted)) {
      _log(TrialEvents.secondSessionStarted, {
        ...params,
        'hours_since_first_workout': _state.firstWorkoutMs == null
            ? -1
            : _hoursSince(_state.firstWorkoutMs!, _now()),
      });
    }
    _state.firstWorkoutMs ??= _now().millisecondsSinceEpoch;
    _save();
  }

  void workoutCompleted({required int dayIndex, required int seconds}) {
    _state.workoutsCompleted++;
    _visitWorkouts++;
    final params = {
      'workout_number': _state.workoutsCompleted,
      'day_index': dayIndex,
      'duration_sec': seconds,
    };
    _log(TrialEvents.workoutCompleted, params);
    if (_state.once.add(TrialEvents.firstWorkoutCompleted)) {
      _log(TrialEvents.firstWorkoutCompleted, params);
    }
    _save();
  }

  /// Left mid-workout. [reason] is the quit screen's choice (an enum name),
  /// never the note typed with it.
  void workoutQuit({
    required int dayIndex,
    required int percent,
    required int seconds,
    String? reason,
  }) {
    _log(TrialEvents.workoutQuit, {
      'day_index': dayIndex,
      'percent_done': percent,
      'duration_sec': seconds,
      'reason': reason ?? 'none',
    });
  }

  // ------------------------------------------------------- onboarding ---

  /// Onboarding showed [screenId] (0-based [index] in its PageView).
  void onboardingScreen(String screenId, int index) {
    final now = _now();
    _onboardingStartedAt ??= now;
    _onboardingScreen = (screenId: screenId, index: index, since: now);
  }

  /// Onboarding is finished or gone.
  void onboardingLeft() => _onboardingScreen = null;

  // ----------------------------------------------------------- visits ---

  void _endVisit() {
    final started = _visitStartedAt;
    _visitStartedAt = null;
    if (started == null) return;
    final now = _now();
    final seconds = now.difference(started).inSeconds;
    final screen = _onboardingScreen;
    if (screen != null) {
      _log(TrialEvents.onboardingExit, {
        'screen_id': screen.screenId,
        'step_index': screen.index + 1,
        'sec_on_screen': now.difference(screen.since).inSeconds,
        'sec_in_onboarding': now
            .difference(_onboardingStartedAt ?? screen.since)
            .inSeconds,
      });
    }
    // Under a second is a notification shade or app switcher flick.
    if (seconds >= 1) {
      _log(TrialEvents.visitEnd, {
        'duration_sec': seconds,
        'workouts_completed': _visitWorkouts,
        'in_onboarding': screen != null ? 1 : 0,
      });
    }
    _visitWorkouts = 0;
  }

  // --------------------------------------------------------- plumbing ---

  /// Calendar days since the trial started (or access began), local time.
  int? _daysSinceStart(DateTime now) {
    final startMs = _state.trialStartMs ?? _state.accessStartMs;
    if (startMs == null) return null;
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(now.year, now.month, now.day);
    // Rounded: a daylight-saving change makes a day 23 or 25 hours.
    return (b.difference(a).inHours / 24).round();
  }

  static int _hoursSince(int ms, DateTime now) => math.max(
    0,
    now.difference(DateTime.fromMillisecondsSinceEpoch(ms)).inHours,
  );

  void _syncSubState() {
    final value = _state.subState;
    if (!_sending || value == _sentSubState) return;
    _sentSubState = value;
    unawaited(
      _setUserProperty('sub_state', value).catchError((Object e) {
        debugPrint('[trial] sub_state failed: $e');
      }),
    );
  }

  static Future<void> _firebaseUserProperty(String name, String value) =>
      FirebaseAnalytics.instance.setUserProperty(name: name, value: value);

  void _log(String name, Map<String, Object> params) {
    final now = _now();
    params = {
      ...params,
      'sub_state': _state.subState,
      if (_daysSinceStart(now) case final day?) 'trial_day': day,
    };
    if (kDebugMode) {
      debugPrint('[trial] $name ${jsonEncode(params)}');
      params = {...params, 'debug_build': 1};
    }
    if (!_sending) return;
    unawaited(
      _sink.log(name, params).catchError((Object e) {
        debugPrint('[trial] $name failed: $e');
      }),
    );
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    unawaited(
      prefs
          .setString(_kState, jsonEncode(_state.toJson()))
          .then(
            (_) {},
            onError: (Object e) => debugPrint('[trial] save failed: $e'),
          ),
    );
  }
}

class _State {
  _State();

  factory _State.fromJson(Map<String, dynamic> j) => _State()
    ..trialStartMs = j['trialStartMs'] as int?
    ..trialEndMs = j['trialEndMs'] as int?
    ..trialProductId = j['trialProductId'] as String?
    ..accessStartMs = j['accessStartMs'] as int?
    ..firstWorkoutMs = j['firstWorkoutMs'] as int?
    ..workoutsStarted = j['workoutsStarted'] as int? ?? 0
    ..workoutsCompleted = j['workoutsCompleted'] as int? ?? 0
    ..subState = j['subState'] as String? ?? SubState.none
    ..once.addAll(((j['once'] as List?) ?? const []).cast<String>());

  int? trialStartMs;
  int? trialEndMs;
  String? trialProductId;
  int? accessStartMs;
  int? firstWorkoutMs;
  int workoutsStarted = 0;
  int workoutsCompleted = 0;
  String subState = SubState.none;
  final Set<String> once = {};

  Map<String, Object?> toJson() => {
    'trialStartMs': trialStartMs,
    'trialEndMs': trialEndMs,
    'trialProductId': trialProductId,
    'accessStartMs': accessStartMs,
    'firstWorkoutMs': firstWorkoutMs,
    'workoutsStarted': workoutsStarted,
    'workoutsCompleted': workoutsCompleted,
    'subState': subState,
    'once': once.toList(),
  };
}
