import 'package:flutter_test/flutter_test.dart';
import 'package:military_calisthenics_women/core/funnel/funnel_tracker.dart';
import 'package:military_calisthenics_women/core/funnel/trial_engagement.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<FunnelEnvironment> _store() async =>
    const FunnelEnvironment.production('app_store');

class _Sink implements FunnelSink {
  final events = <(String, Map<String, Object>)>[];

  Iterable<String> get names => events.map((e) => e.$1);
  Map<String, Object> last(String name) =>
      events.lastWhere((e) => e.$1 == name).$2;

  @override
  Future<void> log(String name, Map<String, Object> params) async =>
      events.add((name, params));
  @override
  Future<void> setCollectionEnabled(bool on) async {}
  @override
  Future<String?> appInstanceId() async => null;
}

VerifiedPurchase _trialStart(String productId) => VerifiedPurchase(
  event: FunnelEvents.trialStart,
  isNew: true,
  transactionId: 't1',
  productId: productId,
  offer: 'trial',
  paid: false,
  environment: 'production',
);

class _Harness {
  _Harness({this.consent = true});

  final bool consent;
  final sink = _Sink();
  final userProperties = <String, String>{};
  DateTime now = DateTime(2026, 11, 3, 9);
  StoreRenewalStatus? status;
  late final FunnelTracker tracker;
  late TrialEngagement engagement;

  Future<void> start() async {
    tracker = FunnelTracker(
      onboardingVersion: 'test',
      onboardingStepCount: 12,
      sink: _Sink(),
      environment: _store,
    );
    await tracker.load();
    await tracker.setConsent(consent);
    engagement = _engagement();
    await engagement.load();
  }

  /// A new launch: same saved state, new object.
  Future<void> relaunch() async {
    engagement = _engagement();
    await engagement.load();
  }

  TrialEngagement _engagement() => TrialEngagement(
    tracker: tracker,
    trialDaysFor: (id) => id.contains('recovery') ? 7 : 3,
    sink: sink,
    renewalStatus: () async => status,
    setUserProperty: (name, value) async => userProperties[name] = value,
    clock: () => now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('first and second workouts, each counted once', () async {
    final h = _Harness();
    await h.start();
    h.engagement.workoutStarted(dayIndex: 1);
    h.engagement.workoutCompleted(dayIndex: 1, seconds: 900);
    h.engagement.workoutStarted(dayIndex: 2);
    h.engagement.workoutStarted(dayIndex: 3);
    expect(
      h.sink.names.where((n) => n == TrialEvents.workoutStarted).length,
      3,
    );
    expect(
      h.sink.names.where((n) => n == TrialEvents.firstWorkoutStarted).length,
      1,
    );
    expect(
      h.sink.names.where((n) => n == TrialEvents.secondSessionStarted).length,
      1,
    );
    expect(h.sink.last(TrialEvents.firstWorkoutCompleted)['duration_sec'], 900);
    expect(h.sink.last(TrialEvents.secondSessionStarted)['workout_number'], 2);
  });

  test('counts survive a relaunch', () async {
    final h = _Harness();
    await h.start();
    h.engagement.workoutStarted(dayIndex: 1);
    await Future<void>.delayed(Duration.zero);
    await h.relaunch();
    h.engagement.workoutStarted(dayIndex: 2);
    expect(h.sink.names, contains(TrialEvents.secondSessionStarted));
    expect(
      h.sink.names.where((n) => n == TrialEvents.firstWorkoutStarted).length,
      1,
    );
  });

  test('return on day 1 and day 2 of the trial, once each', () async {
    final h = _Harness();
    await h.start();
    h.engagement.onAcquisition(_trialStart('annual'));
    await h.engagement.onAppOpened();
    expect(h.sink.names, isNot(contains(TrialEvents.returnDay1)));

    h.now = DateTime(2026, 11, 4, 22);
    await h.engagement.onAppOpened();
    await h.engagement.onAppOpened();
    h.now = DateTime(2026, 11, 5, 7);
    await h.engagement.onAppOpened();

    expect(h.sink.names.where((n) => n == TrialEvents.returnDay1).length, 1);
    expect(h.sink.names.where((n) => n == TrialEvents.returnDay2).length, 1);
    expect(h.sink.last(TrialEvents.returnDay2)['trial_day'], 2);
    expect(h.sink.last(TrialEvents.returnDay2)['anchor'], 'trial');
    expect(h.sink.last(TrialEvents.returnDay2)['sub_state'], SubState.trial);
    expect(h.userProperties['sub_state'], SubState.trial);
  });

  test('a cancelled trial is logged with the hours since it started', () async {
    final h = _Harness();
    await h.start();
    h.engagement.onAcquisition(_trialStart('annual'));
    h.now = h.now.add(const Duration(hours: 30));
    h.status = const StoreRenewalStatus(
      productId: 'annual',
      willAutoRenew: false,
    );
    await h.engagement.onAppOpened();
    final p = h.sink.last(TrialEvents.trialCancelled);
    expect(p['hours_since_trial_start'], 30);
    expect(p['sub_state'], SubState.trialCancelled);
    expect(h.userProperties['sub_state'], SubState.trialCancelled);
    expect(h.sink.names, isNot(contains(TrialEvents.subscriptionConverted)));
  });

  test('the store is asked at most every 6 hours', () async {
    final h = _Harness();
    await h.start();
    h.engagement.onAcquisition(_trialStart('annual'));
    h.status = const StoreRenewalStatus(
      productId: 'annual',
      willAutoRenew: true,
    );
    await h.engagement.onAppOpened();
    h.status = const StoreRenewalStatus(
      productId: 'annual',
      willAutoRenew: false,
    );
    h.now = h.now.add(const Duration(hours: 1));
    await h.engagement.onAppOpened();
    expect(h.sink.names, isNot(contains(TrialEvents.trialCancelled)));
    h.now = h.now.add(const Duration(hours: 6));
    await h.engagement.onAppOpened();
    expect(h.sink.names, contains(TrialEvents.trialCancelled));
  });

  test('Play: converted only once the trial is a day past its end', () async {
    final h = _Harness();
    await h.start();
    h.engagement.onAcquisition(_trialStart('annual'));
    h.status = const StoreRenewalStatus(
      productId: 'annual',
      willAutoRenew: true,
    );
    h.now = h.now.add(const Duration(days: 3, hours: 2));
    await h.engagement.onAppOpened();
    expect(h.sink.names, isNot(contains(TrialEvents.subscriptionConverted)));

    h.now = h.now.add(const Duration(days: 1));
    await h.engagement.onAppOpened();
    final p = h.sink.last(TrialEvents.subscriptionConverted);
    expect(p['hours_since_trial_start'], 98);
    expect(p['sub_state'], SubState.paid);
  });

  test('iOS: a trial bought before this build is picked up from StoreKit, '
      'and its conversion when the period is paid', () async {
    final h = _Harness();
    await h.start();
    final started = h.now.subtract(const Duration(hours: 10));
    h.status = StoreRenewalStatus(
      productId: 'annual',
      willAutoRenew: true,
      inFreeTrial: true,
      startedAt: started,
      expiresAt: started.add(const Duration(days: 3)),
    );
    await h.engagement.onAppOpened();
    expect(h.engagement.subState, SubState.trial);

    h.now = h.now.add(const Duration(days: 3));
    h.status = StoreRenewalStatus(
      productId: 'annual',
      willAutoRenew: true,
      inFreeTrial: false,
      startedAt: started,
    );
    await h.engagement.onAppOpened();
    expect(
      h.sink.last(TrialEvents.subscriptionConverted)['hours_since_trial_start'],
      82,
    );
  });

  test('nothing is sent without analytics consent', () async {
    final h = _Harness(consent: false);
    await h.start();
    h.engagement.onAcquisition(_trialStart('annual'));
    h.engagement.workoutStarted(dayIndex: 1);
    h.engagement.workoutCompleted(dayIndex: 1, seconds: 60);
    h.now = h.now.add(const Duration(days: 1));
    await h.engagement.onAppOpened();
    expect(h.sink.events, isEmpty);
    expect(h.userProperties, isEmpty);
  });

  test('a store error never logs a cancellation', () async {
    final h = _Harness();
    await h.start();
    h.engagement.onAcquisition(_trialStart('annual'));
    h.status = null;
    await h.engagement.onAppOpened();
    expect(h.sink.names, isNot(contains(TrialEvents.trialCancelled)));
  });
}
